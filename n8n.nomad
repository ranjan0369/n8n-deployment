job "n8n" {
  datacenters = ["dc1"]
  type        = "service"

  group "n8n" {
    count = 1

    network {
      mode = "host"
      port "http" {
        static = 5678
      }
    }

    volume "n8n_data" {
      type      = "host"
      read_only = false
      source    = "n8n_data"
    }

    service {
      name     = "n8n"
      provider = "consul"
      port     = "http"
      tags     = ["web", "http"]

      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "n8n" {
      driver = "docker"

      config {
        image = "n8nio/n8n:latest"
        ports = ["http"]
      }

      volume_mount {
        volume = "n8n_data"
        destination = "/home/node/.n8n"
        read_only = false
      }

      env {
        N8N_BASIC_AUTH_ACTIVE     = "true"
        N8N_BASIC_AUTH_USER       = "admin"
        N8N_BASIC_AUTH_PASSWORD   = "admin@123"  # Change this
        N8N_PROTOCOL              = "http"
        N8N_HOST                  = "0.0.0.0"
        N8N_PORT                  = "5678"
        N8N_SECURE_COOKIE         = "false"

        # Database Configuration
        # Use host IP address for inter-service communication on host network mode
        DB_TYPE                   = "postgresdb"
        DB_POSTGRESDB_HOST        = "143.198.48.187"
        DB_POSTGRESDB_PORT        = "5432"
        DB_POSTGRESDB_DATABASE    = "n8n"
        DB_POSTGRESDB_USER        = "postgres"
        DB_POSTGRESDB_PASSWORD    = "admin@123"  # Must match postgres job
        DB_POSTGRESDB_SSL_ENABLED = "false"


        # Optional: Logging
        LOG_LEVEL                 = "info"
      }

      logs {
        max_files     = 5
        max_file_size = 20
      }
    }
  }
}

# Nomad Client Configuration Required:
# Add this to your Nomad client config (/etc/nomad.d/client.hcl):
#
# client {
#   host_volume "n8n_data" {
#     path      = "/opt/nomad/volumes/n8n"
#     read_only = false
#   }
# }
#
# Ensure directory exists:
# sudo mkdir -p /opt/nomad/volumes/n8n
# sudo chown 1000:1000 /opt/nomad/volumes/n8n
#
# Make sure your Nomad client can resolve .service.consul domains:
# Ensure Consul DNS is available at 127.0.0.1:8600 or configure via
# Nomad's dns stanza: dns { servers = ["127.0.0.1:8600"] }