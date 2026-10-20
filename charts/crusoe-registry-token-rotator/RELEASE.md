<!-- chart-version: 1.3.0 -->

## What changed

Three values are renamed. **The old names still work**, and still take precedence when set, but
the chart now prints a warning naming each one, and they are removed in 2.0.0.

| Deprecated | Replacement |
|------------|-------------|
| `rbac.create` | `serviceAccount.create` |
| `rbac.serviceAccount.name` | `serviceAccount.name` |
| `namespace` | `helm install --namespace` |

Resources now install into the release namespace, the one you pass to Helm, rather than
`.Values.namespace`.

No Kubernetes object names change in this release.

## Before you upgrade

**The upgrade will refuse to run in two cases**, both to do with where your resources live. Helm
cannot move objects between namespaces during an upgrade, so proceeding would delete them and
recreate them elsewhere.

1. You set `namespace` to something other than the namespace you pass to Helm.
2. An earlier version placed your resources in `crusoe-system` while the Helm release itself lives
   in a different namespace. This happens if you installed with `--namespace <something-else>`
   without setting `namespace`, because it used to default to `crusoe-system` regardless.

In both cases the chart stops and tells you how to proceed. The release is left untouched, so
there is nothing to roll back.

If you installed the documented way, with `--namespace crusoe-system`, nothing changes and you can
simply drop the key from your values.

## Impact on running workloads

None. The chart does not touch the image pull secret it generates, so pods already using it keep
running across the upgrade without restarting.

## Migrating your values

```yaml
# before
namespace: crusoe-system
rbac:
  create: true
  serviceAccount:
    name: my-rotator

# after
serviceAccount:
  create: true
  name: my-rotator
# and install with: helm upgrade ... --namespace crusoe-system
```

## Upgrading

```sh
helm repo update
helm upgrade crusoe-registry-token-rotator crusoe/crusoe-registry-token-rotator \
  --namespace crusoe-system
```
