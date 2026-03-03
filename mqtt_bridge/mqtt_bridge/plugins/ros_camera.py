import asyncio
import fractions
import time
import threading
from typing import Optional, Any, Dict
from contextlib import contextmanager
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


@contextmanager
def relay_only_ice_mode():
    """Context manager to temporarily enable relay-only ICE mode."""
    import aiortc.rtcpeerconnection as rtcpc
    
    original_gatherer = rtcpc.RTCIceGatherer
    try:
        rtcpc.RTCIceGatherer = RelayOnlyRTCIceGatherer
        logger.info("Enabled relay-only ICE mode")
        yield
    finally:
        rtcpc.RTCIceGatherer = original_gatherer


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

            # Handle different image encodings
            if msg.encoding in ['yuyv', 'yuv422_yuy2']:
                # Convert YUYV to BGR (yuv422_yuy2 is the ROS standard name for YUYV)
                raw_data = np.frombuffer(msg.data, dtype=np.uint8).reshape((msg.height, msg.width, 2))
                bgr_frame = cv2.cvtColor(raw_data, cv2.COLOR_YUV2BGR_YUYV)
            elif msg.encoding in ['rgb8', 'bgr8']:
                # Already in RGB/BGR format from MJPEG decoding
                raw_data = np.frombuffer(msg.data, dtype=np.uint8).reshape((msg.height, msg.width, 3))
                if msg.encoding == 'rgb8':
                    bgr_frame = cv2.cvtColor(raw_data, cv2.COLOR_RGB2BGR)
                else:
                    bgr_frame = raw_data
            else:
                self.node.get_logger().error(f"Unsupported image encoding: {msg.encoding}")
                return
            
            # Ensure even dimensions for H.264
            h, w = bgr_frame.shape[:2]
            if h % 2 != 0 or w % 2 != 0:
                bgr_frame = bgr_frame[:h & ~1, :w & ~1]
            
            with self._frame_lock:
                self.latest_frame = np.ascontiguousarray(bgr_frame, dtype=np.uint8)
                self.actual_height, self.actual_width = bgr_frame.shape[:2]
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
            frames_received = self._frames_received
        
        if frame_data is None:
            # Create blank gray frame if no data available
            self.node.get_logger().warning(
                f"Frame {self.frame_count}: No frame data available, sending blank frame (received {frames_received} total)"
            )
            frame_data = np.full((self.actual_height, self.actual_width, 3), 128, dtype=np.uint8)
        elif self.frame_count == 1:
            self.node.get_logger().info(
                f"Starting WebRTC stream with cached frame (received {frames_received} frames so far)"
            )
        elif self.frame_count % 100 == 0:
            # Log every 100 frames to confirm streaming
            self.node.get_logger().debug(
                f"Frame {self.frame_count}: Sending frame to WebRTC ({frames_received} total received)"
            )
            
        if self.frame_count == 1:
            self.frame_0_timestamp = time.time()
            self.frame_0_timestamp_monotonic = time.monotonic()

        frame = VideoFrame.from_ndarray(frame_data, format="bgr24")
        frame = frame.reformat(format="yuv420p")
        frame.pts = pts
        frame.time_base = time_base
        
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
                    This bypasses NAT/firewall issues but adds latency.
    """
    def __init__(self, node: Node, client: Any, *args, **kwargs):
        self.fps = kwargs.pop('fps', 30)
        kwargs.pop('time_reference', None)
        # Extract force_relay before passing to parent (parent doesn't know about it)
        self.force_relay = kwargs.pop('force_relay', False)
        
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
        self.node.get_logger().info(f"ROSCameraStreamer: {self.image_topic} @ {self.fps}fps{mode_str}")

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
        
        # Now start the parent's WebRTC setup
        return await super().start(*args, **kwargs)

    async def _setup_webrtc(self):
        """
        Initialize WebRTC peer connection with optional relay-only mode.
        
        When force_relay is True, patches aiortc to use only TURN relay candidates,
        bypassing NAT/firewall issues.
        """
        self.node.get_logger().info(f"_setup_webrtc called, force_relay={self.force_relay}")
        if self.force_relay:
            self.node.get_logger().info(
                "Setting up WebRTC with RELAY-ONLY transport policy (force_turn enabled)"
            )
            with relay_only_ice_mode():
                self.node.get_logger().info("Inside relay_only_ice_mode context, calling super()._setup_webrtc()")
                await super()._setup_webrtc()
                self.node.get_logger().info("Exited relay_only_ice_mode context")
        else:
            self.node.get_logger().info("Setting up WebRTC with normal ICE (force_turn disabled)")
            await super()._setup_webrtc()
    
    def _send_offer(self, sdp: str):
        """Override to add diagnostic logging for WebRTC offer."""
        import time
        prefix = self.client.topic_prefix
        offer_topic = f"{prefix}cyberwave/twin/{self.twin_uuid}/webrtc-offer"
        
        sdp_lines = sdp.split('\r\n') if sdp else []
        self.node.get_logger().info(f"=== WebRTC OFFER BEING SENT ===")
        self.node.get_logger().info(f"  Topic: {offer_topic}")
        self.node.get_logger().info(f"  SDP lines: {len(sdp_lines)}")
        
        relay_candidates = [l for l in sdp_lines if 'relay' in l.lower()]
        host_candidates = [l for l in sdp_lines if 'a=candidate' in l and 'host' in l.lower()]
        srflx_candidates = [l for l in sdp_lines if 'a=candidate' in l and 'srflx' in l.lower()]
        
        self.node.get_logger().info(f"  ICE candidates: relay={len(relay_candidates)}, host={len(host_candidates)}, srflx={len(srflx_candidates)}")
        
        if relay_candidates:
            for c in relay_candidates[:3]:
                self.node.get_logger().info(f"  RELAY: {c[:100]}...")
        else:
            self.node.get_logger().warning("  WARNING: No relay candidates in offer - TURN may not be working!")
        
        super()._send_offer(sdp)
        self.node.get_logger().info(f"=== WebRTC OFFER SENT ===")
    
    def _subscribe_to_answer(self):
        """Override to add diagnostic logging for WebRTC answer subscription."""
        import json
        
        if not self.twin_uuid:
            raise ValueError("twin_uuid must be set before subscribing")
        
        prefix = self.client.topic_prefix
        answer_topic = f"{prefix}cyberwave/twin/{self.twin_uuid}/webrtc-answer"
        candidate_topic = f"{prefix}cyberwave/twin/{self.twin_uuid}/webrtc-candidate"
        
        self.node.get_logger().info(f"=== SUBSCRIBING TO WEBRTC SIGNALING ===")
        self.node.get_logger().info(f"  Answer topic: {answer_topic}")
        self.node.get_logger().info(f"  Candidate topic: {candidate_topic}")
        
        def logging_on_answer(data):
            try:
                payload = data if isinstance(data, dict) else json.loads(data)
                msg_type = payload.get('type', 'unknown')
                target = payload.get('target', 'unknown')
                sender = payload.get('sender', 'unknown')
                sensor = payload.get('sensor') or payload.get('camera', 'unknown')
                
                self.node.get_logger().info(f"=== WEBRTC MESSAGE RECEIVED ===")
                self.node.get_logger().info(
                    f"  type={msg_type}, target={target}, sender={sender}, sensor={sensor}"
                )
                
                if msg_type == 'answer':
                    sdp = payload.get('sdp', '')
                    sdp_lines = sdp.split('\r\n') if sdp else []
                    self.node.get_logger().info(f"  Answer SDP lines: {len(sdp_lines)}")
                    if target == 'edge':
                        self.node.get_logger().info("  >>> PROCESSING ANSWER FOR EDGE <<<")
                    else:
                        self.node.get_logger().warning(f"  Ignoring answer: target={target} (expected 'edge')")
                elif msg_type == 'candidate':
                    candidate = payload.get('candidate', {})
                    self.node.get_logger().info(f"  ICE candidate: {str(candidate)[:100]}...")
                
            except Exception as e:
                self.node.get_logger().error(f"Error logging WebRTC message: {e}")
            
            try:
                payload = data if isinstance(data, dict) else json.loads(data)
                
                if payload.get("type") == "offer":
                    return
                elif payload.get("type") == "answer":
                    if payload.get("target") == "edge":
                        answer_sensor = payload.get("sensor") or payload.get("camera")
                        expected = self.camera_name if self.camera_name is not None else "default"
                        if answer_sensor is None or answer_sensor == expected:
                            self._answer_data = payload
                            self._answer_received = True
                            self.node.get_logger().info(f"  >>> ANSWER ACCEPTED (sensor match) <<<")
                        else:
                            self.node.get_logger().warning(
                                f"  Ignoring answer: sensor mismatch (expected={expected}, got={answer_sensor})"
                            )
                elif payload.get("type") == "candidate":
                    if payload.get("target") == "edge":
                        self._handle_candidate(payload)
            except Exception as e:
                self.node.get_logger().error(f"Error processing WebRTC message: {e}")
        
        self.client.subscribe(answer_topic, logging_on_answer)
        self.client.subscribe(candidate_topic, logging_on_answer)
        self.node.get_logger().info(f"=== SUBSCRIBED TO WEBRTC SIGNALING ===")
    
    async def _wait_for_answer(self, timeout: float = 60.0):
        """Override to add diagnostic logging while waiting for answer."""
        import time as time_mod
        
        self.node.get_logger().info(f"=== WAITING FOR WEBRTC ANSWER (timeout={timeout}s) ===")
        start_time = time_mod.time()
        last_log_time = start_time
        
        while not self._answer_received:
            elapsed = time_mod.time() - start_time
            
            if time_mod.time() - last_log_time >= 10.0:
                self.node.get_logger().warning(
                    f"  Still waiting for WebRTC answer... {elapsed:.1f}s elapsed"
                )
                last_log_time = time_mod.time()
            
            if elapsed > timeout:
                self.node.get_logger().error(
                    f"=== WEBRTC ANSWER TIMEOUT after {elapsed:.1f}s ==="
                )
                self.node.get_logger().error(
                    "  The cloud/backend is not responding to the WebRTC offer."
                )
                self.node.get_logger().error(
                    "  Check: 1) Cloud service is running, 2) MQTT connectivity, 3) Topic routing"
                )
                raise TimeoutError("Timeout waiting for WebRTC answer")
            
            await asyncio.sleep(0.1)
        
        elapsed = time_mod.time() - start_time
        self.node.get_logger().info(f"=== WEBRTC ANSWER RECEIVED in {elapsed:.1f}s ===")
        
        if self._answer_data is None:
            raise RuntimeError("Answer received flag set but answer data is None")
        
        import json
        answer = (
            json.loads(self._answer_data)
            if isinstance(self._answer_data, str)
            else self._answer_data
        )
        
        from aiortc import RTCSessionDescription
        await self.pc.setRemoteDescription(
            RTCSessionDescription(sdp=answer["sdp"], type=answer["type"])
        )
        self.node.get_logger().info("=== WEBRTC REMOTE DESCRIPTION SET ===")
