#!/bin/bash

set -e

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
pnpm tilia res:build
pnpm react res:build

cd tilia
TILIA_VERSION=$(npm pkg get version | sed 's/"//g')
is_semver "$TILIA_VERSION"
cd ../react
REACT_VERSION=$(npm pkg get version | sed 's/"//g')
is_semver "$REACT_VERSION"
cd ..

# ================ TILIA
cd tilia
pnpm publish --access public --no-git-checks

echo "Wait for tilia version to propagate on npm"
sleep 3
echo "Wait for tilia version to propagate on npm"
sleep 3
echo "Wait for tilia version to propagate on npm"
sleep 3

# ================ REACT
cd ../react
npm pkg set dependencies.@tilia/tilia="$TILIA_VERSION"
pnpm publish --access public --no-git-checks
cd ..

# Reset git repo
git reset --hard HEAD
git tag v$TILIA_VERSION

echo "Published successfully!"
