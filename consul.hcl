# Consul Configuration for Single Node Setup
# Place this file in /etc/consul.d/consul.hcl or pass with -config-file flag

# Data directory for Consul state
data_dir = "/opt/consul/data"

# Node name
node_name = "consul-server-1"

# Server mode enabled
server = true

# Single node bootstrap (set to false in multi-node clusters)
bootstrap_expect = 1

# Bind address
bind_addr = "10.124.0.2"

# Advertise address - used for other agents to connect
advertise_addr = "10.124.0.2"

# Client address (where agents listen)
client_addr = "0.0.0.0"

# UI enabled
ui_config {
  enabled = true
}

# Service configuration
services = []

# DNS configuration
dns_config {
  # Enable DNS interface
  allow_stale = true

  # Maximum concurrent DNS queries
  max_stale = "87600h"

  # Node TTL
  node_ttl = "0s"

  # Service TTL
  service_ttl = {
    "*" = "0s"
  }

  # Enable DNS SRV records
  enable_truncate = true

  # UDP answer limit
  udp_answer_limit = 3

  # Prefer checks - ordering for health checks
  only_passing = false
}

# Performance tuning for single node
performance {
  raft_multiplier = 1
}

# ACLs (disabled for single node setup)
acl {
  enabled       = false
  default_policy = "allow"
}

# Telemetry
telemetry {
  prometheus_retention_time = "30s"
}

# Ports
ports {
  http   = 8500
  https  = -1
  dns    = 8600
  serf_lan = 8301
  serf_wan = 8302
  server = 8300
}

# Logging
log_level = "INFO"