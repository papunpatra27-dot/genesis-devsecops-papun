#!/bin/bash
# userdata.sh.tpl — bootstraps a k3s single-node cluster on Amazon Linux 2023.
# Installs k3s, Helm, and authenticates with ECR for image pulls.
set -euo pipefail

# System updates
dnf update -y
dnf install -y git curl unzip jq

# Install k3s (single-node control plane + worker)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -

# Wait for k3s to be ready
until k3s kubectl get nodes 2>/dev/null | grep -q ' Ready'; do
  sleep 5
done

# Export kubeconfig for subsequent commands
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Add Helm repos
helm repo add argo        https://argoproj.github.io/argo-helm
helm repo add kyverno     https://kyverno.github.io/kyverno/
helm repo add prometheus  https://prometheus-community.github.io/helm-charts
helm repo update

# Install Argo CD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=NodePort \
  --wait

# Install Argo Rollouts
helm install argo-rollouts argo/argo-rollouts \
  --namespace argo-rollouts \
  --create-namespace \
  --wait

# Install Kyverno
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --wait

# Install kube-prometheus-stack (Prometheus + Grafana)
helm install kube-prometheus-stack prometheus/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --wait

# ECR login helper for k3s image pulls
aws ecr get-login-password --region ${aws_region} | \
  k3s kubectl create secret docker-registry ecr-credentials \
    --docker-server=${ecr_registry} \
    --docker-username=AWS \
    --docker-password="$(aws ecr get-login-password --region ${aws_region})" \
    --namespace staging \
    --dry-run=client -o yaml | k3s kubectl apply -f -

echo "k3s bootstrap complete for ${project}-${environment}"
