set -euo pipefail
: "${FALCO_CHART_VERSION:?Set FALCO_CHART_VERSION (e.g., 2.x.y)}"
CLUSTER_TYPE=${1:-kind}

VALUES_FILE="infra/helm/falco-values.${CLUSTER_TYPE}.yaml"

helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install falco falcosecurity/falco \
  -n falco \
  -f "${VALUES_FILE}" \
  --set-file customRules.rulesFile=rules/custom_rules.yaml \
  --version "$FALCO_CHART_VERSION"
kubectl -n falco rollout status ds/falco --timeout=180s