# PHASE 3: Application Deployment (N8N)

## 1. Overview
In this phase we will see how to deploy **n8n** application in nomad cluster that we setup in the previous phase. The components we will be deploying are as follows:
- PostgreSQL Database
- N8N Application	

We will use nomad job file to deploy the services and see how following components are used to configure them:
- `driver` block to use Docker as container runtime
- `env` block for setting environment variables
- `volume` block for persistent volume
- `service` block to register n8n in Consul

## 2. Running PostgreSQL Database:
First, we deploy a PostgreSQL database to store n8n application data. To ensure data durability, we configure a persistent volume backed by the DigitalOcean droplet’s local disk. The PostgreSQL data directory on the host is mapped to `/opt/postgres/data`, which will be used to persist database files across container restarts.

Before deploying the PostgreSQL job, the required directory must be created on the host with appropriate ownership and permissions to allow the containerized database to write data reliably.

```sh
sudo mkdir -p /opt/postgres/data
sudo chown -R 999:999 /opt/postgres/data
```

Now, we will define a nomad job file named `postgres.nomad.hcl` which will have following contents:

`postgres.nomad`

```hcl
job "postgres" {
  datacenters = ["dc1"]
  type        = "service"

  group "db" {
    count = 1

    network {
      port "db" {
        static = 5432
      }
    }

    task "postgres" {
      driver = "docker"

      config {
        image = "postgres:latest"

        ports = ["db"]

        volumes = [
          "/opt/postgres/data:/var/lib/postgresql/data"
        ]
      }

      env {
        POSTGRES_DB       = "n8ndb"
        POSTGRES_USER     = "n8nuser"
        POSTGRES_PASSWORD = "strongpassword123"
        PGDATA            = "/var/lib/postgresql/data/pgdata"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      service {
        name = "postgres"
        port = "db"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
```

Deploy the database using the command
```sh
nomad job run postgres.nomad.hcl
```

## 3.Running N8N:

After running postgres we will now define n8n.nomad job file to deploy n8n application. Before that it also needs a persistent volume to store application data so in the host machine we will do:
```sh
sudo mkdir -p /opt/n8n/data
sudo chown -R 1000:1000 /opt/n8n/data
```

Now create a job file named `n8n.nomad.hcl` and use the following content:

`n8n.nomad.hcl`
```hcl
job "n8n" {
  datacenters = ["dc1"]
  type        = "service"

  group "n8n" {
    count = 1

    network {
      port "http" {
        to = 5678
      }
    }

    task "n8n" {
      driver = "docker"

      config {
        image = "n8nio/n8n:latest"

        ports = ["http"]

        volumes = [
          "/opt/n8n/data:/home/node/.n8n"
        ]
      }

      env {
        # Basic
        N8N_BASIC_AUTH_ACTIVE = "true"
        N8N_BASIC_AUTH_USER   = "admin"
        N8N_BASIC_AUTH_PASSWORD = "admin123"

        N8N_HOST     = "n8n.service.consul"
        N8N_PORT     = "5678"
        N8N_PROTOCOL = "http"
        WEBHOOK_URL  = "http://n8n.service.consul"

        # Database configuration
        DB_TYPE       = "postgresdb"
        DB_POSTGRESDB_HOST = "postgres.service.consul"
        DB_POSTGRESDB_PORT = "5432"
        DB_POSTGRESDB_DATABASE = "n8ndb"
        DB_POSTGRESDB_USER     = "n8nuser"
        DB_POSTGRESDB_PASSWORD = "strongpassword123"
      }

      resources {
        cpu    = 500
        memory = 768
      }

      service {
        name = "n8n"
        port = "http"

        check {
          name     = "n8n-http"
          type     = "http"
          path     = "/healthz"
          interval = "10s"
          timeout  = "3s"
        }
      }
    }
  }
}
```

Deploy the application using the command
```sh
nomad job run n8n.nomad
```

Check the status of the job using
```sh
nomad job status postgres
nomad job status n8n
nomad alloc status <alloc-id>
```

Verify the application is deployed:
```sh
ssh -Nf -L 5678:localhost:5678 admin@droplet_public_ip
```

Open `http://localhost:5678` in your browser, we will see n8n setup page if everything is correct.
