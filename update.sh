#!/bin/sh

# Update nix flake inputs
nix flake update

./apply-npm.sh

