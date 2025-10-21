set -euo pipefail
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm upgrade --install falcosidekick falcosecurity/falcosidekick \
  -n falco \
  -f infra/helm/falcosidekick-values.stdout.yaml
kubectl -n falco rollout status deploy/falcosidekick --timeout=120s