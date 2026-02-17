job "traefik" {
  datacenters = ["dc1"]
  type = "service"

  group "traefik-group" {
    count = 1

    network {
      port "web" {
        static = 80
      }

      port "websecure" {
        static = 443
      }

      port "dashboard" {
        static = 8080
      }
    }

    volume "traefik-letsencrypt" {
      type      = "host"
      source    = "traefik-letsencrypt"
      read_only = false
    }

    task "traefik" {
      driver = "docker"

      config {
        image = "traefik:v2.11"
        ports = ["web", "websecure", "dashboard"]
        network_mode = "host"
        args = [
          "--api.dashboard=true",
          "--api.insecure=true",

          "--providers.consulcatalog=true",
          "--providers.consulcatalog.endpoint.address=consul.service.consul:8500",

          "--entrypoints.web.address=:80",
          "--entrypoints.websecure.address=:443",


          "--certificatesresolvers.letsencrypt.acme.tlschallenge=true",
          "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web",
          "--certificatesresolvers.letsencrypt.acme.email=ranjan.shrestha0369@gmail.com",
          "--certificatesresolvers.letsencrypt.acme.storage=/etc/traefik/letsencrypt/acme.json"
        ]
      }

      volume_mount {
        volume      = "traefik-letsencrypt"
        destination = "/etc/traefik/letsencrypt"
      }

      service {
        name = "traefik"
        port = "web"

        check {
          type     = "http"
          path     = "/dashboard/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}