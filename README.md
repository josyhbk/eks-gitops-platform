# eks-gitops-platform

A Kubernetes platform managed by Argo CD from this repo: a Gateway API
gateway, secrets, monitoring and a sample app. One command builds it on a
local kind cluster.

| Wave | Component | What it does |
|---|---|---|
| 0 | [Envoy Gateway](https://gateway.envoyproxy.io) | Gateway API controller |
| 0 | [External Secrets](https://external-secrets.io) | Secrets from a store or generated in the cluster, never in git |
| 1 | gateway | The shared `Gateway` every app attaches its `HTTPRoute` to |
| 1 | [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) | Prometheus, Alertmanager, Grafana |
| 2 | demo | [podinfo](https://github.com/stefanprodan/podinfo) with its route, scrape config, alert rules and a dashboard |
| 3 | [Argo CD](https://argo-cd.readthedocs.io) | Manages its own install like any other component |

## Run it

Needs Docker with about 6 GB of memory, [kind](https://kind.sigs.k8s.io),
kubectl and helm.

```bash
make up        # kind cluster, Argo CD, root app, then waits until all apps are healthy
make password  # Argo CD and Grafana admin logins
```

| URL | |
|---|---|
| http://demo.localhost:8880 | podinfo |
| http://argocd.localhost:8880 | Argo CD |
| http://grafana.localhost:8880 | Grafana, see the "Demo app" dashboard |

`make down` deletes the cluster.

To try a change, push it to a branch or a fork and point the cluster at it:

```bash
make root REPO_URL=https://github.com/<you>/eks-gitops-platform.git REVISION=<branch>
```

## How it works

`make up` installs Argo CD with Helm and applies one Application by hand,
`bootstrap/root.yaml`. That root app renders the `clusters/` chart, which has
one Application per component listed in `clusters/values.yaml`. Argo CD
takes over from there, its own install included.

```
bootstrap/  kind config, the root Application, the wait script
clusters/   chart that renders an Application per component
platform/   shared services, one folder per component
apps/       workloads
```

Each component folder has a `values.yaml`, an optional
`values-<cluster>.yaml` and an optional `manifests/` folder for plain YAML
that goes with the chart (dashboards, alert rules, secrets). `CLUSTER=local`
(the default) picks up the `values-local.yaml` files. A cluster file can set
`enabled: false` on a component to leave it out.

To add a component, add an entry to `clusters/values.yaml` with its chart,
version, namespace and wave, plus a folder with its values.

## Choices

- **Gateway API, not Ingress.** ingress-nginx was retired upstream. The routes
  here are standard `HTTPRoute`s, so Envoy Gateway can be swapped for another
  controller (Istio, the AWS Load Balancer Controller) without touching the apps.
- **Waves wait for health.** Argo CD no longer reports a child Application's
  health to its parent by default, so a wave would start as soon as the one
  before was applied. A health check in `platform/argocd/values.yaml` brings
  that back, and each wave waits for the previous one to be healthy.
- **No passwords in git.** External Secrets generates the Grafana admin
  password once, inside the cluster. Left to the chart, the password is
  random on every render, which under Argo CD means a new password and a
  Grafana restart on every sync.
- **Retries on first sync.** A component can sync before a CRD it uses is
  ready. Each Application retries with backoff instead of failing.

## Next

- EKS with Terraform: VPC, EKS, Karpenter, Pod Identity, and a `values-eks.yaml` per component
- Alertmanager to Slack, with the webhook from AWS Secrets Manager
- CI that runs `make up` on every pull request
