#!/bin/bash

set -e

DATE=$(date +'%Y%m%dT%H%M%S')

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

is_semver() {
  local version="$1"
  # Regex for SemVer compliance
  if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*)?(\+[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*)?$ ]]; then
    echo "Valid SemVer: $version"
    return 0
  else
    echo "Invalid SemVer: $version"
    return 1
  fi
}

# Install dependencies
pnpm i
# Check compilation for all projects
pnpm core res:build
pnpm react res:build

cd core
CORE_VERSION=$(npm pkg get version | sed 's/"//g')
is_semver "$CORE_VERSION"
cd ../react
REACT_VERSION=$(npm pkg get version | sed 's/"//g')
is_semver "$REACT_VERSION"
cd ..

# ================ CORE
cd core
CORE_VERSION=$CORE_VERSION-canary.$DATE
npm --no-git-tag-version version $CORE_VERSION
CANARY=true pnpm publish --tag canary --access public --no-git-checks

echo "Wait for core version to propagate on npm"
sleep 3
echo "Wait for core version to propagate on npm"
sleep 3
echo "Wait for core version to propagate on npm"
sleep 3

# ================ REACT
cd ../react
REACT_VERSION=$REACT_VERSION-canary.$DATE
npm --no-git-tag-version version $REACT_VERSION
npm pkg set dependencies.@tilia/core="$CORE_VERSION"
CANARY=true pnpm publish --tag canary --access public --no-git-checks
cd ..

# Reset git repo
git reset --hard HEAD

echo "Canary versions published successfully!"
