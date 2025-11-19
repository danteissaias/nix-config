#!/bin/sh

# Update nix flake inputs
nix flake update

# Update npm packages to latest versions
(cd global && npx npm-check-updates -u && npm install)

# Fix package-lock.json and update npmDepsHash
echo "Fixing package-lock.json..."
nix run nixpkgs#npm-lockfile-fix global/package-lock.json
echo "Updating npmDepsHash..."
nix run nixpkgs#prefetch-npm-deps global/package-lock.json > global/deps.hash
echo "Updated deps.hash: $(cat global/deps.hash)"
