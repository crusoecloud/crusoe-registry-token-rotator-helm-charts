## What changed

The chart now defines its Secret permissions once in a `ClusterRole` and grants them with one
`RoleBinding` per target namespace, instead of copying an identical `Role` into every namespace.

**What the rotator can access is unchanged.** A RoleBinding that references a ClusterRole applies
only inside its own namespace, so access stays limited to the namespaces listed in
`targetSecret.namespaces`. It still manages only the single secret named in `targetSecret.name`.

The benefit is scale. Objects created go from `2 + 2n` to `3 + n` for `n` target namespaces. At 50
namespaces a `helm upgrade` drops from roughly 77s to 38s.

## Before you upgrade

**Installing now requires permission to create a `ClusterRole`.** If your cluster restricts
cluster-scoped RBAC, or runs an admission policy that blocks charts from creating it, set
`rbac.create: false`, have an administrator apply the RBAC separately, and point
`rbac.serviceAccount.name` at the ServiceAccount you created.

The per-namespace `RoleBinding` objects are renamed, so the upgrade replaces them rather than
patching them. This is required: `roleRef` is immutable in Kubernetes, so an existing binding
cannot be repointed at a ClusterRole in place.

## Impact on running workloads

None. The chart does not touch the image pull secret it generates, so pods already using it keep
running across the upgrade without restarting.

## Upgrading

```sh
helm repo update
helm upgrade crusoe-registry-token-rotator crusoe/crusoe-registry-token-rotator \
  --namespace crusoe-system
```
