set -euo pipefail
kubectl apply -f manifests/demo/ns.yaml
kubectl apply -f manifests/demo/pod-alpine.yaml
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=20
kubectl -n falco-demo exec alpine-demo -- sh -lc 'echo "[demo] shell spawned"; apk update || true'
kubectl -n falco-demo exec alpine-demo -- sh -lc 'echo "* * * * * echo hi" >> /etc/cron.d/demo || true'
kubectl -n falco-demo exec alpine-demo -- sh -lc 'wget -qO- http://169.254.169.254/latest/meta-data/ || true'
kubectl -n falco-demo exec alpine-demo -- sh -lc 'nc -zv 127.0.0.1 4444 || true'
kubectl -n falco-demo exec alpine-demo -- sh -lc 'touch /etc/demo && chmod 777 /etc/demo || true'
sleep 5
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=200 | egrep -e "SHELL in container|PKG MANAGER|IMDS access|SUSPICIOUS outbound|WRITE cron|PERM change|MOUNT|PRIVILEGED container|WRITE to system bin|WRITE sensitive file" || true