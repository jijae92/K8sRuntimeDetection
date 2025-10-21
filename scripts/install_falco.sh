set -euo pipefail
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install falco falcosecurity/falco \
  -n falco \
  -f infra/helm/falco-values.kind.yaml \
  --set-file customRules.rulesFile=rules/custom_rules.yaml
kubectl -n falco rollout status ds/falco --timeout=180s