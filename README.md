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

On Crusoe Managed Kubernetes (CMK) clusters, both the `crusoe-system` namespace and the `crusoe-secrets` secret are
created automatically. The cronjob will use the `crusoe-secrets` secret to authenticate to the Crusoe API and will
be deployed in `crusoe-system` namespace. If you choose to use another namespace for the cronjob, you must manually
create the `crusoe-secrets` secret in that namespace.

**For non-CMK clusters:**  
You must manually create both the namespace and the credentials secret before installing the chart:

```sh
kubectl create namespace crusoe-system

kubectl create secret generic crusoe-secrets \
  --from-literal=CRUSOE_ACCESS_KEY=<your-access-key> \
  --from-literal=CRUSOE_SECRET_KEY=<your-secret-key> \
  -n crusoe-system
```

## Installation

**Note:** Before installing the chart, ensure your `kubectl` context is set to the correct cluster:
```sh
kubectl config current-context
```
If needed, switch to the appropriate context with:
```sh
kubectl config use-context <your-context-name>
```

1. **Clone the repository:**
   ```sh
   git clone https://github.com/crusoecloud/crusoe-registry-token-rotator-helm-charts.git
   cd crusoe-registry-token-rotator-helm-charts
   ```

2. **Edit values.yaml:**
   Update the following fields in `charts/crusoe-registry-token-rotator/values.yaml`:
   - `targetSecret.registryUrl`: Set to your registry URL (required)
   - `targetSecret.registryUsername`: Set to your registry username (required)
   - `targetSecret.namespaces`: (Optional) Update if you want the secret created in namespaces other than `default`
     Example:
   ```yaml
   image:
     repository: ghcr.io/crusoecloud/crusoe-registry-token-rotator
     tag: "latest"
     pullPolicy: IfNotPresent
   targetSecret:
     name: crusoe-image-pull-secrets
     namespaces:
       - default
       - <namespace1>
       - <namespace2>
     registryUrl: "<crusoe-registry-url>"
     registryUsername: "<crusoe-registry-username>"
   crusoeCredentialsSecretName: crusoe-secrets
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
   helm install crusoe-registry-token-rotator ./charts/crusoe-registry-token-rotator \
     --namespace crusoe-system
   ```
   Or to upgrade:
   ```sh
   helm upgrade --install crusoe-registry-token-rotator ./charts/crusoe-registry-token-rotator \
     --namespace crusoe-system
   ```

4. **Verify the installation:**
   After installing the chart, verify that the release and its resources were created successfully:
   ```sh
   helm list --namespace crusoe-system
   ```
   You should see output similar to the following:
 
   ```
   NAME                         NAMESPACE      REVISION UPDATED                              STATUS   CHART                               APP VERSION
   crusoe-registry-token-rotator crusoe-system 1        2025-09-16 13:55:57.593474 -0700 PDT  deployed crusoe-registry-token-rotator-1.0.0
   ```
   To verify the CronJob was created, run:
   ```sh
   kubectl get cronjobs -n crusoe-system
   ```
   You should see output similar to:
   ```
   NAME                            SCHEDULE      TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE
   crusoe-registry-token-rotator   0 */6 * * *   <none>     False     0        5h29m           9d
   ```

5. **(Optional) Trigger a test run of the CronJob:**
   By default, the CronJob runs on a schedule. To manually trigger a run for testing:
   ```sh
   kubectl create job --from=cronjob/crusoe-registry-token-rotator crusoe-registry-token-rotator-manual-test -n crusoe-system
   ```
   You can monitor the job with:
   ```sh
   kubectl get jobs -n crusoe-system
   kubectl logs job/crusoe-registry-token-rotator-manual-test -n crusoe-system
   ```

## Configuration

All configuration is via `values.yaml`. Key options:

| Parameter                       | Description                                          | Default                                             |
|---------------------------------|------------------------------------------------------|-----------------------------------------------------|
| `image.repository`              | Image repository for the registry token rotator app  | `ghcr.io/crusoecloud/crusoe-registry-token-rotator` |
| `image.tag`                     | Image tag                                            | `latest`                                            |
| `serviceAccount.create`         | Create the ServiceAccount, ClusterRole and RoleBindings | `true`                                           |
| `serviceAccount.name`           | ServiceAccount name. If empty, derived from release  | `""`                                                |
| `rbac.create`                   | Deprecated alias for `serviceAccount.create`         | unset                                               |
| `rbac.serviceAccount.name`      | Deprecated alias for `serviceAccount.name`           | unset                                               |
| `namespace`                     | Deprecated. Use `helm --namespace`                   | unset                                               |
| `targetSecret.name`             | Name of the Kubernetes secret to manage              | `crusoe-image-pull-secrets`                         |
| `targetSecret.namespaces`       | List of namespaces to update/create the secret in    | `default`                                            |
| `targetSecret.registryUrl`      | Crusoe Registry URL for the secret                   |                                                     |
| `targetSecret.registryUsername` | Crusoe Registry username for the secret              |                                                     |
| `crusoeCredentialsSecretName`   | Name of the secret containing Crusoe API credentials | `crusoe-secrets`                                    |
| `schedule`                      | Cron schedule for rotation job                       | `0 */6 * * *`                                       |

## Usage

- The chart will periodically rotate the PAT token and update the target secret in the specified namespaces.
- Ensure the Crusoe credentials secret exists in the deployment namespace with keys `CRUSOE_ACCESS_KEY` and
  `CRUSOE_SECRET_KEY`.
- The rotated secret will be used by workloads to pull images from the configured registry.

## Security

- Runs as a non-root user in the container
- All dependencies are pinned for reproducibility

### Permissions on Kubernetes Secrets

The rotator manages a single secret, the one named in `targetSecret.name`, in each namespace listed in
`targetSecret.namespaces`. The permissions are defined once in a `ClusterRole` and granted by one
`RoleBinding` per target namespace. A RoleBinding that references a ClusterRole applies only inside its own
namespace, so the rotator's access stays limited to the namespaces you configure. The permissions granted are:

- **create**: unscoped, because Kubernetes RBAC cannot restrict `create` by resource name. The object does not
  exist yet when the request is authorized.
- **get**, **update**, **patch**: restricted via `resourceNames` to `targetSecret.name`. The rotator cannot read or
  modify any other secret.

No permissions are granted in the deployment namespace. The Crusoe API credentials reach the pod through
`secretKeyRef`, which the kubelet resolves, so the ServiceAccount never reads that secret through the Kubernetes API
and needs no access to it.

The CronJob runs as a dedicated ServiceAccount. It never falls back to the namespace's `default` ServiceAccount,
which would otherwise extend these permissions to every pod using that account.

The `ClusterRole` is a cluster-scoped object, so installing the chart requires permission to create one. Its name
includes the release namespace, so two releases of this chart can coexist in one cluster.

Set `serviceAccount.create: false` to manage RBAC yourself. The chart then creates no ServiceAccount, ClusterRole
or RoleBinding, and you must set `serviceAccount.name` to an account you have already bound; rendering fails if you
do not.

## Deprecated values

Three keys are deprecated and will be removed in 2.0.0. They still take effect today, and override their
replacements when set, but the chart prints a warning on install and upgrade.

| Deprecated | Replacement |
|------------|-------------|
| `rbac.create` | `serviceAccount.create` |
| `rbac.serviceAccount.name` | `serviceAccount.name` |
| `namespace` | `helm install --namespace` |

Resources now install into the release namespace rather than `.Values.namespace`. If you set `namespace` to
something other than the namespace you pass to Helm, rendering fails with instructions instead of relocating your
resources, because Helm cannot move objects between namespaces during an upgrade.

If you install the way the Installation section describes, with `--namespace crusoe-system`, nothing changes for
you and you can simply drop the key.

## Development

- Python dependencies are managed via `requirements.txt`
- The main app logic is in `rotate_token_api.py`
- Build the container:
  ```sh
  docker build -t crusoe-registry-token-rotator:latest .
  ```