![Vasko Mihaylov](resume_assets/original_resume-001.jpg)

# VASKO MIHAYLOV

Plovdiv, Bulgaria | +359 896 756188 | vaskosmihaylov@gmail.com

## SENIOR DEVOPS ENGINEER

Senior DevOps Engineer with 11+ years of experience across Linux infrastructure, Kubernetes platform operations, CI/CD, observability, IAM/SSO, and infrastructure automation. Currently operating multiple production Kubernetes clusters with ArgoCD GitOps (50+ applications), Prometheus federation, and ELK-based centralized logging. Strong hands-on background with Puppet, Ansible, Terraform, GitLab CI, Keycloak, and self-hosted enterprise services. Experienced with AWS infrastructure and cloud platform practices. Known for turning repeatable operational work into tested automation, deployment pipelines, monitoring checks, and reliable runbooks for production systems.

## CORE SKILLS

- Operating systems: RHEL 6/7/8/9, CentOS, Rocky Linux, AlmaLinux, Ubuntu, Fedora, Solaris, SUSE
- Infrastructure as code: Puppet, Hiera, R10K, Ansible, Terraform, Kickstart, Cobbler
- CI/CD and automation: GitLab CI/CD, Artifactory, Renovate, Jenkins job DSL, Bash, Python, Ruby/Puppet DSL, PHP
- Kubernetes and containers: Kubernetes (multi-cluster operations), ArgoCD (GitOps, app-of-apps, 50+ applications), Helm, kubectl, Docker, Podman, ingress-nginx, cert-manager, metrics-server, RBAC, network policies, service accounts, persistent volumes, DaemonSets, Deployments, node drain/update workflows, Ceph storage
- Cloud platforms: AWS (EC2, S3, EKS, Route 53, IAM, KMS); working knowledge of cloud networking, compute, storage, and deployment patterns across AWS, Azure, and GCP
- IAM and security: Keycloak, OIDC, SAML, OAuth2, LDAP, SSSD, Wazuh, TLS/SSL, access control hardening
- Load balancing: HAProxy (production K8s API and ingress load balancing, SSL termination, health-checked backends, multi-cluster failover)
- Observability: Prometheus (federation, PuppetDB service discovery, Alertmanager, 12+ exporters), Grafana (LDAP auth, multi-datasource, image rendering), Icinga2, Nagios plugins, Wazuh, Elasticsearch/Logstash/Kibana (5-node cluster, complex grok pipelines, 30+ index routes), Filebeat, Metricbeat, InfluxDB, Graphite
- Web and databases: Apache, Nginx, HAProxy, PHP-FPM, TYPO3, Drupal, Matomo, Mattermost, MySQL/MariaDB, Galera, PostgreSQL
- Operations: incident response, patching, CVE remediation, backup/restore automation, LVM/filesystems, DNS, SMTP/IMAP, user and permission management

## EXPERIENCE

### Digitas PixelPark, Bulgaria - Senior DevOps Engineer
2020 - Present

- Built and maintained Puppet/Hiera automation for enterprise Linux infrastructure, using roles/profiles, strict module versioning, and R10K-controlled deployments across development, test, stage, and production environments.
- Developed a Puppet-managed Keycloak platform using Java 21, MariaDB, HAProxy, health and metrics endpoints, separated public/admin hostnames, log management, theme handling, and reusable Hiera configuration.
- Designed the Keycloak SSO rollout model for LionLogin/Azure AD federation, using realm-isolated SAML broker trusts and downstream OIDC/SAML integrations for applications such as TYPO3 and ArgoCD.
- Integrated TYPO3 backend authentication with Keycloak/OIDC, including backend-user auto-provisioning, identity mapping, duplicate cleanup, and group-based admin assignment.
- Built a Matomo deployment pipeline with GitLab CI, Renovate, Artifactory, and Ansible: downloads pinned upstream releases, uploads release artifacts, deploys to test automatically, gates production manually, backs up existing installations, runs database migrations, and validates HTTP health.
- Delivered Matomo infrastructure automation through Puppet/Hiera, including LAMP stack configuration, Apache security headers, LVM layout, cron-based archive/import jobs, MariaDB tuning, backup thresholds, and Icinga monitoring variables.
- Maintained Wazuh security operations automation with Puppet profiles for manager, indexer, dashboard, Filebeat, LDAP auth, Apache reverse proxying, FIM reports, log cleanup, package version locks, and PuppetDB-driven customer/project agent groups.
- Implemented and maintained Mattermost self-hosting automation: versioned configuration templates, PostgreSQL integration, systemd units, mmctl setup, secure defaults, LDAP settings, backup scripts, and Apache reverse proxy configuration.
- Operated multiple production Kubernetes clusters (7+ clusters across dev, stage, live, and CI environments) on VMware vSphere, including control plane management, HAProxy-based API server and ingress load balancing with health-checked backends, SSL termination, and multi-cluster failover.
- Managed ArgoCD GitOps platform deploying 50+ applications across dev/stage/live environments using Helm charts from a private Artifactory registry, with per-environment namespace targeting and automated sync workflows.
- Built and maintained the centralized Prometheus observability stack: Prometheus 3.x with PuppetDB-based service discovery, federation from multiple K8s cluster Prometheus instances, Alertmanager with routing and inhibition rules, and 12+ exporters (node, MySQL, Apache, Elasticsearch, HAProxy, Keycloak, PostgreSQL, Artifactory, BIND, Dovecot, Java).
- Designed and operated a 5-node Elasticsearch cluster (8.x) with xpack security, TLS transport/HTTP encryption, audit logging, NFS-based snapshots, and 3 Logstash nodes with complex grok/dissect pipelines routing logs to 30+ project-specific indices with persisted queues and fingerprint-based deduplication.
- Managed Grafana 13.x with LDAP authentication, multiple datasources (Prometheus, Graphite, InfluxDB2 for Icinga2 perf data), Podman-based image renderer, and CSP-hardened Apache reverse proxy.
- Operated Ceph storage clusters for Kubernetes persistent storage, including OSD nodes, monitors, and automated backup workflows.
- Created and updated Kubernetes deployment assets for ingress-nginx, Filebeat, Metricbeat, metrics-server, monitoring service accounts, RBAC, persistent volumes, and network policies.
- Operated Kubernetes maintenance flows through Ansible and kubectl, including node drain/update procedures, post-maintenance checks, monitoring integration, and service validation.
- Created and updated Terraform YAML artifacts for vSphere-based VM provisioning, including monitoring stacks, Puppet infrastructure, Mattermost, Matomo, service hosts, Kubernetes nodes, and RHEL 9 migrations.
- Maintained central GitLab deployment templates for TYPO3 and Drupal applications, covering Artifactory artifact downloads, release directory preparation, symlink-based deployments, cache flushing, database schema updates, and maintenance-mode workflows.
- Improved Renovate dependency automation for GitLab-hosted repositories, including repository onboarding, shared configuration, dependency dashboards, security labels, automerge rules for low-risk updates, and regex managers for CI version variables.
- Developed Nagios/Icinga-compatible monitoring checks and packaging workflows, including LibreNMS alert checks, Podman container status checks, RuboCop validation, RPM packaging, and GitLab CI build/upload jobs.
- Supported GitLab runner/container platform work, including RHEL9/UBI-based CI images and pipeline standardization for internal deployments.
- Automated recurring maintenance with Ansible playbooks for VMware snapshots, VM hardware updates, Icinga downtimes, OS updates, Kubernetes node drain/update flows, package checks, and CVE remediation.
- Developed and improved monitoring/reporting automation for Grafana, Prometheus, Logstash, Icinga, Wazuh, LibreNMS, and monthly customer reporting workflows.
- Collaborated with distributed infrastructure, development, and operations teams; reviewed merge requests, handled production issues, and coordinated rollout work across customer environments.

### SiteGround Web Hosting, Bulgaria - DevOps
2017 - 2020

- Maintained Linux hosting infrastructure and services including DNS, Apache, Nginx, SSH, FTP, Exim, Dovecot, MySQL, PHP, cPanel, and Site Tools.
- Wrote Bash automation for backups, log collection, monitoring, package installation, and repeatable system administration tasks.
- Worked with AWS-hosted infrastructure and services, including EC2 and S3, while supporting production hosting and automation workflows.
- Performed incident response, patching, package management with rpm/yum, driver updates, hardware/software upgrades, and server performance troubleshooting.
- Managed disks and filesystems through CLI tools and hosting control panels.
- Troubleshot user accounts, sudo rules, permissions, security conflicts, and service availability issues.
- Monitored queues and coordinated team work to ensure operational tasks and incidents were handled on time.

### SiteGround Web Hosting, Bulgaria - Senior Technical Support Specialist
2015 - 2017

- Resolved customer issues across hosting, server availability, DNS, MySQL, control panels, domains, and web applications.
- Investigated and fixed Linux system, web server, database, and application-level problems under customer-facing SLAs.
- Performed standard administration tasks including package installation, patching, filesystem checks, performance analysis, and log review.
- Maintained direct communication with customers and escalated complex technical issues to engineering teams.

## SELECTED PROJECTS

### Keycloak IAM and SSO Platform
- Puppet-managed Keycloak 26 platform with Java 21, MariaDB, HAProxy, separate public/admin entry points, health/metrics, log rotation, Filebeat integration, theme/data directory handling, and Hiera-defined realms.
- SSO architecture for external enterprise authentication via SAML into Keycloak, with downstream OIDC/SAML integrations for internal applications.

### Multi-Cluster Kubernetes Platform with ArgoCD GitOps
- Operated 7+ Kubernetes clusters across dev, stage, live, and CI environments on VMware vSphere, with HAProxy load balancers for API server and ingress traffic distribution, health-checked backends, and SSL termination.
- ArgoCD GitOps platform managing 50+ applications deployed via Helm charts from Artifactory, with environment-specific targeting across dev/stage/live namespaces and automated sync workflows.
- Kubernetes manifests for ingress-nginx, Filebeat, Metricbeat, metrics-server, monitoring service accounts, RBAC, network policies, persistent volumes, and Ceph-backed storage.

### Enterprise Observability Stack
- Centralized Prometheus 3.x with 1.3TB+ retention, PuppetDB-driven service discovery, federation from K8s cluster Prometheus instances, Alertmanager with routing/inhibition, and 12+ exporter types.
- Elasticsearch 8.x cluster (5 nodes) with xpack security, TLS encryption, audit logging, NFS snapshots, and Logstash pipeline with grok/dissect filters routing to 30+ project-specific indices.
- Grafana 13.x with LDAP authentication, multi-datasource setup (Prometheus, Graphite, InfluxDB2), Podman-based image rendering, and Apache reverse proxy with CSP headers.

### Renovate Dependency Automation
- GitLab Renovate configuration for centralized dependency update management, repository onboarding, dependency dashboards, vulnerability labels, and minor/patch automerge policies.
- Custom regex manager support for tracking version variables in GitLab CI files and keeping CI image/tooling versions visible to Renovate.

### Monitoring Checks and RPM Packaging
- Nagios/Icinga plugin work for operational checks, including LibreNMS alert integration and Podman container status monitoring with proper exit codes and performance output.
- GitLab CI packaging pipeline for public/private monitoring checks with linting, Ruby/FPM RPM builds, artifacts, and package upload jobs.

### TYPO3 Keycloak SSO Provisioning
- TYPO3 v13 extension/integration for backend user provisioning from Keycloak OIDC login events.
- Handles user create/update, identity lookup, duplicate identity cleanup, email/username synchronization, and group-based admin mapping.

### Matomo CI/CD and Infrastructure
- GitLab CI pipeline for controlled Matomo release ingestion, Artifactory upload, automated test deployment, manual production deployment, Ansible-based backup/update, and post-deploy health validation.
- Puppet/Hiera infrastructure for Matomo web, PHP, MariaDB, LVM, backups, cron jobs, monitoring thresholds, and deployment users.

### Wazuh Security Automation
- Puppet profiles for Wazuh manager/indexer/dashboard stack, LDAP integration, package version control, Apache proxy, FIM reporting, log cleanup, and agent-group lifecycle management from PuppetDB inventory.

### Mattermost Self-Hosted Automation
- Full Puppet profile for Mattermost installation, PostgreSQL database integration, systemd service, secure configuration defaults, LDAP options, backup workflow, and Apache reverse proxy support.

### VMware, Terraform, and Maintenance Automation
- Terraform/YAML VM artifacts for vSphere environments and customer platforms.
- Ansible maintenance playbooks for snapshots, Icinga downtimes, package updates, CVE remediation, Kubernetes node operations, and post-maintenance checks.

## EDUCATION AND CERTIFICATIONS

- National Sports Academy, Bulgaria - Bachelor's Degree, 2010 - 2015
- Software University - Linux System Administration, 2016
- Udemy - Git from Basics to Advanced, 2020
- Udemy - Grafana Beginners to Advanced Crash Course, 2021
- Udemy - NGINX, Apache, SSL Encryption Certification Course, 2021
- Udemy - Go: Mastering Google's Go Programming, 2021
- Udemy - Python 3 Master Course, 2021

## PERSONAL PROJECTS

- **Cloud-Native Platform on AWS EKS** -- Production-grade Kubernetes platform demonstrating GitOps (ArgoCD app-of-apps), observability (Prometheus + Grafana + Loki), security hardening (PSS, network policies, RBAC, SOPS/KMS), HPA with custom Prometheus metrics, Terraform IaC with modular architecture, and CI/CD via GitHub Actions with OIDC federation. [github.com/vaskosmihaylov/k8s-aws-platform](https://github.com/vaskosmihaylov/k8s-aws-platform)
- [Nextcloud Hub with OnlyOffice, MariaDB, Nginx Proxy, ACME companion, Ubuntu 22.04, and Docker Compose](https://github.com/vaskosmihaylov/docker-onlyoffice-nextcloud-nginx_proxy-SSL#install-nextcloud-hub--onlyoffice--mariadb--nginx-proxy--acme-companion-ubuntu-2204-with-docker-compose)
- [Console ChatGPT project](https://github.com/amidabuddha/console-chat-gpt)
- [Wazuh CVE library](https://github.com/vaskosmihaylov/Wazuh_CVE_Library)

## GITHUB PORTFOLIO

- GitHub profile and public repositories: [github.com/vaskosmihaylov](https://github.com/vaskosmihaylov?tab=repositories)
- Selected public repositories: [nfi-custom-strategies](https://github.com/vaskosmihaylov/nfi-custom-strategies), [PropSketch](https://github.com/vaskosmihaylov/PropSketch), [hr_tool_core_v12](https://github.com/vaskosmihaylov/hr_tool_core_v12), [freqai-foundry-strategies](https://github.com/vaskosmihaylov/freqai-foundry-strategies), [freqtrade-strategy-lab](https://github.com/vaskosmihaylov/freqtrade-strategy-lab), [vwap-regime-orchestrator](https://github.com/vaskosmihaylov/vwap-regime-orchestrator), [viki_services](https://github.com/vaskosmihaylov/viki_services), [hr_tool_core](https://github.com/vaskosmihaylov/hr_tool_core), [control-repo](https://github.com/vaskosmihaylov/control-repo), [PHP-test](https://github.com/vaskosmihaylov/PHP-test)
