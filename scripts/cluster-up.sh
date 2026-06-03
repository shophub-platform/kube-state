#!/usr/bin/env bash
# cluster-up.sh — podiže lokalni k3d klaster "shophub" i instalira ceo platform stack.
# Idempotentno: bezbedno je pokrenuti više puta (helm upgrade --install).
# Zahtevi: docker, k3d, kubectl, helm
# Pokretanje:  bash scripts/cluster-up.sh
set -euo pipefail

CLUSTER_NAME="shophub"
REGISTRY_PORT="5000"
AGENTS=3

echo "==> [1/4] Registry"
k3d registry create registry.localhost --port "${REGISTRY_PORT}" 2>/dev/null || echo "    registry već postoji"

echo "==> [2/4] k3d klaster (Traefik isključen da bi ingress-nginx mogao na 80/443)"
if ! k3d cluster list | grep -q "^${CLUSTER_NAME}"; then
  k3d cluster create "${CLUSTER_NAME}" \
    --servers 1 --agents "${AGENTS}" \
    --registry-use "k3d-registry.localhost:${REGISTRY_PORT}" \
    --k3s-arg "--disable=traefik@server:0" \
    --port "80:80@loadbalancer" --port "443:443@loadbalancer" --wait
else
  echo "    klaster postoji, pokrećem ga"
  k3d cluster start "${CLUSTER_NAME}"
fi

k3d kubeconfig merge "${CLUSTER_NAME}" --kubeconfig-switch-context >/dev/null
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "==> [3/4] Helm repozitorijumi"
helm repo add jetstack https://charts.jetstack.io >/dev/null 2>&1 || true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo add cnpg https://cloudnative-pg.github.io/charts >/dev/null 2>&1 || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "==> [4/4] Instalacija komponenti"
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true --wait --timeout 5m

helm upgrade --install cnpg cnpg/cloudnative-pg \
  --namespace cnpg-system --create-namespace --wait --timeout 5m

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer --wait --timeout 5m

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace --wait --timeout 10m

echo
echo "==> Gotovo. Provera:"
kubectl get nodes
echo
echo "Grafana:  kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80"
echo "Login:    admin / (kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d)"