# N8N Deployment on Nomad with Ansible Automation

Enterprise-grade infrastructure automation for deploying n8n (workflow automation platform) on a single-node or multi-node HashiCorp Nomad cluster. This project uses **Ansible** to fully automate the provisioning, configuration, and deployment of all components including Traefik reverse proxy, PostgreSQL database, and Consul service discovery.

**Deployment Time**: 5-10 minutes (fully automated)  
**Target Environment**: Ubuntu 20.04+ (Single Node or Multi-Node)  
**Infrastructure as Code**: Yes - Ansible playbooks + Nomad job files  

---

## Architecture Overview

### System Design

The infrastructure consists of three tightly integrated layers working in harmony:

```
┌─────────────────────────────────────────────────────────────────┐
│              Single-Node Nomad Cluster                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │           LAYER 1: API Gateway & Routing               │    │
│  │  Traefik (Reverse Proxy, SSL/TLS, Load Balancing)      │    │
│  │  Ports: 80 (HTTP), 443 (HTTPS), 8080 (Dashboard)       │    │
│  └────────────────────────────────────────────────────────┘    │
│                           ↓                                     │
│  ┌────────────────────────────────────────────────────────┐    │
│  │        LAYER 2: Application & Orchestration            │    │
│  │  N8N (Workflow Automation Engine)                      │    │
│  │  Port: 5678  |  Health Checks & Service Registration   │    │
│  └────────────────────────────────────────────────────────┘    │
│                           ↓                                     │
│  ┌────────────────────────────────────────────────────────┐    │
│  │         LAYER 3: Data Persistence & Discovery          │    │
│  │  PostgreSQL (Database) | Consul (Service Discovery)    │    │
│  │  Ports: 5432 (DB) | 8500 (HTTP), 8600 (DNS)            │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │      STORAGE LAYER: Persistent Host Volumes             │    │
│  │  [traefik_data] [n8n_data] [postgres_data]             │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                  ↑
          Host Network (<droplet's public ip>)
```

### Data Flow

```
User Request (HTTPS) 
    ↓
Traefik → Receives request on ports 80/443
    ↓
Traefik → Consults Consul Catalog for N8N service IP
    ↓
Traefik → Routes to N8N application (5678)
    ↓
N8N → Executes workflow logic
    ↓
N8N → Queries PostgreSQL for workflow/execution data (5432)
    ↓
PostgreSQL → Returns data
    ↓
N8N → Returns response to Traefik
    ↓
Traefik → Returns HTTPS response to user
```

---

## Ansible Automation Philosophy

Instead of manual configuration steps, this project uses **Infrastructure as Code** with Ansible. Every component is provisioned automatically, making deployment:
- **Repeatable**: Deploy 100 times, get identical results
- **Documented**: Code tells you exactly what's happening
- **Testable**: Run playbooks in test environments first
- **Scalable**: Add more nodes with minimal effort
- **Maintainable**: Update infrastructure by changing code, not manually via SSH

### What Ansible Automates

| Layer | Component | Automation | Playbook |
|-------|-----------|-----------|----------|
| **Infrastructure** | Docker | Install, configure daemon, enable service | `docker.yml` |
| **Infrastructure** | System Hardening | Security tuning, kernel parameters | `infra_hardening.yml` |
| **Infrastructure** | Persistent Storage | Create volume directories, set permissions | `create-host-volumes.yml` |
| **Orchestration** | Nomad | Install, configure server+client, start agent | `nomad.yml` |
| **Discovery** | Consul | Install, configure server, start agent | `consul.yml` |
| **Services** | Job Deployment | Copy Nomad job files, deploy services | `copy-job-files.yml` |
| **Orchestration** | Master Playbook | Runs all playbooks in correct order | `initialize.yml` |

### Project Structure

```
ansible/
├── ansible.cfg                    # Ansible runtime configuration
├── inventory/
│   ├── hosts.ini                 # Target hosts & groups
│   └── group_vars/
│       ├── nomad_servers.yml     # Nomad server variables
│       ├── nomad_clients.yml     # Nomad client variables
│       └── consul_servers.yml    # Consul server variables
│
├── playbooks/                    # Executable playbooks
│   ├── initialize.yml            # ✈️ Master playbook (RUN THIS)
│   ├── docker.yml                # Container runtime
│   ├── infra_hardening.yml       # Security & tuning
│   ├── create-host-volumes.yml   # Persistent storage
│   ├── nomad.yml                 # Orchestration engine
│   ├── consul.yml                # Service discovery
│   └── copy-job-files.yml        # Service deployment
│
└── roles/                        # Reusable components
    ├── docker/                   # Docker installation
    ├── nomad/                    # Nomad setup
    ├── consul/                   # Consul setup
    └── infra_hardening/          # Security hardening
```

---

## Prerequisites

### Hardware Requirements
- **CPU**: 4 cores minimum (8+ cores recommended for production)
- **RAM**: 8GB minimum (16GB+ recommended for production)
- **Disk**: 50GB+ free space
- **Network**: Static IP or DHCP with DNS resolution

### Software Requirements (Control Machine)
- Ansible 2.9 or higher
- Python 3.8 or higher
- SSH client
- `ansible-core>=2.12` recommended

### Target Machine Requirements
- Ubuntu 20.04 LTS or later
- SSH access with key-based authentication
- `sudo` privileges without password prompt
- Internet connectivity for package downloads
- No Docker/Nomad/Consul pre-installed (Ansible will handle it)

### Pre-Deployment Verification

On your control machine:
```bash
# Verify Ansible
ansible --version

# Verify Python
python3 --version

# SSH key exists
ls -la ~/.ssh/id_rsa

# SSH connectivity to target
ssh -i ~/.ssh/id_rsa root@<droptlet_public_ip> "echo Connection OK"
```

---

## Quick Deployment (5 minutes)

### Step 1: Configure Target Hosts

Edit the Ansible inventory to specify your deployment target:

```bash
# Edit inventory
code ansible/inventory/hosts.ini
```

**Example - Single Node Deployment:**
```ini
[nomad_servers]
n8n-prod ansible_host=<droplet's public ip> ansible_user=dgouser

[nomad_clients]
n8n-prod ansible_host=<droplet's public ip> ansible_user=dgouser

[consul_servers]
n8n-prod ansible_host=<droplet's public ip> ansible_user=dgouser

[all:vars]
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_become=yes
ansible_become_user=root
ansible_become_method=sudo
```

**Example - Multi-Node Deployment:**
```ini
[nomad_servers]
nomad-server-1 ansible_host=<droplet's public ip> ansible_user=dgouser

[nomad_clients]
nomad-client-1 ansible_host=10.124.0.3 ansible_user=dgouser
nomad-client-2 ansible_host=10.124.0.4 ansible_user=dgouser

[consul_servers]
nomad-server-1 ansible_host=<droplet's public ip> ansible_user=dgouser

[all:vars]
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_become=yes
ansible_become_user=root
ansible_become_method=sudo
```

### Step 2: Update Deployment Variables

Review and customize variables for your environment:

```bash
# For Nomad servers
vi ansible/inventory/group_vars/nomad_servers.yml

# For Consul servers  
vi ansible/inventory/group_vars/consul_servers.yml
```

**Critical Variables to Update:**

```yaml
# ansible/inventory/group_vars/nomad_servers.yml

# PostgreSQL
postgres_user: "postgres"
postgres_password: "CHANGE_ME_SECURE_PASSWORD_123"      # ⚠️ CHANGE THIS

# N8N
n8n_user: "admin"
n8n_password: "CHANGE_ME_ANOTHER_SECURE_PASSWORD_456"  # ⚠️ CHANGE THIS

# System
nomad_version: "1.5.0"
consul_version: "1.15.0"
docker_version: "latest"
```

### Step 3: Run the Master Playbook

Deploy everything automatically:

```bash
cd ansible

# Run each playbook one by one in the following order
ansible-playbook playbooks/initialize.yml
ansible-playbook playbooks/docker.yml
ansible-playbook playbooks/create-host-volumes.yml
ansible-playbook playbooks/nomad.yml
ansible-playbook playbooks/consul.yml
ansible-playbook playbooks/copy-job-files.yml

# Monitor progress - watch for:
# - TASK [...] - Each step
# - ok/changed - Success indicator
# - FAILED - Any errors
```

**Expected Duration**: 5-10 minutes

### Step 4: Verify Deployment

After the playbook completes:

```bash
# SSH into deployed server
ssh dgouser@<droplet's public ip>

# Check Nomad
nomad status
nomad node status

# Check Consul
consul members
consul catalog services

# Check services running
nomad status postgres
nomad status n8n
nomad status traefik
```

---

## Accessing Services

Once deployment completes, all services are immediately available:

### N8N Application (Main Interface)
```
URL: https://n8n.tech-labs.space
Username: admin
Password: (configured in variables)
Purpose: Workflow automation, API integrations, scheduling
```

**First Login:**
1. Navigate to `https://<droplet's public ip>`
2. You may see self-signed certificate warning (normal)
3. Click "Proceed" or "Advanced"
4. Login with credentials from variables

### Nomad Dashboard (Job Management)
```
ssh -Nf -L 4646:localhost:4646 dgouser@<droplet's public ip>
URL: http://localhost:4646
Purpose: View jobs, allocations, logs, resource usage
```

### Consul UI (Service Registry)
```
ssh -Nf -L 8500:localhost:8500 dgouser@<droplet's public ip>
URL: http://localhost:8500
Purpose: Service discovery, health checks, key-value store
```

### Traefik Dashboard (Routing Status)
```
URL: http://<droplet's public ip>:8080
Purpose: View active routes, certificates, middleware
```
---

## Operations & Monitoring

### Check Service Status

```bash
# From control machine
ansible nomad_servers -m shell -a "nomad status"

# Or SSH in and run directly
ssh dgouser@<droplet's public ip>

# View all jobs
nomad status

# View specific job details
nomad status postgres
nomad status n8n
nomad status traefik
```

### View Service Logs

```bash
ssh dgouser@<droplet's public ip>

# Real-time logs (N8N)
nomad logs -job n8n -f

# Last 50 lines (PostgreSQL)
nomad logs -job postgres -tail 50

# Traefik logs
nomad logs -job traefik -tail 100
```

### Monitor System Resources

```bash
ssh dgouser@<droplet's public ip>

# Nomad resource usage
nomad node status -self

# Consul member status
consul members

# Docker resources
docker stats

# System memory
free -h

# Disk usage
df -h
```

### Database Administration

```bash
ssh dgouser@<droplet's public ip>

# Connect to PostgreSQL
psql -h 127.0.0.1 -U postgres -d n8n

# Inside psql:
\dt                    # List tables
\l                     # List databases
SELECT version();      # PostgreSQL version
SELECT pg_size_pretty(pg_database_size('n8n'));  # DB size
```

---

## 🔄 Common Operations

### Restart a Service

```bash
ssh dgouser@<droplet's public ip>

# Restart N8N
nomad stop n8n
sleep 5
nomad run /opt/nomad/jobs/n8n.nomad.hcl

# Or all services
nomad stop postgres n8n traefik
sleep 5
nomad run /opt/nomad/jobs/postgres.nomad.hcl
nomad run /opt/nomad/jobs/traefik.nomad.hcl
nomad run /opt/nomad/jobs/n8n.nomad.hcl
```

### Backup Data

```bash
ssh dgouser@<droplet's public ip>

# PostgreSQL backup to file
pg_dump -h 127.0.0.1 -U postgres -d n8n > n8n_backup.sql
scp dgouser@<droplet's public ip>:n8n_backup.sql /local/backup/path/

# N8N data backup
sudo tar -czf n8n-data-backup.tar.gz /opt/nomad/volumes/n8n/

# Traefik certificates backup
sudo tar -czf traefik-certs-backup.tar.gz /opt/nomad/volumes/traefik/
```

### Restore from Backup

```bash
ssh dgouser@<droplet's public ip>

# PostgreSQL restore
psql -h 127.0.0.1 -U postgres -d n8n < backup.sql

# N8N data restore
sudo tar -xzf n8n-data-backup.tar.gz -C /
sudo systemctl restart nomad

# Service verification
nomad status
```

### Scale to Multiple Nodes (Advanced)

```bash
# 1. Add new hosts to inventory
vi ansible/inventory/hosts.ini
# Add entries in [nomad_clients] section

# 2. Deploy Nomad to new clients
ansible-playbook playbooks/nomad.yml -l nomad_clients

# 3. Verify new nodes joined cluster
ansible nomad_servers -m shell -a "nomad node status"
```

---

## Troubleshooting

### Ansible Connection Issues

**Problem**: `SSH: Connect to host refused`

**Debug Steps:**
```bash
# Test SSH connectivity
ssh -v -i ~/.ssh/id_rsa dgouser@<droplet's public ip>

# Check SSH key permissions
ls -la ~/.ssh/id_rsa

# Verify target machine SSH is running
ansible nomad_servers -m ping
```

**Solution:**
```bash
# Add SSH key to agent
ssh-add ~/.ssh/id_rsa

# Or copy key to target
ssh-copy-id -i ~/.ssh/id_rsa dgouser@<droplet's public ip>
```

### Playbook Execution Hangs

**Problem**: Playbook doesn't progress past a certain task

**Debug Steps:**
```bash
# Run with verbose output
ansible-playbook playbooks/initialize.yml -vvv

# Check target node resources
ansible nomad_servers -m shell -a "free -h && df -h"

# Run specific playbook with debug
ansible-playbook playbooks/docker.yml -v
```

### Service Won't Start

**Problem**: N8N showing `Dead` or repeated restarts

**Debug Steps:**
```bash
ssh dgouser@<droplet's public ip>

# Check specific job
nomad status n8n

# View logs
nomad logs -job n8n

# Check resource allocation
nomad node status -self
```

**Solution - Increase Memory:**
```bash
# Edit job file
sudo vi /opt/nomad/jobs/n8n.nomad.hcl

# Update resources
resources {
  memory = 2048  # Increase from 1024
}

# Redeploy
nomad run /opt/nomad/jobs/n8n.nomad.hcl
```

### Database Connection Errors

**Problem**: N8N can't connect to PostgreSQL

**Debug Steps:**
```bash
ssh dgouser@<droplet's public ip>

# Test PostgreSQL connectivity
nc -zv 127.0.0.1 5432

# Check PostgreSQL job
nomad status postgres
nomad logs -job postgres

# Verify running containers
docker ps | grep postgres
```

**Solution - Restart PostgreSQL:**
```bash
ssh dgouser@<droplet's public ip>

nomad stop postgres
sleep 5
nomad run /opt/nomad/jobs/postgres.nomad.hcl

# Wait for startup
sleep 30

# Restart N8N
nomad stop n8n
nomad run /opt/nomad/jobs/n8n.nomad.hcl
```

### Port Conflicts

**Problem**: `bind: address already in use`

**Debug:**
```bash
ssh dgouser@<droplet's public ip>

# Find process using port
lsof -i :5678    # N8N
lsof -i :5432    # PostgreSQL
lsof -i :80      # Traefik HTTP
```

**Solution:**
```bash
# Either kill conflicting process
kill -9 <PID>

# Or change port in job file
vi /opt/nomad/jobs/n8n.nomad.hcl
# Update port allocation
nomad run /opt/nomad/jobs/n8n.nomad.hcl
```

---

## 📁 File Reference

```
n8n-deployment/
├── README.md                    # This documentation
├── ansible/                     # Ansible automation
│   ├── ansible.cfg             # Ansible configuration
│   ├── inventory/
│   │   ├── hosts.ini           # Target hosts
│   │   └── group_vars/         # Variables
│   ├── playbooks/              # Main playbooks
│   │   ├── initialize.yml      
│   │   ├── docker.yml
│   │   ├── nomad.yml
│   │   ├── consul.yml
│   │   └── ...
│   └── roles/                  # Reusable components
│       ├── docker/
│       ├── nomad/
│       ├── consul/
│       └── infra_hardening/
├── configs/                    # Static configuration
│   ├── nomad.hcl
│   └── consul.hcl
├── jobs/                       # Nomad job definitions
│   ├── postgres.nomad.hcl
│   ├── n8n.nomad.hcl
│   └── traefik.nomad.hcl
├── traefik.yml                 # Traefik config
└── traefik-config.toml         # Traefik routing
```

---

## Security Checklist

### Before Production Deployment

- [ ] Change all default passwords in `group_vars`
- [ ] Enable firewall rules (restrict access to ports)
- [ ] Configure Let's Encrypt for HTTPS
- [ ] Set up PostgreSQL backups
- [ ] Enable audit logging for Nomad/Consul
- [ ] Configure TLS for inter-service communication
- [ ] Set up monitoring and alerting
- [ ] Install security patches on OS

### Post-Deployment Verification

```bash
ssh dgouser@<droplet's public ip>

# Check listening ports
sudo netstat -tlnp | grep LISTEN

# Review file permissions
ls -la /opt/nomad/config/

# Check recent system logs
sudo tail -20 /var/log/syslog

```
---

## 💡 Best Practices

1. **Always test in non-production first** - Use staging environment
2. **Keep backups** - Backup before major changes
3. **Monitor regularly** - Check logs and resource usage
4. **Document changes** - Keep track of what you modify
5. **Use version control** - Commit Ansible playbooks changes
6. **Security first** - Change default passwords immediately
7. **Plan capacity** - Monitor growth, scale proactively

---

**Status**: Production Ready  
**Version**: 1.0 - Ansible Automated  
**Last Updated**: February 2026  
**Deployment Method**: Fully Automated with Ansible
