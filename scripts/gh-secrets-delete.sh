#!/bin/bash
# scripts/gh-secrets-delete.sh
set -e
REPO=$(gh repo view --json name,owner -q '.owner.login + "/" + .name')

if [ -n "$1" ]; then
  echo "🗑️  Deleting secret: $1"
  gh secret delete "$1" --repo "$REPO"
  echo "✅ Done"
  exit 0
fi

echo "🗑️  Deleting ALL secrets in $REPO..."
read -p "Are you sure? (y/N) " confirm
[[ "$confirm" != "y" ]] && { echo "Aborted."; exit 1; }

SECRET_NAMES=$(gh secret list --repo "$REPO" --json name -q '.[].name')
if [ -z "$SECRET_NAMES" ]; then
  echo "No secrets found."
  exit 0
fi

for name in $SECRET_NAMES; do
  echo "  Deleting $name..."
  gh secret delete "$name" --repo "$REPO"
done
echo "✅ All secrets deleted"
