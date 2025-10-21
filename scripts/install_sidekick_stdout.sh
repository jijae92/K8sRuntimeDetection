set -euo pipefail
: "${FALCOSIDEKICK_CHART_VERSION:?Set FALCOSIDEKICK_CHART_VERSION (e.g., 0.5.x)}"
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm upgrade --install falcosidekick falcosecurity/falcosidekick \
  -n falco \
  -f infra/helm/falcosidekick-values.stdout.yaml \
  --version "$FALCOSIDEKICK_CHART_VERSION"
kubectl -n falco rollout status deploy/falcosidekick --timeout=120s