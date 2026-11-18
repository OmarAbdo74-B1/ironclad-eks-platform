#!/usr/bin/env bash
set -euo pipefail

helm repo add traefik https://traefik.github.io/charts >/dev/null 2>&1 || true
helm repo update traefik

helm upgrade --install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --version 42.4.1 \
  -f "$(dirname "$0")/values-local.yaml"
