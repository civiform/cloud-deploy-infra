#!/usr/bin/env sh

helm install external-dns \
  --set provider=cloudflare \
  oci://registry-1.docker.io/bitnamicharts/external-dns
