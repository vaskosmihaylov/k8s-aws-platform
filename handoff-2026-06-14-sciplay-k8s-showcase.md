# Handoff: SciPlay K8S/DevOps Role Preparation & AWS Showcase Project

**Date:** 2026-06-14
**Working directory:** `/Users/vasmihay/Personal/resume`

---

## Context

The user received a LinkedIn job offer from **SD Solutions** for a **Senior Kubernetes / DevOps Engineer** role at **SciPlay** (social gaming company, part of Light & Wonder). The recruiter offered: remote, B2B, $6000-6500 gross.

SciPlay's current stack is traditional on-prem: LAMP, Couchbase, VMware, F5, Pure Storage SAN, Grafana observability. They are migrating toward containers, Kubernetes, and an internal developer platform. They want someone strong in classic infra who can lead the modernization.

## What was accomplished

### 1. Resume Gap Analysis (completed)

The user's resume is at `Resume_updated.md` / `Resume_updated.html` in the working directory. Key findings:

**Strong matches (~70% coverage):**
- 11+ years Linux sysadmin / classic infra
- VMware (Terraform with vSphere)
- Grafana/Prometheus/ELK observability
- LAMP stack management
- Kubernetes fundamentals (Helm, RBAC, ingress-nginx, DaemonSets, node drain)
- Docker/Podman containers
- IaC (Puppet, Ansible, Terraform)

**Gaps:**
- Cloud-managed Kubernetes (EKS/GKE/AKS) -- K8s work is all on-prem vSphere
- AWS depth -- resume only shows EC2 + S3, says "basic GCP"
- No F5 load balancer experience (has HAProxy)
- No Couchbase or Pure Storage SAN
- No Internal Developer Platform (IDP) experience
- ArgoCD mentioned only for SSO integration, not as a GitOps deployment tool

### 2. Recruiter Reply (drafted, not sent)

A short, confident reply was drafted that highlights overlap and subtly addresses the cloud gap by mentioning active AWS K8s work. The user has not sent it yet.

### 3. AWS K8S Showcase Project Plan (detailed, not started)

A full step-by-step plan was provided to build a **"Cloud-Native Platform on AWS EKS"** showcase project. The user has a personal AWS account. The plan has 5 phases:

- **Phase 1:** Terraform foundation (VPC, EKS, S3 backend)
- **Phase 2:** Platform components (ingress-nginx, cert-manager, ArgoCD, Prometheus+Grafana)
- **Phase 3:** App deployment (containerized app, K8s manifests, ArgoCD GitOps)
- **Phase 4:** Production practices (RBAC, network policies, HPA, CI/CD with GitHub Actions + ECR)
- **Phase 5:** Documentation and screenshots

Estimated cost: ~$150-165/mo (can be reduced with spot instances and teardown).

The project repo structure was outlined:
```
k8s-aws-platform/
├── terraform/      (vpc, eks, rds, backend, variables, outputs)
├── k8s/            (apps, monitoring, ingress, argocd manifests)
├── .github/workflows/
└── README.md
```

## What was NOT done

- No files were created or modified
- No Terraform or K8s manifests were scaffolded
- The recruiter reply was not sent
- No resume updates were made
- No AWS resources were provisioned
- No GitHub repo was created

## What comes next

The user's last question was: **"Want me to start scaffolding the Terraform and Kubernetes files for this project?"** -- unanswered.

Likely next steps:
1. **Scaffold the project** -- create the repo structure, Terraform files (VPC, EKS, S3 backend), and initial K8s manifests
2. **Possibly update the resume** to better position for the role (e.g., strengthen cloud/K8s language)
3. **Send the recruiter reply** (may need LinkedIn or email)
4. **Build and deploy** the showcase on the user's AWS account

## Key files in the workspace

| File | Purpose |
|---|---|
| `Resume_updated.md` | Latest resume in Markdown |
| `Resume_updated.html` | Latest resume as styled HTML |
| `Resume.pdf` | PDF version (may be older) |
| `Resume_updated.docx` | Word version |

## Suggested skills

- **`/prototype`** -- if the user wants to quickly prototype the K8s project structure or test Terraform modules before committing
- **`/tdd`** -- if building the Go/PHP showcase app with tests
- **`/init`** -- to set up CLAUDE.md in the new K8s project repo once created
- **`/to-issues`** -- to break the 5-phase plan into trackable GitHub issues in the new repo
- **`/grill-me`** -- to help the user prepare for the technical interview by stress-testing their knowledge of the architecture they're building

---

*Generated from conversation on 2026-06-14.*
