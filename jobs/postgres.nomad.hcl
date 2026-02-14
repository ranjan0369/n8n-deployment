job "postgres" {
  datacenters = ["dc1"]
  type = "service"

  group "postgres-group" {
    count = 1

    network {
      port "db" { static = 5432 }
    }

    volume "pgdata" {
      type      = "host"
      source    = "postgres-data"
      read_only = false
    }

    task "postgres" {
      driver = "docker"

      config {
        image = "postgres:15-alpine"
        ports = ["db"]
      }

      env {
        POSTGRES_DB       = "n8n"
        POSTGRES_USER     = "n8nuser"
        POSTGRES_PASSWORD = "n8npass"
      }

      volume_mount {
        volume      = "pgdata"
        destination = "/var/lib/postgresql/data"
      }

      service {
        name = "postgres"
        port = "db"
        provider = "consul"
        tags = ["db"]
        check {
          name     = "postgres_tcp"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}