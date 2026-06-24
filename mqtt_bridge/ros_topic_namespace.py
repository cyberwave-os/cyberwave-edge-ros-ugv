"""Pure helpers for twin-scoped ROS topic namespacing."""

from __future__ import annotations


def resolve_ros_namespace(
    *,
    configured_namespace: str = "",
    twin_uuid: str | None = None,
) -> str:
    """Resolve the active ROS namespace, preferring an explicit override."""
    configured = str(configured_namespace or "").strip().strip("/")
    if configured:
        return configured
    twin = str(twin_uuid or "").strip().strip("/")
    return twin


def resolve_ros_topic(topic_name: str, namespace: str = "") -> str:
    """Return a fully-qualified ROS topic in the active namespace."""
    topic = str(topic_name or "").strip()
    if not topic:
        return topic
    base_topic = topic.lstrip("/")
    ns = str(namespace or "").strip().strip("/")
    if not ns:
        return f"/{base_topic}"
    if base_topic == ns or base_topic.startswith(f"{ns}/"):
        return f"/{base_topic}"
    return f"/{ns}/{base_topic}"
