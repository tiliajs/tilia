#!/bin/bash

set -e

# @tilia/query releases on its own schedule. The version in package.json is
# the source of truth; beta and canary stamp a date suffix and restore it.
# The published tilia range is set by clean-package at pack time.

cd "$(dirname "$0")/.."

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
  if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*)?(\+[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*)?$ ]]; then
    echo "Valid SemVer: $version"
    return 0
  else
    echo "Invalid SemVer: $version"
    return 1
  fi
}

DATE=$(date +'%Y%m%dT%H%M%S')

pnpm i
pnpm test

VERSION=$(npm pkg get version | sed 's/"//g')
is_semver "$VERSION"

if [[ $1 == "--beta" ]]; then
  VERSION=$VERSION-beta.$DATE
  npm --no-git-tag-version version $VERSION
  pnpm publish --tag beta --access public --no-git-checks
  git checkout -- package.json
  echo "Beta version published successfully!"
elif [[ $1 == "--canary" ]]; then
  VERSION=$VERSION-canary.$DATE
  npm --no-git-tag-version version $VERSION
  CANARY=true pnpm publish --tag canary --access public --no-git-checks
  git checkout -- package.json
  echo "Canary version published successfully!"
else
  pnpm publish --access public --no-git-checks
  git tag "query-v$VERSION"
  echo "Published successfully!"
fi
