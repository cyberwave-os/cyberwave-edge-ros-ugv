"""Tests for edge_driver_env."""

from mqtt_bridge.edge_driver_env import (
    EdgeDriverEnv,
    apply_resolved_mqtt_to_environ,
    edge_driver_env_from_environ,
    resolve_broker_host,
    resolve_broker_port,
    resolve_mqtt_topic_prefix,
)


def test_edge_driver_env_from_environ_reads_all_forwarded_vars():
    env = edge_driver_env_from_environ(
        {
            "CYBERWAVE_ENVIRONMENT": "local",
            "CYBERWAVE_EDGE_LOG_LEVEL": "debug",
            "CYBERWAVE_BASE_URL": "http://10.13.4.222:8000",
            "CYBERWAVE_MQTT_HOST": "10.13.4.222",
            "CYBERWAVE_MQTT_PORT": "1883",
            "CYBERWAVE_MQTT_USE_TLS": "false",
            "CYBERWAVE_API_KEY": "cw_test_key_123456",
            "CYBERWAVE_TWIN_UUID": "twin-a",
            "CYBERWAVE_TWIN_JSON_FILE": "/app/twin.json",
            "CYBERWAVE_CHILD_TWIN_UUIDS": "cam-1, cam-2",
        }
    )

    assert env.environment == "local"
    assert env.edge_log_level == "debug"
    assert env.debug_logs_enabled is True
    assert env.base_url == "http://10.13.4.222:8000"
    assert env.mqtt_host == "10.13.4.222"
    assert env.mqtt_port == "1883"
    assert env.mqtt_port_int == 1883
    assert env.mqtt_use_tls is False
    assert env.api_key == "cw_test_key_123456"
    assert env.twin_uuid == "twin-a"
    assert env.twin_json_file == "/app/twin.json"
    assert env.child_twin_uuids == ["cam-1", "cam-2"]


def test_resolve_broker_port_env_overrides_params_yaml():
    env = EdgeDriverEnv(mqtt_port="1883")
    port, source = resolve_broker_port(8883, env)
    assert port == 1883
    assert source == "CYBERWAVE_MQTT_PORT"


def test_resolve_broker_port_uses_params_when_env_unset():
    env = EdgeDriverEnv()
    port, source = resolve_broker_port(8883, env)
    assert port == 8883
    assert source == "broker.port parameter"


def test_edge_driver_env_api_key_falls_back_to_token():
    env = edge_driver_env_from_environ({"CYBERWAVE_TOKEN": "legacy-token"})
    assert env.api_key == "legacy-token"


def test_resolve_broker_host_env_wins_over_params_yaml():
    env = EdgeDriverEnv(mqtt_host="dev.mqtt.cyberwave.com")
    host, source = resolve_broker_host("mqtt.cyberwave.com", env)
    assert host == "dev.mqtt.cyberwave.com"
    assert source == "CYBERWAVE_MQTT_HOST"


def test_resolve_broker_host_falls_back_to_params_then_localhost():
    env = EdgeDriverEnv()
    host, source = resolve_broker_host("broker.example.com", env)
    assert host == "broker.example.com"
    assert source == "broker.host parameter"

    host, source = resolve_broker_host("", env)
    assert host == "localhost"
    assert source == "default"


def test_apply_resolved_mqtt_to_environ_syncs_sdk_env():
    environ: dict[str, str] = {}
    apply_resolved_mqtt_to_environ(
        "dev.mqtt.cyberwave.com",
        8883,
        api_key="cw_test",
        use_tls=True,
        target=environ,
    )

    assert environ["CYBERWAVE_MQTT_HOST"] == "dev.mqtt.cyberwave.com"
    assert environ["CYBERWAVE_MQTT_PORT"] == "8883"
    assert environ["CYBERWAVE_MQTT_USE_TLS"] == "true"
    assert environ["CYBERWAVE_API_KEY"] == "cw_test"


def test_resolve_mqtt_topic_prefix_from_environment():
    assert resolve_mqtt_topic_prefix(environment="dev") == "dev"


def test_resolve_mqtt_topic_prefix_production_is_empty():
    assert resolve_mqtt_topic_prefix(environment="production") == ""


def test_resolve_mqtt_topic_prefix_explicit_overrides_environment():
    assert (
        resolve_mqtt_topic_prefix(mqtt_topic_prefix="custom", environment="dev")
        == "custom"
    )


def test_resolve_mqtt_topic_prefix_reads_from_environ_mapping():
    assert (
        resolve_mqtt_topic_prefix(
            environ={
                "CYBERWAVE_ENVIRONMENT": "staging",
                "CYBERWAVE_MQTT_TOPIC_PREFIX": "override",
            }
        )
        == "override"
    )
