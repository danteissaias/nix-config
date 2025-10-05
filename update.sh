#!/bin/sh

# Update nix flake inputs
nix flake update

# Update npm packages to latest versions
(cd global && bun update --latest)
