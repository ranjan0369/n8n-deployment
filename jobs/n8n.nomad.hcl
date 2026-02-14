job "n8n" {
  datacenters = ["dc1"]
  type = "service"

  group "n8n-group" {
    count = 1

    network {
      port "http" { static = 5678 }
    }

    volume "n8ndata" {
      type      = "host"
      source    = "n8n-data"
      read_only = false
    }

    task "n8n" {
      driver = "docker"

      config {
        image = "n8nio/n8n:latest"
        ports = ["http"]
      }

      env {
        DB_TYPE               = "postgresdb"
        DB_POSTGRESDB_HOST    = "postgres.service.consul"
        DB_POSTGRESDB_PORT    = "5432"
        DB_POSTGRESDB_DATABASE= "n8n"
        DB_POSTGRESDB_USER    = "n8nuser"
        DB_POSTGRESDB_PASSWORD= "n8npass"
        N8N_BASIC_AUTH_ACTIVE = "true"
        N8N_BASIC_AUTH_USER   = "admin"
        N8N_BASIC_AUTH_PASSWORD = "adminpass"
        N8N_HOST              = "n8n.tech-labs.space"
        N8N_PORT              = "5678"
        N8N_PROTOCOL          = "https"
      }

      volume_mount {
        volume      = "n8ndata"
        destination = "/home/node/.n8n"
      }

      resources {
        cpu = 500
        memory = 500
      }

      service {
        name = "n8n"
        port = "http"
        provider = "consul"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.n8n.rule=Host(`n8n.tech-labs.space`)",
          "traefik.http.routers.n8n.entrypoints=websecure",
          "traefik.http.routers.n8n.tls.certresolver=letsencrypt",
          "traefik.http.services.n8n.loadbalancer.server.port=5678"
        ]

        check {
          name     = "n8n_http"
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}