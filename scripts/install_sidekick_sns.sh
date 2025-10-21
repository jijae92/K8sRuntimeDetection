set -euo pipefail
: "${FALCOSIDEKICK_CHART_VERSION:?Set FALCOSIDEKICK_CHART_VERSION (e.g., 0.5.x)}"
: "${AWS_REGION:?}"
: "${SNS_TOPIC_ARN:?}"
: "${FALCOSIDEKICK_ROLE_ARN:?}"
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
TMP_VALUES_FILE="$(mktemp -t falcosidekick-values.XXXXXX.yaml)"
trap 'rm -f "$TMP_VALUES_FILE"' EXIT
envsubst < infra/helm/falcosidekick-values.sns.yaml > "$TMP_VALUES_FILE"
helm upgrade --install falcosidekick falcosecurity/falcosidekick \
  -n falco \
  -f "$TMP_VALUES_FILE" \
  --version "$FALCOSIDEKICK_CHART_VERSION"
kubectl -n falco rollout status deploy/falcosidekick --timeout=120s