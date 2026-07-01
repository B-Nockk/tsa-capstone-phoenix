#!/bin/bash
# scripts/gh-vars-delete.sh
set -e
REPO=$(gh repo view --json name,owner -q '.owner.login + "/" + .name')

if [ -n "$1" ]; then
  echo "🗑️  Deleting variable: $1"
  gh variable delete "$1" --repo "$REPO"
  echo "✅ Done"
  exit 0
fi

echo "🗑️  Deleting ALL variables in $REPO..."
read -p "Are you sure? (y/N) " confirm
[[ "$confirm" != "y" ]] && { echo "Aborted."; exit 1; }

VAR_NAMES=$(gh variable list --repo "$REPO" --json name -q '.[].name')
if [ -z "$VAR_NAMES" ]; then
  echo "No variables found."
  exit 0
fi

for name in $VAR_NAMES; do
  echo "  Deleting $name..."
  gh variable delete "$name" --repo "$REPO"
done
echo "✅ All variables deleted"
