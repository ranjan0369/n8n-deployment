# Phase 5 – CI/CD Automation with GitHub Actions

## Objective

The objective of this phase is to automate the deployment of the N8N Nomad job so that whenever changes are pushed to the `n8n.nomad` file in the GitHub repository, the application is automatically redeployed to the server. This eliminates manual SSH deployments and ensures a consistent, repeatable CI/CD workflow.


## Research Tasks

### What is `appleboy/ssh-action`?

The `appleboy/ssh-action` is a GitHub Action that allows you to execute remote SSH commands directly from a GitHub Actions workflow.

#### How It Works

- Establishes an SSH connection from GitHub’s runner to your remote server.
- Uses credentials stored securely in GitHub Secrets.
- Executes any shell commands on the remote host.
- Returns logs directly inside the GitHub Actions workflow output.

In our case, it runs:

```sh
nomad job run /home/ubuntu/nomad-jobs/n8n.nomad
```

### What is `appleboy/scp-action`?

The `appleboy/scp-action` allows you to copy files from the GitHub runner to a remote server using SCP (Secure Copy Protocol).

It is used to:

- Transfer the `n8n.nomad` file
- Place it into a directory on your Droplet
- Prepare it for execution

### What is GitHub Actions?

GitHub Actions is GitHub’s built-in CI/CD automation platform that allows you to:

- Automatically build
- Test
- Deploy
- Execute workflows on events like push, pull requests, etc.

Workflows are defined using YAML files inside:

```
.github/workflows/
```


## How to Store a Private SSH Key as a GitHub Secret

GitHub Secrets securely store sensitive values such as private keys.

**Steps:**

1. Go to your GitHub repository.
2. Navigate to: `Settings → Secrets and variables → Actions`
3. Click **New repository secret**.
4. Add:

   | Secret Name      | Value                        |
   |------------------|------------------------------|
   | HOST             | Droplet IP address           |
   | USERNAME         | SSH user (ubuntu/root)       |
   | SSH_PRIVATE_KEY  | Full private SSH key content |

Paste the entire private key including:

```
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

---

## How to Copy Files Using SCP in GitHub Actions

Using `appleboy/scp-action`, you can copy files like this:

```yaml
- name: Copy Nomad Job File
  uses: appleboy/scp-action@master
  with:
    host: ${{ secrets.HOST }}
    username: ${{ secrets.USERNAME }}
    key: ${{ secrets.SSH_PRIVATE_KEY }}
    source: "n8n.nomad"
    target: "/home/ubuntu/nomad-jobs/"
```

This securely transfers the file to your server.

---

## How to Run Remote Commands via SSH

Using `appleboy/ssh-action`:

```yaml
- name: Deploy Nomad Job
  uses: appleboy/ssh-action@master
  with:
    host: ${{ secrets.HOST }}
    username: ${{ secrets.USERNAME }}
    key: ${{ secrets.SSH_PRIVATE_KEY }}
    script: |
      nomad job run /home/ubuntu/nomad-jobs/n8n.nomad
```

This executes the Nomad deployment remotely.


## Alternative Method – HashiCorp Nomad GitHub Action

You may alternatively use:

`hashicorp/setup-nomad`

This action:

- Installs Nomad CLI in the GitHub runner
- Allows deployment directly to a remote Nomad cluster

You must configure:

```yaml
env:
  NOMAD_ADDR: https://your-server-ip:4646
  NOMAD_TOKEN: ${{ secrets.NOMAD_TOKEN }}
```

However, for a single-node Nomad server, the SSH method is typically simpler and more secure.


## Accomplishment Tasks

### Step 1 – Create GitHub Secrets

Go to:

Repo → Settings → Secrets and variables → Actions

Create:

- HOST
- USERNAME
- SSH_PRIVATE_KEY

### Step 2 – Create Workflow File

Create this file in your repository:

```
.github/workflows/deploy.yml
```

### Step 3 – Define the Workflow

Here is the complete workflow configuration:

```yaml
name: Deploy N8N to Nomad

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Copy Nomad Job File to Server
        uses: appleboy/scp-action@master
        with:
          host: ${{ secrets.HOST }}
          username: ${{ secrets.USERNAME }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          source: "n8n.nomad"
          target: "/home/ubuntu/nomad-jobs/"

      - name: Run Nomad Job on Server
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.HOST }}
          username: ${{ secrets.USERNAME }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            nomad job run /home/ubuntu/nomad-jobs/n8n.nomad
```

## How the Deployment Flow Works

1. You modify `n8n.nomad`
2. You push to `main`
3. GitHub Actions triggers workflow
4. Workflow:
   - Checks out repo
   - Copies job file to Droplet
   - Runs `nomad job run`
5. Nomad updates the N8N deployment

This creates a fully automated CI/CD pipeline.

## Outcome of Phase 5

After completing this phase:

- Manual SSH deployments are eliminated.
- Every Git push automatically redeploys N8N.
- Infrastructure becomes reproducible and version-controlled.