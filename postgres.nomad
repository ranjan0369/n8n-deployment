job "postgres" {
  datacenters = ["dc1"]
  type        = "service"

  group "postgres" {
    count = 1

    network {
      mode = "host"
      port "db" {
        static = 5432
      }
    }

    volume "postgres_data" {
      type      = "host"
      read_only = false
      source    = "postgres_data"
    }

    service {
      name     = "postgres"
      provider = "consul"
      port     = "db"
      tags     = ["database", "sql"]

      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "postgres" {
      driver = "docker"

      config {
        image = "postgres:15-alpine"
        ports = ["db"]
        args  = ["-c", "listen_addresses=*"]
      }

      volume_mount {
        volume = "postgres_data"
        destination = "/var/lib/postgresql/data"
        read_only = false
        }

      env {
        POSTGRES_USER                = "postgres"
        POSTGRES_PASSWORD            = "admin@123"  # Change this
        POSTGRES_DB                  = "n8n"
        PGDATA                       = "/var/lib/postgresql/data/pgdata"
      }

      resources {
        cpu    = 500
        memory = 512
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
#   host_volume "postgres_data" {
#     path      = "/opt/nomad/volumes/postgres"
#     read_only = false
#   }
# }
#
# Ensure directory exists:
# sudo mkdir -p /opt/nomad/volumes/postgres
# sudo chown 1000:1000 /opt/nomad/volumes/postgres