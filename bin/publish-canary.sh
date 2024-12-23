#!/bin/bash

# Set up environment
if ! command -v pnpm &>/dev/null; then
  echo "pnpm is not installed. Please install it first."
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Error: There are uncommitted changes in the repository."
  echo "Please commit or stash your changes before proceeding."
  exit 1
else
  echo "Repository is clean. Proceeding with the operation."
fi

# Install dependencies
pnpm install-all

# Build packages
pnpm core build
pnpm react build

# Set canary versions
for pkg in core react; do
  cd packages/$pkg
  npm --no-git-tag-version version $(npm pkg get version | sed 's/"//g')-canary.$(date +'%Y%m%dT%H%M%S')
  cd ../..
done

# Publish @tilia/core to NPM
npm publish --tag canary --access public

# Update @tilia/react dependency
cd ../react
pnpm add @tilia/core@canary

# Publish @tilia/react to NPM
npm publish --tag canary --access public

echo "Canary versions published successfully!"

# reset git repo
git reset --hard HEAD
