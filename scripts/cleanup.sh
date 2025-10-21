set -euo pipefail
kubectl delete -f manifests/demo/pod-alpine.yaml --ignore-not-found
kubectl delete -f manifests/demo/ns.yaml --ignore-not-found
helm -n falco uninstall falcosidekick || true
helm -n falco uninstall falco || true
kubectl delete ns falco --ignore-not-found
kind delete cluster --name falco-mini || true