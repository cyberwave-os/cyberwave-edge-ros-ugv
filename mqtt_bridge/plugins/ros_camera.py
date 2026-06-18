import asyncio
import fractions
import time
import threading
from typing import Optional, Any, Dict
import logging

import cv2
import numpy as np
from av import VideoFrame
from rclpy.node import Node
from sensor_msgs.msg import Image

from cyberwave.camera import BaseVideoTrack, BaseVideoStreamer
from aiortc.rtcicetransport import RTCIceGatherer, connection_kwargs
from aioice import Connection, TransportPolicy

logger = logging.getLogger(__name__)

# ROS sensor_msgs / usb_cam encodings treated as packed YUYV (no BGR in callback).
_YUYV_ENCODINGS = frozenset({"yuyv", "yuv422_yuy2"})


class RelayOnlyRTCIceGatherer(RTCIceGatherer):
    """
    Custom RTCIceGatherer that forces TURN relay-only mode.

    This is needed because aiortc's RTCConfiguration doesn't support iceTransportPolicy,
    but the underlying aioice.Connection does support transport_policy.
    """

    def __init__(
        self,
        iceServers=None,
        local_username: Optional[str] = None,
        local_password: Optional[str] = None,
    ) -> None:
        from pyee.asyncio import AsyncIOEventEmitter
        AsyncIOEventEmitter.__init__(self)

        if iceServers is None:
            iceServers = self.getDefaultIceServers()
        ice_kwargs = connection_kwargs(iceServers)

        # Force RELAY mode
        ice_kwargs['transport_policy'] = TransportPolicy.RELAY
        logger.info("ICE transport policy set to RELAY (force_turn enabled)")

        self._connection = Connection(ice_controlling=False, **ice_kwargs)
        self._remote_candidates_end = False
        self._RTCIceGatherer__state = "new"


def enable_relay_only_ice_mode() -> None:
    """Permanently patch aiortc to use relay-only ICE mode for this process.

    Unlike a context manager, this patch persists across WebRTC reconnections so
    every peer connection created after this call (including auto-reconnect attempts)
    will use TURN relay-only transport.  Call this once during streamer initialisation
    when force_relay=True.
    """
    import aiortc.rtcpeerconnection as rtcpc
    if rtcpc.RTCIceGatherer is not RelayOnlyRTCIceGatherer:
        rtcpc.RTCIceGatherer = RelayOnlyRTCIceGatherer
        logger.info("Permanently enabled relay-only ICE mode (force_turn)")


class ROSVideoStreamTrack(BaseVideoTrack):
    """
    Video stream track that gets frames from a ROS 2 topic.
    """
    def __init__(self, node: Node, topic: str = "/image_raw", fps: int = 30):
        super().__init__()
        self.node = node
        self.topic = topic
        self.fps = fps
        self.encoding = "yuv420p"
        self.latest_frame = None
        self.latest_frame_encoding: Optional[str] = None
        self._frame_lock = threading.Lock()
        self._last_time = None
        self._last_log_time = 0
        self._frames_received = 0
        self._frame_ready_event = threading.Event()
        
        # Dimensions from config or default
        self.actual_width = 640
        self.actual_height = 480
        if hasattr(self.node, '_mapping') and self.node._mapping:
            camera_config = self.node._mapping.raw.get('camera', {})
            self.actual_width = camera_config.get('image_width', 640)
            self.actual_height = camera_config.get('image_height', 480)
        
        # Subscribe to ROS image topic
        self.subscription = self.node.create_subscription(
            Image, self.topic, self._image_callback, 10
        )
        self.node.get_logger().info(f"ROSVideoStreamTrack subscribed to {self.topic}")

    def _image_callback(self, msg):
        try:
            now = time.time()
            if now - self._last_log_time > 10:
                self.node.get_logger().info(
                    f"ROSCameraStreamer: {self.topic} {msg.encoding} {msg.width}x{msg.height}"
                )
                self._last_log_time = now

            if self.latest_frame is None:
                self.node.get_logger().info(f"FIRST FRAME on {self.topic}!")

            # Store native ROS payload; convert to yuv420p only in recv() (stream rate).
            if msg.encoding in _YUYV_ENCODINGS:
                frame_buffer = np.frombuffer(msg.data, dtype=np.uint8).reshape(
                    (msg.height, msg.width, 2)
                )
                frame_encoding = "yuyv"
            elif msg.encoding in ("rgb8", "bgr8"):
                frame_buffer = np.frombuffer(msg.data, dtype=np.uint8).reshape(
                    (msg.height, msg.width, 3)
                )
                frame_encoding = msg.encoding
            else:
                self.node.get_logger().error(f"Unsupported image encoding: {msg.encoding}")
                return

            # H.264 / yuv420p require even width and height.
            h, w = frame_buffer.shape[:2]
            if h % 2 != 0 or w % 2 != 0:
                frame_buffer = frame_buffer[: h & ~1, : w & ~1]

            with self._frame_lock:
                self.latest_frame = np.ascontiguousarray(frame_buffer, dtype=np.uint8)
                self.latest_frame_encoding = frame_encoding
                self.actual_height, self.actual_width = frame_buffer.shape[:2]
                self._frames_received += 1
                if hasattr(self.node, '_last_image_time'):
                    self.node._last_image_time = now
            
            # Signal that we have at least one frame ready
            if not self._frame_ready_event.is_set():
                self._frame_ready_event.set()
                self.node.get_logger().info(f"Frame buffer ready for WebRTC streaming")
                
        except Exception as e:
            self.node.get_logger().error(f"Error processing ROS image: {e}")

    def get_stream_attributes(self) -> Dict[str, Any]:
        return {
            "camera_type": "ros",
            "camera_id": self.topic,
            "width": self.actual_width,
            "height": self.actual_height,
            "fps": self.fps,
        }
    
    def wait_for_frames(self, timeout: float = 5.0) -> bool:
        """
        Wait for frames to be available before starting WebRTC.
        
        Args:
            timeout: Maximum time to wait in seconds
            
        Returns:
            True if frames are ready, False if timeout occurred
        """
        return self._frame_ready_event.wait(timeout)
    
    def has_frames(self) -> bool:
        """Check if any frames have been received."""
        return self._frame_ready_event.is_set()

    def get_latest_frame_bgr(self) -> Optional[np.ndarray]:
        """Return the latest frame as BGR for JPEG snapshot (take_photo)."""
        with self._frame_lock:
            frame_data = self.latest_frame
            encoding = self.latest_frame_encoding
        if frame_data is None or encoding is None:
            return None
        if encoding in _YUYV_ENCODINGS or encoding == "yuyv":
            return cv2.cvtColor(frame_data, cv2.COLOR_YUV2BGR_YUYV)
        if encoding == "rgb8":
            return cv2.cvtColor(frame_data, cv2.COLOR_RGB2BGR)
        return frame_data.copy()

    @staticmethod
    def _to_yuv420p_video_frame(frame_data: np.ndarray, encoding: str) -> VideoFrame:
        if encoding in _YUYV_ENCODINGS or encoding == "yuyv":
            video_frame = VideoFrame.from_ndarray(frame_data, format="yuyv422")
        elif encoding == "rgb8":
            bgr = cv2.cvtColor(frame_data, cv2.COLOR_RGB2BGR)
            video_frame = VideoFrame.from_ndarray(bgr, format="bgr24")
        else:
            video_frame = VideoFrame.from_ndarray(frame_data, format="bgr24")
        return video_frame.reformat(format="yuv420p")

    async def recv(self):
        # Wait for at least one frame to be ready before starting WebRTC streaming
        if self.frame_count == 0:
            # Wait up to 5 seconds for the first frame
            self.node.get_logger().info(f"Waiting for first frame on {self.topic}...")
            await asyncio.get_event_loop().run_in_executor(
                None, self._frame_ready_event.wait, 5.0
            )
            if not self._frame_ready_event.is_set():
                self.node.get_logger().error(
                    f"No frames received on {self.topic} after 5s, starting with blank frame"
                )
            else:
                self.node.get_logger().info(f"First frame ready on {self.topic}, starting WebRTC transmission")
        
        # Frame rate control (skip for first frame to avoid SDK timeout)
        if self.frame_count > 0:
            now = time.time()
            if self._last_time is not None:
                wait = max(0, (1.0 / self.fps) - (now - self._last_time))
                if wait > 0:
                    await asyncio.sleep(wait)
        self._last_time = time.time()

        self.frame_count += 1
        pts = self.frame_count
        time_base = fractions.Fraction(1, int(self.fps))
        
        with self._frame_lock:
            frame_data = self.latest_frame
            frame_encoding = self.latest_frame_encoding
            frames_received = self._frames_received

        if frame_data is None:
            # Create blank gray frame if no data available
            self.node.get_logger().warning(
                f"Frame {self.frame_count}: No frame data available, sending blank frame (received {frames_received} total)"
            )
            frame_data = np.full((self.actual_height, self.actual_width, 3), 128, dtype=np.uint8)
            frame_encoding = "bgr8"
        elif self.frame_count == 1:
            self.node.get_logger().info(
                f"Starting WebRTC stream with cached frame (received {frames_received} frames so far)"
            )
        elif self.frame_count % 100 == 0:
            # Log every 100 frames to confirm streaming
            self.node.get_logger().debug(
                f"Frame {self.frame_count}: Sending frame to WebRTC ({frames_received} total received)"
            )
            
        now = time.time()
        now_monotonic = time.monotonic()

        if self.frame_count == 1:
            self.frame_0_timestamp = now
            self.frame_0_timestamp_monotonic = now_monotonic

        frame = self._to_yuv420p_video_frame(frame_data, frame_encoding or "bgr8")
        frame.pts = pts
        frame.time_base = time_base

        # Capture sync frame data so the SDK can publish a camera_sync_frame MQTT
        # message after streaming starts. This anchor is required for the backend to
        # correctly trim and timestamp the recording for Replay.
        self._capture_sync_frame(
            now,
            now_monotonic,
            frame_index=self.frame_count,
            pts=pts,
            time_base_num=time_base.numerator,
            time_base_den=time_base.denominator,
        )

        # Keyframe every 4 seconds or first 10 frames
        if self.frame_count % (int(self.fps) * 4) == 1 or self.frame_count < 10:
            frame.key_frame = True

        return frame

    def close(self):
        if self.subscription:
            self.node.destroy_subscription(self.subscription)
            self.subscription = None
        super().stop()


class ROSCameraStreamer(BaseVideoStreamer):
    """
    Uses SDK's BaseVideoStreamer with ROS image source.

    Args:
        node: ROS 2 node instance
        client: MQTT client for signaling
        force_relay: If True, forces all WebRTC traffic through TURN relay servers.
                    This bypasses NAT/firewall issues but adds latency.  The relay
                    patch is applied permanently (process-wide) so it survives
                    auto-reconnect cycles.
    """
    def __init__(self, node: Node, client: Any, *args, **kwargs):
        self.fps = kwargs.pop('fps', 30)
        kwargs.pop('time_reference', None)
        # Extract force_relay before passing to parent (parent doesn't know about it)
        self.force_relay = kwargs.pop('force_relay', False)

        # Apply the relay-only ICE patch before the parent creates any peer connection.
        # Using a permanent patch (not a context manager) ensures every future
        # reconnect attempt also uses relay-only transport.
        if self.force_relay:
            enable_relay_only_ice_mode()

        # Populate camera_name from mapping if not explicitly provided.
        # The media service requires a non-None sensor field in the WebRTC offer to
        # start a recording; without it the backend logs an error and skips recording,
        # which is why UGV streams never appeared in the Replay tab.
        if 'camera_name' not in kwargs or kwargs.get('camera_name') is None:
            mapping_camera_name = None
            if hasattr(node, '_mapping') and node._mapping:
                camera_config = node._mapping.raw.get('camera', {})
                mapping_camera_name = camera_config.get('camera_name') or camera_config.get('sensor_id')
            if mapping_camera_name:
                kwargs['camera_name'] = mapping_camera_name

        super().__init__(client, *args, **kwargs)
        self.node = node

        # Get camera settings from robot mapping (preferred) or fall back to defaults
        if hasattr(self.node, '_mapping') and self.node._mapping:
            camera_config = self.node._mapping.raw.get('camera', {})
            self.image_topic = camera_config.get('image_topic', '/image_raw')
            self.fps = camera_config.get('fps', self.fps)
        else:
            self.image_topic = "/image_raw"

        mode_str = " (TURN relay-only)" if self.force_relay else ""
        self.node.get_logger().info(
            f"ROSCameraStreamer: {self.image_topic} @ {self.fps}fps{mode_str}"
            + (f", camera_name={self.camera_name}" if self.camera_name else ", camera_name=None (recording disabled)")
        )

    def initialize_track(self) -> ROSVideoStreamTrack:
        """Required by BaseVideoStreamer: create the video track."""
        if self.streamer is not None:
            return self.streamer
        self.streamer = ROSVideoStreamTrack(self.node, self.image_topic, self.fps)
        return self.streamer

    async def start(self, *args, **kwargs):
        """
        Start the WebRTC camera stream.

        Waits for frames to be available before starting WebRTC to avoid
        'Timeout waiting for first frame' warnings.
        """
        # Ensure track is initialized
        if self.streamer is None:
            self.initialize_track()

        # Wait for frames to be ready (up to 10 seconds)
        self.node.get_logger().info("Waiting for camera frames before starting WebRTC...")
        frame_ready = await asyncio.get_event_loop().run_in_executor(
            None, self.streamer.wait_for_frames, 10.0
        )

        if frame_ready:
            self.node.get_logger().info(
                f"Camera frames ready! Starting WebRTC with {self.streamer._frames_received} cached frames"
            )
        else:
            self.node.get_logger().warning(
                "No camera frames after 10s wait. Starting WebRTC anyway (will send blank frames)"
            )

        # Delegate entirely to the SDK's WebRTC setup — do not override signaling
        # internals (_subscribe_to_answer, _send_offer, _wait_for_answer) as they
        # can race with the SDK's own state machine on reconnect.
        return await super().start(*args, **kwargs)
