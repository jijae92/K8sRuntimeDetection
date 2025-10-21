set -euo pipefail
kind delete cluster --name falco-mini || true
kind create cluster --name falco-mini
kubectl wait --for=condition=Ready nodes --all --timeout=120s