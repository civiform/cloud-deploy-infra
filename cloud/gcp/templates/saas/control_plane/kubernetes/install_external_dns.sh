#! /usr/bin/env bash

helm repo add bitnami https://charts.bitnami.com/bitnami

helm install external-dns \
  --set provider=cloudflare \
  --set cloudflare.apiToken="${CLOUDFLARE_API_TOKEN}" \
  --set cloudflare.proxied=false \
  --set nodeSelector."cloud\\.google\\.com/gke-nodepool"=np-control-plane \
  bitnami/external-dns
