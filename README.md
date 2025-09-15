# Crusoe Registry Token Rotator Helm Chart

## Overview

This Helm chart deploys the Crusoe Token Rotator, a Kubernetes-native solution for securely rotating container registry
credentials (Personal Access Tokens) and storing them in Kubernetes Secrets. It is designed for automated, scheduled
rotation of tokens for use with private container registries, improving security and compliance.

## Features

- Automated rotation of container registry tokens using a scheduled Kubernetes CronJob
- Secure storage of tokens in Kubernetes Secrets
- Supports multi-namespace secret management
- Highly configurable via Helm values

## Architecture

- **CronJob:** Runs the token rotation script on a schedule
- **Python App:** Calls the Crusoe API to generate new tokens and updates Kubernetes Secrets

## Prerequisites

- Kubernetes 1.21+
- Helm 3.x
- Access to the Crusoe API (with credentials)
- Access to the target container registry

## Namespace and Credentials Secret (Required for non-CMK clusters)

On Crusoe Managed Kubernetes (CMK) clusters, both the `crusoe-secrets` namespace and the `crusoe-credentials` secret are
created automatically.

**For non-CMK clusters:**  
You must manually create both the namespace and the credentials secret before installing the chart:

```sh
kubectl create namespace crusoe-secrets

kubectl create secret generic crusoe-credentials \
  --from-literal=CRUSOE_ACCESS_KEY=<your-access-key> \
  --from-literal=CRUSOE_SECRET_KEY=<your-secret-key> \
  -n crusoe-secrets
```

## Installation

1. **Clone the repository:**
   ```sh
   git clone https://gitlab.com/crusoeenergy/island/managed-platform-services/ccr/crusoe-registry-token-rotator.git
   cd crusoe-registry-token-rotator
   ```

2. **Configure values:**
   Edit `values.yaml` to set your image, registry, secret, and credential settings. Example:
   ```yaml
   image:
     repository: registry.gitlab.com/crusoeenergy/island/managed-platform-services/ccr/crusoe-registry-token-rotator
     tag: "latest"
     pullPolicy: IfNotPresent
   imagePullSecrets:
     - name: gitlab
   targetSecret:
     name: crusoe-image-pull-secrets
     namespaces:
       - default
     registryUrl: "<crusoe-registry-url>"
     registryUsername: "<crusoe-registry-username>"
   crusoeCredentialsSecretName: crusoe-credentials
   schedule: "0 */6 * * *"
   successfulJobsHistoryLimit: 3
   failedJobsHistoryLimit: 1
   resources:
     limits:
       cpu: 100m
       memory: 128Mi
     requests:
       cpu: 50m
       memory: 64Mi
   ```

3. **Install the chart:**
   ```sh
   helm install crusoe-registry-token-rotator .
   ```
   Or to upgrade:
   ```sh
   helm upgrade --install crusoe-registry-token-rotator .
   ```

## Configuration

All configuration is via `values.yaml`. Key options:

| Parameter                       | Description                                                             | Default                     |
|---------------------------------|-------------------------------------------------------------------------|-----------------------------|
| `image.repository`              | Image repository for the registry token rotator app                     |                             |
| `image.tag`                     | Image tag                                                               |                             |
| `namespace`                     | Namespace where the CronJob will be created                              | `crusoe-system`             |
| `targetSecret.name`             | Name of the Kubernetes secret to manage                                 | `crusoe-image-pull-secrets` |
| `targetSecret.namespaces`       | List of namespaces to update/create the secret in                       |                             |
| `targetSecret.registryUrl`      | Crusoe Registry URL for the secret                                      |                             |
| `targetSecret.registryUsername` | Crusoe Registry username for the secret                                 |                             |
| `crusoeCredentialsSecretName`   | Name of the secret containing Crusoe API credentials                    | `crusoe-secrets`            |
| `schedule`                      | Cron schedule for rotation job                                          | `0 */6 * * *`               |

## Usage

- The chart will periodically rotate the PAT token and update the target secret in the specified namespaces.
- Ensure the Crusoe credentials secret exists in the deployment namespace with keys `CRUSOE_ACCESS_KEY` and
  `CRUSOE_SECRET_KEY`.
- The rotated secret will be used by workloads to pull images from the configured registry.

## Security

- Runs as a non-root user in the container
- All dependencies are pinned for reproducibility

### Permissions on Kubernetes Secrets

The Crusoe Registry Token Rotator requires permissions to manage Kubernetes Secrets in each of the namespaces you specify in `targetSecret.namespaces`. Specifically, the application is granted the following permissions on secrets:

- **GET**: Read existing secrets to check their current state.
- **CREATE**: Create new secrets if they do not exist.
- **UPDATE**: Update existing secrets with new token data.
- **PATCH**: Partially update secrets as needed.

These permissions are granted via Kubernetes RBAC roles and are necessary for the app to rotate and manage registry credentials securely and automatically.

## Development

- Python dependencies are managed via `requirements.txt`
- The main app logic is in `rotate_token_api.py`
- Build the container:
  ```sh
  docker build -t crusoe-registry-token-rotator:latest .
  ```