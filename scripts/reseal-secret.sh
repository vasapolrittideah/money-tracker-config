#!/bin/bash

set -e

SEALED_SECRET_FILENAME="secret-sealed.yml"

kubeseal --fetch-cert --controller-namespace kube-system > pub-cert.pem

environments=("dev" "staging" "prod")

for env in "${environments[@]}"; do
  echo "Processing environment: $env"

  if compgen -G "secrets/$env/*.yml" > /dev/null; then
    for file in secrets/$env/*.yml; do
      service=$(basename "$file" .yml)
      output_dir="k8s/$service/overlays/$env"
      output_path="$output_dir/$SEALED_SECRET_FILENAME"

      echo "  Resealing: $file → $output_path"

      kubeseal --scope=namespace-wide --format=yaml --cert pub-cert.pem < "$file" > "$output_path"
    done
  else
    echo "  ⚠️  No .yml files found in secrets/$env, skipping..."
  fi
done

rm pub-cert.pem
rm secret-sealed.yml

echo "✅ All secrets resealed successfully."