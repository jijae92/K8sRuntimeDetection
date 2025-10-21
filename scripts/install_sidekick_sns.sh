set -euo pipefail
: "${AWS_REGION:?}"
: "${SNS_TOPIC_ARN:?}"
: "${FALCOSIDEKICK_ROLE_ARN:?}"
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
envsubst < infra/helm/falcosidekick-values.sns.yaml | tee /tmp/falcosidekick-values.sns.yaml
helm upgrade --install falcosidekick falcosecurity/falcosidekick \
  -n falco \
  -f /tmp/falcosidekick-values.sns.yaml
kubectl -n falco rollout status deploy/falcosidekick --timeout=120s