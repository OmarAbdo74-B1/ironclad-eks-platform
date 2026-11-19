# Ironclad: From On-Prem Kubernetes to AWS EKS

A DevSecOps and GitOps platform, built and tested on an on-premises Kubernetes cluster first, then migrated to AWS EKS.

This repository is the **GitOps source of truth**. Everything running on the cluster is declared here and applied by ArgoCD. The two application repositories build, test and scan the images; they never touch the cluster.

| Repository | Role |
| --- | --- |
| [ironclad-backend](https://github.com/OmarAbdo74-B1/ironclad-backend) | Node.js API, Dockerfile, Jenkinsfile, unit tests |
| [ironclad-frontend](https://github.com/OmarAbdo74-B1/ironclad-frontend) | Static frontend on unprivileged nginx, Jenkinsfile, unit tests |
| **ironclad-eks-platform** (this repo) | Kustomize overlays, ArgoCD apps and projects, platform tools, guardrails, tools server |

---

## Status

| Phase | State |
| --- | --- |
| Phase 1: On-prem (kubeadm) | Done, frozen at tag `onprem-v1` |
| Phase 2: Migration to AWS EKS | In progress |

---

## Target architecture

![Target architecture](docs/onprem/screenshots/00-architecture/target-architecture.png)

Phase 1 builds every piece of this design that can run without a cloud account, on a local cluster. Phase 2 moves it to AWS and adds the cloud-only parts (ALB, WAF, ACM, RDS, IRSA, S3).

---

## How a change reaches production

```
Developer push
   │
   ▼
Jenkins (outside the cluster)
   Unit tests ─► SonarQube analysis ─► Quality Gate (webhook) ─► Build image
   ─► Trivy scan (blocks on fixable CRITICAL) ─► Push image ─► Commit new tag to this repo (dev overlay)
   │
   ▼
ArgoCD (inside the cluster) pulls from Git
   dev      auto-sync
   staging  auto-sync, promoted by Pull Request
   prod     manual sync, promoted by Pull Request, only inside the sync window
```

The same image is built once and promoted through the environments. Only the tag in each overlay changes.

---

# Phase 1: On-prem

## Environment

| Component | Version / detail |
| --- | --- |
| Kubernetes | kubeadm v1.30.14, 1 control plane + 2 workers, containerd, CentOS Stream 9 |
| CNI | Flannel |
| Ingress | Traefik (chart 42.4.1), NodePort 30080 |
| GitOps | ArgoCD v3.6.1, App of Apps |
| Config | Kustomize base + 3 overlays (dev, staging, prod) |
| CI | Jenkins 2.580.2, SonarQube Community Build 26.11, Trivy 0.76.1 (client/server) |
| Monitoring | kube-prometheus-stack 92.21.1, alerts to Slack |
| Backups | Velero 1.18.2 (chart 12.2.3, AWS plugin v1.14.4), SeaweedFS 4.52 as S3 storage |
| Tools server | Docker Compose: Jenkins, SonarQube, Postgres, Trivy server, SeaweedFS |

Exact versions captured from the cluster are in [`docs/onprem/versions.md`](docs/onprem/versions.md).

## Repository layout

```
app/
  base/                  backend, frontend, ingress
  overlays/dev|staging|prod
argocd/
  root-app.yaml          App of Apps
  projects/              dev, staging, prod, platform
  apps/                  cars-dev, cars-staging, cars-prod, monitoring, velero, guardrails
platform/
  traefik/               install script and values
  monitoring/            kube-prometheus-stack values
  velero/                Velero values
  guardrails/            namespaces, quotas, limit ranges, network policies
tools-server/            Docker Compose for Jenkins, SonarQube, Trivy, SeaweedFS
docs/onprem/             screenshots and command evidence
```

## 1. The application in three environments

Same images, different overlay: namespace, host, replicas and `APP_ENV`.

| Development | Staging | Production |
| --- | --- | --- |
| ![dev](docs/onprem/screenshots/01-application/dev-site.png) | ![staging](docs/onprem/screenshots/01-application/staging-site.png) | ![prod](docs/onprem/screenshots/01-application/prod-site.png) |

All three run the same images (`backend v1.1.3`, `frontend v1.1.4`): [`03-images-per-env.txt`](docs/onprem/evidence/03-images-per-env.txt). Production runs 4 replicas of each, and 10 requests were spread across all 4 backend pods: [`03-prod-load-balancing.txt`](docs/onprem/evidence/03-prod-load-balancing.txt).

![category filter](docs/onprem/screenshots/01-application/dev-category-filter.png)

## 2. GitOps with ArgoCD

One root application deploys every project and application from the `argocd/` folder.

![App of Apps](docs/onprem/screenshots/02-gitops-argocd/root-app-of-apps.png)

![Applications](docs/onprem/screenshots/02-gitops-argocd/applications-after-prod-sync.png)

Platform tools come from upstream Helm charts with a pinned version, and their values come from this repo (multi-source application):

![Multi-source](docs/onprem/screenshots/02-gitops-argocd/monitoring-multi-source.png)

### Production protection

Production is synced by hand, and only on Sunday to Thursday, 10:00 to 16:00 Cairo time. A sync outside the window is refused by ArgoCD:

| Outside the window (03:00) | Inside the window (14:30) |
| --- | --- |
| ![Inactive](docs/onprem/screenshots/02-gitops-argocd/prod-sync-window-inactive.png) | ![Active](docs/onprem/screenshots/02-gitops-argocd/prod-sync-window-active.png) |

![Sync blocked](docs/onprem/screenshots/02-gitops-argocd/prod-sync-blocked.png)

Inside the window, the same change was synced by hand. The header shows the sync window as active:

![Prod synced](docs/onprem/screenshots/02-gitops-argocd/prod-synced-in-window.png)

## 3. Promotion by Pull Request

Promotion is a two-line change to an overlay, reviewed as a Pull Request.

![PR staging](docs/onprem/screenshots/03-promotion-github/pr-promote-staging.png)

![PR prod](docs/onprem/screenshots/03-promotion-github/pr-promote-prod.png)

Jenkins writes to Git, never to the cluster:

![Jenkins commits](docs/onprem/screenshots/03-promotion-github/jenkins-gitops-commits.png)

## 4. CI with security gates

Both pipelines run the same 8 stages.

![Frontend builds](docs/onprem/screenshots/04-ci-jenkins/frontend-builds-stage-view.png)

### Trivy blocked a real CRITICAL vulnerability

Build #1 of the frontend stopped at Trivy. The image was never pushed and never reached any environment.

![Trivy blocked](docs/onprem/screenshots/04-ci-jenkins/frontend-trivy-blocked.png)

![CVE](docs/onprem/screenshots/04-ci-jenkins/frontend-trivy-critical-cve.png)

Fix: `apk upgrade` in the runtime stage and `docker build --pull --no-cache`. Build #2 passed:

![Fixed](docs/onprem/screenshots/04-ci-jenkins/frontend-pipeline-fixed.png)

The backend image, on a newer Alpine base, had zero findings: [backend-trivy-clean.png](docs/onprem/screenshots/04-ci-jenkins/backend-trivy-clean.png).

### SonarQube Quality Gate

The pipeline waits for SonarQube to report back through a webhook signed with a shared secret.

![SonarQube projects](docs/onprem/screenshots/05-code-quality/sonarqube-projects.png)

![Webhook](docs/onprem/screenshots/05-code-quality/sonarqube-webhook.png)

Jenkins holds four credentials, each with one job. None of them can reach the cluster: [credentials.png](docs/onprem/screenshots/04-ci-jenkins/credentials.png).

## 5. Monitoring and alerting

kube-prometheus-stack, deployed by ArgoCD, with alerts routed to Slack.

![Grafana cluster](docs/onprem/screenshots/06-monitoring/grafana-cluster.png)

![Targets](docs/onprem/screenshots/06-monitoring/prometheus-targets.png)

Per-pod usage in production, with the quota limits applied:

![Grafana prod](docs/onprem/screenshots/06-monitoring/grafana-namespace-prod.png)

The monitoring caught two real problems before anyone looked for them:

| Leftover Velero jobs failing every 5 minutes | Grafana OOMKilled, detected and resolved |
| --- | --- |
| ![KubeJobFailed](docs/onprem/screenshots/07-alerting-slack/kubejobfailed-old-velero.png) | ![Grafana outage](docs/onprem/screenshots/07-alerting-slack/grafana-outage-detected.png) |

## 6. Backups with Velero

Backups are stored outside the cluster, on SeaweedFS (S3 API) on the tools server, so they survive the loss of the cluster. Schedules: dev daily, staging every 5 days, prod every 2 hours.

Restore was tested by restoring `dev` into a new namespace (`dev-restore`). The pods and services came back running: [`08-velero-restore.txt`](docs/onprem/evidence/08-velero-restore.txt).

![Restored pods](docs/onprem/screenshots/10-backup-velero/dev-restored-pods.png)

Backup failures raise an alert:

![Velero rules](docs/onprem/screenshots/06-monitoring/prometheus-velero-rules.png)

![Velero alert](docs/onprem/screenshots/07-alerting-slack/velero-backup-failed.png)

## 7. Environment isolation

Owned by the platform (`guardrails` app), not by application overlays.

| Layer | State on-prem |
| --- | --- |
| Pod Security `restricted` | Enforced. Root container rejected: [`09-pss-rejected.txt`](docs/onprem/evidence/09-pss-rejected.txt) |
| ResourceQuota | Enforced: [`09-quotas.txt`](docs/onprem/evidence/09-quotas.txt) |
| LimitRange | Enforced. 2 CPU container rejected: [`09-limitrange-rejected.txt`](docs/onprem/evidence/09-limitrange-rejected.txt) |
| NetworkPolicy (default deny, DNS, same namespace, Traefik) | **Applied, not enforced.** Flannel has no policy support. A pod in dev still reached staging: [`09-netpol-not-enforced.txt`](docs/onprem/evidence/09-netpol-not-enforced.txt) |

![Guardrails](docs/onprem/screenshots/02-gitops-argocd/guardrails-app.png)

| Namespace labels used by the policies | Quota usage in dev |
| --- | --- |
| ![Labels](docs/onprem/screenshots/09-isolation/namespace-labels.png) | ![Quota](docs/onprem/screenshots/09-isolation/quota-dev.png) |

---

## Key decisions

| Decision | Why | Alternative rejected |
| --- | --- | --- |
| Folder per environment on one branch | No drift, no environment config leaking through merges, promotion is a one-line PR | Branch per environment |
| Promotion by PR, prod manual sync + sync window | Review trail, deploys only in working hours | Auto-sync everywhere |
| Build once, deploy many | The image tested in dev is the image in prod | Rebuild per environment |
| Jenkins never touches the cluster | CI only writes a tag to Git; ArgoCD pulls; no kubeconfig in CI | `kubectl apply` from Jenkins |
| Traefik as ingress controller | ingress-nginx retired in March 2026 | ingress-nginx |
| SeaweedFS for backups, outside the cluster | Backups survive cluster loss; the MinIO image is no longer on Docker Hub | MinIO, in-cluster storage |
| Guardrails owned by the platform | Quotas and policies can't be loosened from an app overlay | Policies in app overlays |
| Trivy client/server | Vulnerability DB downloaded once, faster scans | Standalone Trivy per build |
| Versions pinned, at least 2 weeks old | Avoid broken fresh releases | `latest` tags |
| No CPU limits, memory limits always | CPU limits cause throttling (seen in `CPUThrottlingHigh` on the old Velero) | CPU limits everywhere |
| SonarQube webhook with a secret | Forged Quality Gate results are rejected | No secret |

## Problems solved

| Problem | Symptom | Root cause | Fix |
| --- | --- | --- | --- |
| Backend API unreachable | Frontend showed "Backend API Connection Failed" ([screenshot](docs/onprem/screenshots/08-troubleshooting/backend-api-unreachable.png)) | `backend-svc` exposed 3000, Ingress expected 80; Traefik skipped the route silently | Service port 80 → targetPort 3000 |
| SonarQube analysis failed | Similar key already exists ([screenshot](docs/onprem/screenshots/04-ci-jenkins/backend-sonar-key-error.png)) | Project key case mismatch | Lowercase project keys |
| Frontend pipeline blocked | Trivy CRITICAL in `brotli-libs` | Base image older than Alpine fixes | `apk upgrade` + `--pull --no-cache` |
| 37 dead pods in argocd | `ContainerStatusUnknown` | DiskPressure on the control node | Pruned images, masked PackageKit |
| ArgoCD controller restarts | Exit 137, reason Error | Kernel OOM on a 3.6 GB node, controller was BestEffort | Requests and limits on the controller |
| Grafana unavailable | 503 ([screenshot](docs/onprem/screenshots/08-troubleshooting/grafana-no-available-server.png)), Slack alerts 03:13–03:38 | OOMKilled 9 times at 384Mi | Limit raised to 640Mi |
| Velero sync failed | Deployment invalid (strategy, selector) | Old CLI-installed Velero merged with the chart | Removed old install and its cluster-admin binding |
| Backups failed | S3 500 InternalError | SeaweedFS had no free volumes | `-volume.max=30`, 256 MB volumes |
| Prometheus operator stuck | ContainerCreating | Admission webhooks disabled, TLS still on | `tls.enabled: false` |
| Restored namespace adopted by ArgoCD | `dev-restore` shown under the guardrails app | Velero restored ArgoCD tracking labels | Test restores on a separate cluster |

## Known limitations

- NetworkPolicies are not enforced on Flannel. Enforcement is tested on EKS with the VPC CNI.
- Jenkins builds through the Docker socket, which is root-equivalent on the host. Next step: Kaniko or rootless BuildKit.
- Kubernetes v1.30 is end of life; current Calico lines are not tested on it.
- Nodes have 17 GB disk and 3.6 GB RAM: monitoring is pinned with `nodeSelector`, Prometheus has no persistence, cluster memory sits around 80%.
- Grafana and Alertmanager secrets are created by hand. On AWS they move to Secrets Manager.
- `info` alerts go to the same Slack channel as `critical` ones.
- ArgoCD itself is not managed by GitOps: Helm records v3.5.1 while v3.6.1 is running, an upgrade made outside Helm. On AWS, ArgoCD is installed by Helm with its values in Git.

## Evidence

Every command output used above is saved under [`docs/onprem/evidence`](docs/onprem/evidence). All screenshots are under [`docs/onprem/screenshots`](docs/onprem/screenshots), grouped by topic.

---

# Phase 2: Migration to AWS EKS

Planned changes:

| On-prem | AWS |
| --- | --- |
| kubeadm on VMs | EKS |
| Flannel | VPC CNI with NetworkPolicy enforcement |
| Traefik | ALB + WAF + ACM |
| Docker Hub | ECR with immutable tags and scan on push |
| SeaweedFS + access keys | S3 + IRSA |
| No database | RDS |
