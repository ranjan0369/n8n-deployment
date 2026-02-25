# PHASE 1: Research about the Application and Infrastructure

## 1. Understanding the Application (n8n)

N8n is a flexible, self-hosted workflow automation tool that serves as a central hub for orchestrating data flows and integrating various applications. It enables users to automate tasks and processes by connecting different services, offering over 300 integrations and native JavaScript support. N8n is designed to enhance marketing automation, data synchronization, and email delivery systems, providing a robust solution for managing complex workflows efficiently.

### Real-World Use Cases

Some of the real-world use cases for n8n are:

- When you get a new Gmail email → save attachment to Google Drive
- New GitHub issue → send message to Slack/Discord
- New form submission → add data to Google Sheets + send confirmation email
- Call APIs automatically (AWS, OpenAI, etc.)
- Schedule jobs (daily/weekly automation)

### Production-Ready N8N Setup

A typical production-ready n8n setup consists of the following components:

- **n8n** (Docker container)
- **PostgreSQL** (container or managed service)
- **Reverse Proxy** (TLS + domain routing)
- **Backups**
  - Postgres dumps
  - n8n config volume backup
- **Optional**
  - Redis + Worker mode for scaling

### Persistent Data in N8N

n8n persistent data includes:

1. Workflows (your automation definitions)
2. Credentials (stored encrypted)
3. Execution history (logs, workflow run results)
4. User accounts / settings (if using multi-user UI)
5. Encryption-related config

### Data Storage Location

The location of the data that needs to be persistent depends on the database being used.

#### If using SQLite:

- Stored in a file inside: `/home/node/.n8n`
- You **MUST** persist that folder as a Docker volume

#### If using PostgreSQL:

- Workflows/executions/users/credentials stored in Postgres
- But n8n still needs this folder persisted: `/home/node/.n8n`
- It can contain instance-specific config + encryption-related files

#### Production Best Practice:
Persist both:
- Postgres volume (or managed DB like AWS RDS)
- n8n volume: `/home/node/.n8n`

### N8N Configuration

n8n is configured mainly using environment variables.

#### Security & URLs

- `N8N_HOST` → domain name (example: `automation.example.com`)
- `N8N_PORT` → usually `5678`
- `N8N_PROTOCOL` → `https`
- `WEBHOOK_URL` → the public webhook base URL
- `N8N_ENCRYPTION_KEY` → important for production (must not change)

#### Authentication

We can enable built-in auth (basic auth) or use other methods depending on version/setup. The environment variables are:

- `N8N_BASIC_AUTH_ACTIVE` → `true` to enable authentication
- `N8N_BASIC_AUTH_USER`
- `N8N_BASIC_AUTH_PASSWORD`

#### Database Config

To enable the database (usually PostgreSQL), we use the following environment variables:

- `DB_TYPE=postgresdb`
- `DB_POSTGRESDB_HOST`
- `DB_POSTGRESDB_PORT`
- `DB_POSTGRESDB_DATABASE`
- `DB_POSTGRESDB_USER`
- `DB_POSTGRESDB_PASSWORD`

In production, these are usually managed via:

- `docker-compose.yml`
- `.env` file
- Kubernetes secrets/configmaps
---

## 2. Understanding the Infrastructure

We will be running n8n application on a Digital Ocean droplet orchestrated by HashiCorp Nomad and Consul for service discovery. Therefore, we need to get an idea about the infrastructure and components.

### 2.1 Digital Ocean Droplet

Digital Ocean Droplets are virtual private servers (VPS) that provide on-demand compute resources such as CPU, memory, storage, and networking similar to AWS EC2 instances but much simpler. Each Droplet runs a standard Linux or Windows operating system and offers full root access, allowing teams to deploy and manage applications, containers, and infrastructure components with minimal overhead. Droplets are commonly used as lightweight, scalable hosts for services such as Docker, Nomad, and Consul due to their simplicity, predictable pricing, and fast provisioning.

### 2.2 Docker

Docker is a containerization platform that enables applications and their dependencies to be packaged into lightweight, portable containers. Containers run consistently across different environments by sharing the host operating system while remaining isolated from one another. Docker simplifies application deployment, scaling, and versioning, making it widely used for building and running microservices and cloud-native workloads.

### 2.3 HashiCorp Nomad

HashiCorp Nomad is a workload orchestration tool similar to Kubernetes. However, unlike Kubernetes which can only run containers, Nomad supports various kinds of workloads such as VMs and raw binaries apart from Docker containers. Similarly, it is lighter weight than Kubernetes and has minimal hardware requirements.

Nomad follows a client-server architecture.

#### Nomad Server

Nomad servers are the control plane. They decide what runs where.

**Main responsibilities:**

- Accept job submissions
- Schedule workloads
- Maintain cluster state
- Elect a leader (via Raft)
- Store job and allocation metadata

**Key characteristics:**

- Run in odd numbers (3 or 5 recommended)
- Use Raft consensus for high availability
- Do not run user workloads (best practice)

#### Nomad Client

Nomad clients are the execution plane. In other words, they are the ones that actually run the workloads.

**Main responsibilities:**

- Register available resources (CPU, memory, disk)
- Execute workloads
- Report health and status back to servers
- Run task drivers (Docker, exec, etc.)

However, a single node can be configured to act as both server and client. This scenario is common in:

- Local development
- Learning environments
- Small labs
- Proof of concepts

**Example configuration:**

```hcl
server {
  enabled = true
}

client {
  enabled = true
}
```

In production:
- Servers and clients are separated
- Prevents workload noise from affecting scheduling
- Improves stability and security

#### How Nomad Workloads Run

The definition of a workload is written in a file called a **Nomad job file**. It is a declarative configuration file written in HCL. A job file typically describes:

- Application or workload
- Resource requirements
- Network ports
- Constraints
- Services (for Consul)
- Restart and update policies

**Basic example - Nginx container:**

```hcl
job "web-app" {
  datacenters = ["dc1"]
  type = "service"

  group "web" {
    count = 1

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:latest"
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
```

The workload is then run by using the command:

```bash
nomad job run app.nomad
```

#### Nomad Drivers

A Nomad driver is the plugin that tells Nomad how to run a task. Nomad itself does not run containers or binaries directly; it delegates execution to drivers.

**Common Nomad Drivers:**

| Driver | Purpose |
|--------|---------|
| docker | Run Docker containers |
| exec | Run raw binaries |
| raw_exec | Direct host execution |
| java | Run JVM applications |
| qemu | Run VMs |

### 2.4 HashiCorp Consul

Consul is a service networking tool. Its main job is to help services find each other, stay healthy, and communicate securely, especially in dynamic, cloud-native environments.

#### Without Consul (Nomad only):

- Services cannot automatically find each other
- No built-in health-aware discovery
- No service mesh or mTLS

#### With Consul available:

1. Nomad schedules a job on a client
2. The service is automatically registered in Consul
3. Consul performs health checks
4. Other services discover it via DNS/API
5. Unhealthy instances are removed automatically

**Example service registration in a Nomad job:**

```hcl
service {
  name = "api"
  port = "http"

  check {
    type     = "http"
    path     = "/health"
    interval = "10s"
    timeout  = "2s"
  }
}
```

---

## 3. Understanding the Secure Process

A secure process ensures that applications are deployed and operated in a way that protects data, credentials, and user interactions. This includes encrypting traffic using HTTPS, routing requests through a reverse proxy, issuing trusted certificates via Let's Encrypt, and securely managing sensitive information using proper secrets management practices. Together, these measures reduce attack surfaces, prevent data leakage, and establish trust between users and services.

### Why is Running N8N on HTTP Bad? What is HTTPS?

Running n8n over `http://` is insecure because all traffic is sent in plain text.

#### Risks of HTTP

- Login credentials can be intercepted
- API tokens and webhooks can be stolen
- Workflow data can be modified in transit
- Vulnerable to Man-in-the-Middle (MITM) attacks

#### What is HTTPS?

HTTPS (HTTP Secure) is HTTP over TLS encryption.

HTTPS provides:

- **Encryption** – data cannot be read in transit
- **Authentication** – you know you're talking to the real server
- **Integrity** – data cannot be altered silently

For tools like n8n, HTTPS is essential because it handles:

- Credentials
- API keys
- OAuth tokens
- Webhooks exposed to the internet

### What is a Reverse Proxy?

A reverse proxy is a server that sits in front of applications and handles incoming traffic on their behalf.

#### What a Reverse Proxy Does:

- Accepts requests from users
- Terminates HTTPS (TLS)
- Routes traffic to internal services
- Adds security headers
- Hides internal service details

#### Popular Reverse Proxies:

- Nginx
- Traefik
- Caddy

#### Example Flow:

```
User → HTTPS → Reverse Proxy → n8n (internal)
```

This allows your app to:

- Run on private IPs
- Avoid exposing ports directly
- Use one HTTPS entry point for many services

### What is Let's Encrypt?

Let's Encrypt is a free, automated Certificate Authority (CA).

It allows you to:

- Obtain HTTPS certificates at no cost
- Automatically renew certificates
- Enable HTTPS without manual work

Most modern reverse proxies (Traefik, Caddy, Nginx) can:

- Request certificates automatically
- Renew them before expiration
- Attach them transparently to services

### Why Shouldn't Passwords be Stored in Code Repositories?

Putting passwords directly in code is dangerous because:

- Repositories are often shared
- Commits are permanent (even after deletion)
- Secrets can be leaked publicly by accident
- Attackers actively scan GitHub for credentials

Once leaked, a secret must be considered compromised forever.

### What is Secrets Management?

In order to prevent secret leakage, we should follow proper secret management practices by securely storing, accessing, and rotating sensitive data such as:

- Database passwords
- API keys
- Tokens
- Certificates

Good secrets management ensures:

- Secrets are never hardcoded
- Access is restricted and auditable
- Secrets can be rotated without redeploying code

#### Common Approaches:

- Environment variables
- Encrypted config files
- Secret stores (e.g., HashiCorp Vault)
- Platform-integrated secrets (Nomad, Docker, Kubernetes)

---

## 4. Understanding the Automation (GitHub Actions)

CI/CD (Continuous Integration/Continuous Deployment) automates the process of integrating, testing, and deploying code changes to ensure fast and reliable software delivery. GitHub Actions enables CI/CD through workflows composed of jobs and steps executed by runners. Sensitive information required during automation, such as SSH keys or API tokens, is securely stored using GitHub Actions Secrets, which are encrypted and injected into workflows at runtime without being exposed in source code.

### Why CI/CD Matters

- Faster releases
- Fewer human errors
- Consistent deployments
- Higher confidence in production changes

### 4.1 GitHub Actions Concepts: Workflow, Job, Step, Runner

GitHub Actions is GitHub's built-in CI/CD platform. Some of the core concepts are as follows:

#### 4.1.1 Workflow

A workflow is the entire automation pipeline.

- It is defined in `.github/workflows/*.yml`
- It gets triggered by events like:
  - `push`
  - `pull_request`
  - `schedule`

#### 4.1.2 Job

A job is a set of steps that run together on the same machine.

- A workflow can have multiple jobs
- Jobs can run:
  - In parallel
  - Sequentially (with dependencies)

#### 4.1.3 Step

A step is a single action inside a job.

Examples:

- Checkout code
- Install dependencies
- Run tests
- Execute a shell command

Steps run in order inside a job.

#### 4.1.4 Runner

A runner is the machine that executes the job. There are basically two types of runners in GitHub Actions:

- **GitHub-hosted runners** (managed by GitHub)
- **Self-hosted runners** (your own server or VM)

Example runners:

- `ubuntu-latest`
- `windows-latest`

### 4.2 GitHub Actions Secrets

GitHub Actions Secrets are encrypted variables used to store sensitive data such as:

- SSH private keys
- API tokens
- Cloud credentials
- Database passwords

They are:

- Encrypted at rest
- Hidden from logs
- Not visible in repository code

#### Why Secrets Matter

Hardcoding credentials in a repository is dangerous because:

- Repos are shared
- Commits are permanent
- Accidental leaks are common
- Attackers scan public repos automatically

Once leaked, credentials must be revoked immediately.

#### How Secrets Are Used

Secrets are injected at runtime as environment variables.

**Example:**

```yaml
env:
  SSH_KEY: ${{ secrets.SSH_KEY }}
```

Or directly in a step:

```yaml
- run: ssh -i ${{ secrets.SSH_KEY }} user@server
```

The secret:

- Is never printed
- Is never stored in the repo
- Exists only during workflow execution

Secrets can be scoped at:

- Repository level
- Environment level (e.g., staging, production)
- Organization level

### Complete GitHub Actions Workflow Example

Below is a complete GitHub Actions workflow example that uses secrets and deploys a Docker container whenever there is a push to the main branch:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches:
      - main

jobs:
  deploy:
    name: Build and Deploy Application
    runs-on: ubuntu-latest # Github-hosted Runner

    steps:
      # Step 1: Checkout source code
      - name: Checkout repository
        uses: actions/checkout@v4

      # Step 2: Build Docker image
      - name: Build Docker image
        run: |
          docker build -t my-app:latest .

      # Step 3: Deploy to server via SSH
      - name: Deploy to server
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /opt/my-app
            git pull origin main
            docker compose down
            docker compose up -d --build
```