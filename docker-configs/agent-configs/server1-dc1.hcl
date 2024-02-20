node_name = "consul-server1-dc1"
datacenter = "dc1"
server = true
license_path = "/consul/config/license"

log_level = "INFO"

peering { enabled = true }

primary_datacenter = "dc1"

connect {
  enabled = true
  enable_mesh_gateway_wan_federation = true
}

ui_config = {
  enabled = true

  metrics_provider = "prometheus"
  metrics_proxy = {
    base_url = "http://10.5.0.200:9090"
  }
}

data_dir = "/consul/data"

addresses = {
  http = "0.0.0.0"
  grpc = "0.0.0.0"
  grpc_tls = "0.0.0.0"
}

advertise_addr = "10.5.0.2"
advertise_addr_wan = "192.169.7.2"

ports = {
  grpc = 8502
  grpc_tls = 8503
  dns = 53
}

acl {
  enabled = true
  default_policy = "deny"
  down_policy = "extend-cache"
  enable_token_persistence = true
  enable_token_replication = true             # For WAN Fed

  tokens {
    initial_management = "root"
    agent = "root"
    default = ""
    replication = "root"                      # Replication token for WAN Fed. Cheating by using the root token. But whatever.
  }
}

auto_encrypt = {
  allow_tls = true
}

encrypt = "aPuGh+5UDskRAbkLaXRzFoSOcSM+5vAK+NEYOWHJH7w="

tls {
  defaults {
    ca_file = "/consul/config/certs/consul-agent-ca.pem"
    cert_file = "/consul/config/certs/dc1-server-consul-0.pem"
    key_file = "/consul/config/certs/dc1-server-consul-0-key.pem"

    verify_incoming = true
    verify_outgoing = true
  }
  internal_rpc {
    verify_server_hostname = true
  }
}

auto_reload_config = true