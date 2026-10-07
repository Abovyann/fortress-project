# Project Fortress: Highly-Available Cloud Datacenter

**The Pitch:** A highly-available web application running on plain VMs, the way most companies actually ran things before Kubernetes ate the world, and still run things when Kubernetes is overkill.

## Architecture
This project provisions a secure, multi-tier cloud environment in AWS from scratch using Infrastructure as Code.
* **Network:** Custom VPC with Public/Private Subnets and a NAT Gateway.
* **Compute:** 5 EC2 instances running Ubuntu 24.04.
* **Load Balancing:** HAProxy terminating TLS (Let's Encrypt) and distributing traffic.
* **Web Tier:** Nginx running inside Docker containers.
* **Database Tier:** PostgreSQL Primary + Replica with real-time WAL streaming.

## Tech Stack
* **Provisioning:** Terraform (with S3 Remote State + DynamoDB locking)
* **Configuration:** Ansible (Dynamic Jinja2 templating, Handlers, Roles)
* **Observability:** Prometheus, Grafana, Node Exporter, Alertmanager (Discord Webhooks)
* **Security:** UFW, fail2ban, SSH Hardening, AWS Security Group Chaining
* **CI/CD:** GitHub Actions (Syntax validation & Continuous Deployment)
* **Disaster Recovery:** Bash, Cron, AWS CLI, S3

## How it works
1. **Terraform** provisions the blank AWS infrastructure and generates the IPs.
2. **GitHub Actions** detects a push, securely injects SSH keys via Secrets, and triggers Ansible.
3. **Ansible** builds SSH proxy tunnels through the HAProxy Bastion to configure the private subnets.
4. **Automated Backups** run nightly via Cron, pushing encrypted SQL dumps to S3 using IAM Instance Profiles.

## Key Skills Demonstrated
* Real TLS termination and automated certificate renewal.
* Full observability stack with active webhook alerting.
* CI/CD pipelines that actually deploy configuration code.
* Disaster Recovery (Successfully tested restoring a dropped table from S3).
* Strict Security Group chaining (Private nodes have no public IPs and only accept Bastion traffic).
