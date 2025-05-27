#!/bin/bash

set -e

SEALED_SECRET_FILENAME="secret-sealed.yml"
PUB_CERT="pub-cert.pem"

cleanup() {
  echo "🧹 Cleaning up..."
  [[ -f "$PUB_CERT" ]] && rm -f "$PUB_CERT"
  [[ -f "$SEALED_SECRET_FILENAME" ]] && rm -f "$SEALED_SECRET_FILENAME"
}
trap cleanup EXIT

kubeseal --fetch-cert --controller-namespace kube-system > "$PUB_CERT"

if compgen -G "secrets/*.yml" > /dev/null; then
  for file in secrets/*.yml; do
    service=$(basename "$file" .yml)
    out_dir="argocd/apps/base"
    output_path="$out_dir/$SEALED_SECRET_FILENAME"

    echo "  🔐 Sealing: $file → $output_path"
    kubeseal --scope=cluster-wide --format=yaml --cert "$PUB_CERT" < "$file" > "$output_path"
  done
fi

environments=("dev" "staging" "prod")

for env in "${environments[@]}"; do
  echo "📦 Processing environment: $env"

  if compgen -G "secrets/$env/*.yml" > /dev/null; then
    for file in secrets/$env/*.yml; do
      service=$(basename "$file" .yml)
      output_dir="k8s/$service/overlays/$env"
      output_path="$output_dir/$SEALED_SECRET_FILENAME"

      echo "  🔐 Resealing: $file → $output_path"
      kubeseal --scope=namespace-wide --format=yaml --cert "$PUB_CERT" < "$file" > "$output_path"
    done
  else
    echo "  ⚠️  No secrets found for environment '$env'. Skipping..."
  fi
done

echo "✅ All secrets resealed successfully."