
# PHASE 4: Secure Implementation and Hardening

This phase focuses on securely exposing the N8N workflow automation service to the internet, implementing HTTPS, managing secrets safely, and ensuring robust infrastructure hardening. Proper implementation of this phase is critical to maintain system security, confidentiality, and reliability.

## 1. Overview

Exposing services like N8N to the internet introduces potential security risks. This phase addresses these risks by:

1. Deploying a reverse proxy (Traefik) to manage incoming traffic securely.
2. Implementing HTTPS encryption using Let’s Encrypt.
3. Managing sensitive credentials via Consul KV instead of hard-coding them in job files.
4. Using Nomad template stanzas to dynamically inject secrets into environment variables.

## 2. Key Concepts

### 2.1 Traefik as a Reverse Proxy

Traefik is an open-source, modern reverse proxy and load balancer designed for dynamic microservices environments. It automatically detects services and routes traffic based on rules and labels, simplifying secure internet exposure of containerized applications.

**Usage with Nomad:**

- Traefik can run as a Nomad job using the Docker driver.
- It monitors services registered in Consul and automatically updates routing rules.
- It handles HTTP(S) traffic, SSL termination, and redirection.

### 2.2 Consul Catalog Provider

Traefik’s Consul Catalog provider integrates with Consul’s service registry:

- Automatically discovers services (e.g., N8N) registered in Consul.
- Dynamically generates routing rules based on service tags.
- Ensures minimal manual configuration when services scale or change.

### 2.3 Let’s Encrypt Integration

Traefik can automatically generate and renew SSL certificates through Let’s Encrypt:

- Certificates are free and automatically managed.
- The certresolver configuration in Traefik handles certificate issuance.
- Supports both HTTP-01 and TLS-ALPN-01 challenges for domain validation.

### 2.4 Consul KV for Secrets Management

Consul KV can serve as a lightweight secrets manager:

- Store sensitive data such as database passwords or API keys.
- Use Nomad templates to inject secrets into environment variables at runtime.
- Reduces the risk of exposing secrets in job files or version control.

### 2.5 Nomad Template Stanza

Nomad supports template stanzas that allow:

- Reading secrets from Consul KV or other sources.
- Writing secret values to temporary files or environment variables.
- Secure injection of secrets into jobs without hard-coding credentials.

**Example:**

```hcl
template {
  data = "{{ key \"secrets/n8n/db_password\" }}"
  destination = "secrets/db_password.env"
  env = true
}
```

This reads the PostgreSQL password from Consul and exposes it as an environment variable for N8N.

## 3. Implementation Steps

### 3.1 Store Secrets in Consul

1. Save the PostgreSQL password in Consul KV:

   ```sh
   consul kv put secrets/n8n/db_password YOUR_SECURE_PASSWORD
   ```

2. Ensure the key is stored securely and only accessible to authorized services.

### 3.2 Update N8N Nomad Job

1. Remove any hard-coded passwords from the env block.
2. Add a template stanza to inject the secret from Consul:

   ```hcl
   template {
     data = "{{ key \"secrets/n8n/db_password\" }}"
     destination = "secrets/db_password.env"
     env = true
   }
   ```

3. Restart the N8N job to apply the changes:

   ```sh
   nomad job run n8n.nomad
   ```

4. Confirm N8N is running successfully.

### 3.3 Deploy Traefik as a Nomad Job

1. Create a `traefik.nomad.hcl` job file:

   ```hcl
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
            "--certificatesresolvers.letsencrypt.acme.email=example@email.com",
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
   ```

2. Configure:
   - Consul Catalog provider: auto-detect N8N service.
   - Let’s Encrypt resolver: include your email for certificate issuance.

### 3.4 Expose N8N via Traefik

1. Add Traefik-specific tags to N8N service block:

   ```hcl
   service {
     name = "n8n"
     tags = [
          "traefik.enable=true",
          "traefik.http.routers.n8n.rule=Host(`n8n.domain.com`)",
          "traefik.http.routers.n8n.entrypoints=websecure",
          "traefik.http.routers.n8n.tls.certresolver=letsencrypt",
          "traefik.http.services.n8n.loadbalancer.server.port=5678"
        ]
   }
   ```

2. Restart the N8N job to register with Traefik:

   ```sh
   nomad job run n8n.nomad
   nomad job run traefik.nomad
   ```

### 3.5 Update DNS

1. Point your subdomain (`n8n.domain.com`) to your server/Droplet public IP.
2. Wait for DNS propagation (typically a few minutes).

### 3.6 Verification

1. Visit your domain over HTTPS:

   https://n8n.your-domain.com

2. Confirm:
   - N8N instance is accessible.
   - Browser shows a valid lock icon, indicating a secure SSL connection.
   - Secrets (e.g., database password) are loaded properly from Consul KV.

## 4. Summary

Phase 4 ensures that N8N is:

- Securely exposed to the internet using HTTPS.
- Protected from secret leaks by leveraging Consul KV.
- Scalable and maintainable via Nomad templates and Traefik auto-discovery.
- Managed dynamically without manual intervention for certificates or routing rules.

By completing this phase, the infrastructure adheres to best practices in secure deployment, secret management, and internet-facing service hardening.
