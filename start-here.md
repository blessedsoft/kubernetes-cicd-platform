# Start Here: Kubernetes CI/CD Platform

  

This guide covers local setup, application testing, Docker builds, Kubernetes deployments, and the automated GitHub Actions pipeline.

  

The application listens on port `8080` and exposes:

-  `GET /` - service status.

-  `GET /healthz` - health check for Kubernetes probes and CI smoke tests.

  

## 1. Prerequisites

  

Install the tools required for your chosen workflow:

  

- Python 3.12 and Git

- Docker Desktop

-  `kubectl` and a Kubernetes cluster (Docker Desktop, Minikube, Kind, or remote)

- Bash for `deploy.sh` (Git Bash or WSL on Windows)

  

Verify your installation:

  

```bash

python  --version

docker  --version

kubectl  version  --client

git  --version

```

  

Before deploying, verify the target cluster:

  

```bash

kubectl  config  current-context

kubectl  cluster-info

```

  

**Important:** Kubernetes commands affect the cluster selected by your current context. Confirm it is correct before proceeding.

  

## 2. Get the Project

  

```bash

git  clone <repository-url>

cd  kubernetes-cicd-platform

```

  

If already cloned, open a terminal in the project root.

  

## 3. Run Locally

  

Create and activate a virtual environment.

  

**Windows (Git Bash):**

```bash

python  -m  venv  .venv

source  .venv/Scripts/activate

```

  

**macOS/Linux/WSL:**

```bash

python3  -m  venv  .venv

source  .venv/bin/activate

```

  

Install dependencies:

  

```bash

python  -m  pip  install  --upgrade  pip

python  -m  pip  install  -r  requirements-dev.txt

```

  

Start the application:

  

```bash

python  app.py

```

  

In another terminal, verify both endpoints:

  

```bash

curl  http://127.0.0.1:8080/

curl  http://127.0.0.1:8080/healthz

```

  

Expected responses:

  

```json

{"service":"sec-project","status":"ok"}

{"status":"healthy"}

```

  

Stop the application with `Ctrl+C` and exit the virtual environment using `deactivate`.

  

## 4. Run Quality and Security Checks

  

With the virtual environment active, run:

  

```bash

python  -m  ruff  check  .

python  -m  ruff  format  --check  .

python  -m  pytest

python  -m  semgrep  scan  --config  p/python  --error  --severity  ERROR  .

python  -m  pip_audit  -r  requirements.txt  --strict

```

  

Pytest enforces a minimum 70% coverage threshold and generates `coverage.xml`. To apply formatting fixes:

  

```bash

python  -m  ruff  format  .

```

  

## 5. Build and Run with Docker

  

Ensure Docker is running, then build and start the container:

  

```bash

docker  build  -t  sec-project:local  .

docker  run  --rm  --name  sec-project  -p  8080:8080  sec-project:local

```

  

Test the endpoints using the `curl` commands in Section 3. The image uses Gunicorn with two workers and runs as a non-root user.

  

If port `8080` is occupied, use `-p 8081:8080` and test through port `8081`.

  

## 6. Deploy to Kubernetes

  

The `k8s/` directory contains staging and production manifests. Deployments use rolling updates, health probes, and CPU/memory limits.

  

### Prepare the image

  

For a remote cluster, build and push the image:

  

```bash

docker  build  -t <registry-user>/sec-project:<tag> .

docker  push <registry-user>/sec-project:<tag>

```

  

For local clusters, load the image where necessary:

  

```bash

minikube  image  load  sec-project:local

```

  

For Kind:

  

```bash

kind  load  docker-image  sec-project:local

```

  

### Deploy to staging

  

Run from Bash:

  

```bash

./deploy.sh  staging  sec-project:local

```

  

For a registry image, substitute its full image name and tag. The script applies the staging manifest, updates the image, waits for rollout completion, and attempts a rollback if deployment fails.

  

Verify the deployment:

  

```bash

kubectl  -n  staging  get  deployment,pods,service

kubectl  -n  staging  rollout  status  deployment/sec-project

```

  

Access the application:

  

```bash

kubectl  -n  staging  port-forward  service/sec-project  8080:80

```

  

Test `http://127.0.0.1:8080/healthz`.

  

### Deploy to production

  

Deploy only after staging is healthy and the image has passed the required checks:

  

```bash

./deploy.sh  production <registry-user>/sec-project:<immutable-tag>

```

  

Verify production:

  

```bash

kubectl  -n  production  get  deployment,pods,service

kubectl  -n  production  rollout  status  deployment/sec-project

kubectl  -n  production  logs  deployment/sec-project  --all-containers=true

```

  

Production runs three replicas. To roll back:

  

```bash

kubectl  -n  production  rollout  undo  deployment/sec-project

kubectl  -n  production  rollout  status  deployment/sec-project

```

  

## 7. GitHub Actions CI/CD

  

The workflow is defined in `.github/workflows/ci-cd.yml`.

  

**Pull requests** run linting, formatting, tests with coverage enforcement, Semgrep, dependency auditing, Docker builds, and Trivy image scanning. Unfixed HIGH or CRITICAL vulnerabilities block the pipeline. Pull requests do not publish images or deploy.

  

**Successful pushes to `main`** additionally:

1. Publish an image tagged with the full Git commit SHA.

2. Deploy to staging.

3. Run a `/healthz` smoke test.

4. Wait for approval through the GitHub production environment.

5. Deploy to production after approval.

  
  
### Repository Secrets Configuration

Before the workflow can run successfully, you must configure the following **GitHub Actions Secrets** (`Settings` > `Secrets and variables` > `Actions`):

| Secret Name | Description / Format | Target Job |
| :--- | :--- | :--- |
| `REGISTRY_USERNAME` | Container registry username or account namespace. | `build-and-push` |
| `REGISTRY_TOKEN` | Access token or password with explicit image-push privileges. | `build-and-push` |
| `KUBE_CONFIG` | **Base64-encoded** string of your cluster's `kubeconfig` file. | `deploy-to-kubernetes` |

> 💡 **Tip:** To securely generate the `KUBE_CONFIG` secret from your local terminal, run:
> `cat ~/.kube/config | base64 | pbcopy` (macOS) or `cat ~/.kube/config | base64 -w 0` (Linux).

  

Encode the kubeconfig in Bash:

  

```bash

base64  ~/.kube/config | tr  -d  '\n'

```

  

Store the output in `KUBE_CONFIG`. Ensure the credentials provide the required deployment permissions and are appropriate for the GitHub runner.

  

Create GitHub environments named `staging` and `production`. Configure a required reviewer for `production` to enforce manual approval.

  

## 8. Troubleshooting

  

**Cluster connection issues**

```bash

kubectl  config  current-context

kubectl  cluster-info

kubectl  get  nodes

```

  

**ImagePullBackOff:** Verify the image name, registry access, and image availability in the cluster.

  

```bash

kubectl  -n  staging  describe  pod  -l  app=sec-project

```

  

**Failed health probes:**

```bash

kubectl  -n  staging  logs  deployment/sec-project

kubectl  -n  staging  describe  deployment/sec-project

```

  

Confirm the application listens on port `8080` and `/healthz` returns HTTP 200.

  

**Rollout failure:**

```bash

kubectl  -n  staging  rollout  history  deployment/sec-project

kubectl  -n  staging  get  pods

kubectl  -n  staging  describe  pods  -l  app=sec-project

```

  

The default deployment timeout is five minutes. Override it when necessary:

  

```bash

DEPLOY_TIMEOUT=10m  ./deploy.sh  staging <image>

```

  

## 9. Cleanup

  

Remove the application resources:

  

```bash

kubectl  -n  staging  delete  deployment  sec-project  service  sec-project

kubectl  -n  production  delete  deployment  sec-project  service  sec-project

```

  

To remove entire environments, including their namespaces and all contained resources:

  

```bash

kubectl  delete  namespace  staging

kubectl  delete  namespace  production

```

  

## Evidence