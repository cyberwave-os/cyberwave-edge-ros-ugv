"""Edge-core driver container environment (CYBERWAVE_* vars).

edge-core injects these via ``driver_launcher._run_docker_image``. This module
loads them once at mqtt_bridge startup and logs presence (secrets masked).
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Mapping, MutableMapping, Optional

# Vars edge-core / credentials inject into the driver container.
def _strip(value: Optional[str]) -> str:
    return (value or "").strip()


def _parse_csv_uuids(raw: str) -> list[str]:
    out: list[str] = []
    for part in raw.split(","):
        uuid = part.strip()
        if uuid and uuid not in out:
            out.append(uuid)
    return out


def _mask_secret(value: str) -> str:
    if not value:
        return "(not set)"
    if len(value) <= 12:
        return "***"
    return f"{value[:6]}…{value[-4:]}"


def parse_bool_env(value: str | None) -> bool | None:
    """Parse common truthy/falsey env string values."""
    if value is None:
        return None
    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    return None


def get_first_env(*names: str, environ: Mapping[str, str] | None = None) -> str | None:
    source = os.environ if environ is None else environ
    for name in names:
        value = source.get(name)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def resolve_mqtt_topic_prefix(
    *,
    mqtt_topic_prefix: str | None = None,
    environment: str | None = None,
    environ: Mapping[str, str] | None = None,
) -> str:
    """Resolve MQTT topic prefix (matches ``cyberwave==0.5.0`` SDK semantics).

    Resolution order:
    1. ``mqtt_topic_prefix`` argument when non-empty
    2. ``CYBERWAVE_MQTT_TOPIC_PREFIX`` when set and non-empty
    3. ``environment`` argument or ``CYBERWAVE_ENVIRONMENT`` when not ``production``
    4. ``""`` (canonical production prefix)
    """
    source = os.environ if environ is None else environ

    explicit = mqtt_topic_prefix
    if explicit is None:
        explicit = source.get("CYBERWAVE_MQTT_TOPIC_PREFIX")
    if explicit is not None and str(explicit).strip():
        return str(explicit).strip()

    env_value = environment
    if env_value is None:
        env_value = source.get("CYBERWAVE_ENVIRONMENT", "")
    env_value = str(env_value or "").strip()
    if env_value and env_value.lower() != "production":
        return env_value
    return ""


def mqtt_port_from_env(default: int = 8883) -> int:
    port_raw = get_first_env("CYBERWAVE_MQTT_PORT")
    if not port_raw:
        return default
    try:
        return int(port_raw)
    except ValueError:
        return default


def resolve_mqtt_use_tls(
    *,
    port: int | None = None,
    use_tls_raw: str | None = None,
) -> bool:
    """Resolve MQTT TLS flag (edge-core + Python SDK semantics)."""
    raw = use_tls_raw
    if raw is None:
        raw = get_first_env("CYBERWAVE_MQTT_USE_TLS", "CYBERWAVE_MQTT_TLS")
    parsed = parse_bool_env(raw)
    if parsed is not None:
        return parsed
    effective_port = port if port is not None else mqtt_port_from_env()
    return effective_port == 8883


def ensure_mqtt_tls_env() -> None:
    """Set ``CYBERWAVE_MQTT_USE_TLS`` when unset (entrypoint + driver startup)."""
    if get_first_env("CYBERWAVE_MQTT_USE_TLS", "CYBERWAVE_MQTT_TLS"):
        return
    port = mqtt_port_from_env()
    os.environ["CYBERWAVE_MQTT_USE_TLS"] = "true" if port == 8883 else "false"


@dataclass(frozen=True)
class EdgeDriverEnv:
    """CYBERWAVE_* variables forwarded from edge-core into the driver container."""

    environment: str = ""
    environment_uuid: str = ""
    edge_log_level: str = ""
    worker_log_level: str = ""
    base_url: str = ""
    mqtt_host: str = ""
    mqtt_port: str = ""
    mqtt_use_tls: bool = False
    api_key: str = ""
    twin_uuid: str = ""
    twin_json_file: str = ""
    twin_uuids: list[str] = field(default_factory=list)
    child_twin_uuids: list[str] = field(default_factory=list)
    data_backend: str = ""
    zenoh_connect: str = ""
    zenoh_shared_memory: str = ""

    @property
    def mqtt_port_int(self) -> Optional[int]:
        if not self.mqtt_port:
            return None
        try:
            return int(self.mqtt_port)
        except ValueError:
            return None

    @property
    def debug_logs_enabled(self) -> bool:
        return self.edge_log_level.strip().lower() == "debug"

    def load_twin_json(self) -> Optional[dict[str, Any]]:
        if not self.twin_json_file:
            return None
        path = Path(self.twin_json_file)
        if not path.is_file():
            return None
        try:
            with path.open(encoding="utf-8") as handle:
                data = json.load(handle)
            return data if isinstance(data, dict) else None
        except (OSError, json.JSONDecodeError):
            return None


def load_edge_driver_env() -> EdgeDriverEnv:
    """Read standard edge-core driver env vars from the process environment."""
    ensure_mqtt_tls_env()
    return edge_driver_env_from_environ(os.environ)


def edge_driver_env_from_environ(environ: Mapping[str, str]) -> EdgeDriverEnv:
    """Build ``EdgeDriverEnv`` from an explicit env mapping (for tests and tooling)."""
    mqtt_host = (
        get_first_env("CYBERWAVE_MQTT_HOST", "CYBERWAVE_MQTT_BROKER", environ=environ)
        or ""
    )
    mqtt_port = _strip(environ.get("CYBERWAVE_MQTT_PORT"))
    port_int = None
    if mqtt_port:
        try:
            port_int = int(mqtt_port)
        except ValueError:
            port_int = None
    return EdgeDriverEnv(
        environment=_strip(environ.get("CYBERWAVE_ENVIRONMENT")),
        environment_uuid=_strip(environ.get("CYBERWAVE_ENVIRONMENT_UUID")),
        edge_log_level=_strip(environ.get("CYBERWAVE_EDGE_LOG_LEVEL")),
        worker_log_level=_strip(environ.get("CYBERWAVE_WORKER_LOG_LEVEL")),
        base_url=_strip(environ.get("CYBERWAVE_BASE_URL")),
        mqtt_host=mqtt_host,
        mqtt_port=mqtt_port,
        mqtt_use_tls=resolve_mqtt_use_tls(
            port=port_int,
            use_tls_raw=environ.get("CYBERWAVE_MQTT_USE_TLS")
            or environ.get("CYBERWAVE_MQTT_TLS"),
        ),
        api_key=_strip(environ.get("CYBERWAVE_API_KEY"))
        or _strip(environ.get("CYBERWAVE_TOKEN")),
        twin_uuid=_strip(environ.get("CYBERWAVE_TWIN_UUID")),
        twin_json_file=_strip(environ.get("CYBERWAVE_TWIN_JSON_FILE")),
        twin_uuids=_parse_csv_uuids(environ.get("CYBERWAVE_TWIN_UUIDS", "")),
        child_twin_uuids=_parse_csv_uuids(
            environ.get("CYBERWAVE_CHILD_TWIN_UUIDS", "")
        ),
        data_backend=_strip(environ.get("CYBERWAVE_DATA_BACKEND")),
        zenoh_connect=_strip(environ.get("ZENOH_CONNECT")),
        zenoh_shared_memory=_strip(environ.get("ZENOH_SHARED_MEMORY")),
    )


def resolve_broker_host(param_host: Any, env: EdgeDriverEnv) -> tuple[str, str]:
    """Resolve MQTT broker host; ``CYBERWAVE_MQTT_HOST`` wins over params.yaml."""
    if env.mqtt_host:
        return env.mqtt_host, "CYBERWAVE_MQTT_HOST"
    param = _strip(str(param_host)) if param_host is not None else ""
    if param:
        return param, "broker.host parameter"
    return "localhost", "default"


def resolve_broker_port(param_port: Any, env: EdgeDriverEnv) -> tuple[int, str]:
    """Resolve MQTT broker port; ``CYBERWAVE_MQTT_PORT`` wins over params.yaml."""
    if env.mqtt_port_int is not None:
        return env.mqtt_port_int, "CYBERWAVE_MQTT_PORT"
    if param_port is not None:
        try:
            return int(param_port), "broker.port parameter"
        except (TypeError, ValueError):
            pass
    return 8883, "default"


def apply_resolved_mqtt_to_environ(
    host: str,
    port: int,
    *,
    api_key: str = "",
    use_tls: bool | None = None,
    target: MutableMapping[str, str] | None = None,
) -> None:
    """Publish resolved broker settings into ``os.environ`` for the Cyberwave SDK."""
    dest = os.environ if target is None else target
    stripped_host = _strip(host)
    if stripped_host:
        dest["CYBERWAVE_MQTT_HOST"] = stripped_host
    dest["CYBERWAVE_MQTT_PORT"] = str(port)
    if use_tls is not None:
        dest["CYBERWAVE_MQTT_USE_TLS"] = "true" if use_tls else "false"
    if api_key:
        dest.setdefault("CYBERWAVE_API_KEY", api_key)


def log_edge_driver_env(logger: Any, env: EdgeDriverEnv) -> None:
    """Log edge driver env visibility for operators (secrets masked)."""
    twin_json_status = "not set"
    if env.twin_json_file:
        path = Path(env.twin_json_file)
        if path.is_file():
            twin_json_status = f"file ok ({path})"
        else:
            twin_json_status = f"missing ({path})"

    twin_uuids_summary = ",".join(env.twin_uuids) if env.twin_uuids else "(not set)"
    child_summary = (
        ",".join(env.child_twin_uuids) if env.child_twin_uuids else "(not set)"
    )
    topic_prefix = resolve_mqtt_topic_prefix(environment=env.environment)
    topic_family = (
        f"{topic_prefix}cyberwave/twin/<uuid>/…"
        if topic_prefix
        else "cyberwave/twin/<uuid>/…"
    )

    lines = [
        "--- Edge driver environment (from edge-core) ---",
        f"CYBERWAVE_ENVIRONMENT={env.environment or '(not set)'}",
        f"MQTT topic family={topic_family}",
        f"CYBERWAVE_ENVIRONMENT_UUID={env.environment_uuid or '(not set)'}",
        f"CYBERWAVE_EDGE_LOG_LEVEL={env.edge_log_level or '(not set)'}",
        f"CYBERWAVE_WORKER_LOG_LEVEL={env.worker_log_level or '(not set)'}",
        f"CYBERWAVE_BASE_URL={env.base_url or '(not set)'}",
        f"CYBERWAVE_MQTT_HOST={env.mqtt_host or '(not set)'}",
        f"CYBERWAVE_MQTT_PORT={env.mqtt_port or '(not set)'}",
        f"CYBERWAVE_MQTT_USE_TLS={str(env.mqtt_use_tls).lower()}",
        f"CYBERWAVE_API_KEY={_mask_secret(env.api_key)}",
        f"CYBERWAVE_TWIN_UUID={env.twin_uuid or '(not set)'}",
        f"CYBERWAVE_TWIN_JSON_FILE={twin_json_status}",
        f"CYBERWAVE_TWIN_UUIDS={twin_uuids_summary}",
        f"CYBERWAVE_CHILD_TWIN_UUIDS={child_summary}",
        f"CYBERWAVE_DATA_BACKEND={env.data_backend or '(not set)'}",
        f"ZENOH_CONNECT={env.zenoh_connect or '(not set)'}",
        f"ZENOH_SHARED_MEMORY={env.zenoh_shared_memory or '(not set)'}",
        "-----------------------------------------------",
    ]
    for line in lines:
        logger.info(line)

    missing_required: list[str] = []
    if not env.api_key:
        missing_required.append("CYBERWAVE_API_KEY")
    if not env.twin_uuid:
        missing_required.append("CYBERWAVE_TWIN_UUID")
    if not env.mqtt_host:
        missing_required.append("CYBERWAVE_MQTT_HOST")
    if missing_required:
        logger.warning(
            "Missing required edge driver env: " + ", ".join(missing_required)
        )

    if env.mqtt_port_int == 1883 and env.mqtt_use_tls:
        logger.warning(
            "CYBERWAVE_MQTT_USE_TLS=true with CYBERWAVE_MQTT_PORT=1883 — "
            "plain MQTT port; connection may fail unless the broker expects TLS"
        )
    elif env.mqtt_port_int == 8883 and not env.mqtt_use_tls:
        logger.warning(
            "CYBERWAVE_MQTT_USE_TLS=false with CYBERWAVE_MQTT_PORT=8883 — "
            "TLS port without TLS; connection may fail"
        )
