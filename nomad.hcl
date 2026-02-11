# Nomad Server and Client Configuration for Single Node Setup
# Place this file in /etc/nomad.d/nomad.hcl or pass with -config flag

# Data directory for Nomad state
data_dir = "/opt/nomad/data"

# Bind addresses
bind_addr = "0.0.0.0"

# Advertise address - clients will use this to connect to the server
advertise {
  http = "10.124.0.2"
  rpc  = "10.124.0.2"
  serf = "10.124.0.2"
}

# Server configuration
server {
  # Enable server mode
  enabled = true

  # Number of servers in the cluster (single node = 1)
  bootstrap_expect = 1

  # Server data directory
  data_dir = "/opt/nomad/data/server"

  # Retry join addresses (useful for cluster recovery)
  # retry_join = ["10.124.0.2:4648"]
}

# Client configuration
client {
  enabled = true

  # Nomad server addresses for client registration
  servers = ["127.0.0.1:4647"]

  # Node class for scheduling
  node_class = "general"

  # Metadata about this node
  meta {
    environment = "production"
    region      = "local"
  }

  # Host volumes for persistent storage
  host_volume "postgres_data" {
    path      = "/opt/nomad/volumes/postgres"
    read_only = false
  }

  host_volume "n8n_data" {
    path      = "/opt/nomad/volumes/n8n"
    read_only = false
  }

  # Docker driver configuration
  options = {
    "driver.docker.volumes.enabled" = "true"
    "driver.docker.auth.config"     = "/root/.docker/config.json"
    "driver.docker.cleanup.image"   = "true"
    "driver.docker.image.gc"        = "true"
    "driver.docker.image.gc.image_delay" = "3m"
  }

}

# Consul integration for service discovery
consul {
  # Enable Consul integration
  enabled = true

  # Consul server address
  address = "10.124.0.2:8500"

  # Use TLS for Consul communication
  ssl = false

  # Auto-join Consul cluster
  auto_join = true

  # Service name registration prefix
  service_registration {
    enabled = true
  }
}

# Logs
log_level = "INFO"

# UI
ui = {
  enabled = true
}

# Ports configuration
ports {
  http = 4646
  rpc  = 4647
  serf = 4648
}

# Leave gracefully on interrupt
leave_on_interrupt = true
leave_on_terminate = true