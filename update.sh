#!/bin/sh

# Update nix flake inputs
nix flake update

# Update npm packages to latest versions
(cd global && npx npm-check-updates -u && npm install)

echo "Fixing package-lock.json..."
sed -i '' 's|https://registry.npmjs.org|https://registry.yarnpkg.com|g' global/package-lock.json
