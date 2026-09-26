#!/bin/bash

set -e

# ============================================ UTILS and basic CHECKS

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

DATE=$(date +'%Y%m%dT%H%M%S')

# Install dependencies
pnpm i
# Rebuild for all projects
pnpm build

VERSION=$(npm pkg get version | sed 's/"//g')
is_semver "$VERSION"

# ============================================ PUBLISH

# The registry is whatever npm is configured to use — `~/.npmrc`, a project
# `.npmrc`, or the environment. A local registry (verdaccio) admits anonymous
# publish, but npm refuses to send one without a credential for the host and
# fails after packing with ENEEDAUTH. So supply a token for that case, in a
# throwaway user config that lasts the run.
#
# npmjs is left alone: its token is a real one, and replacing the user config
# would hide it. Only a registry that is not npmjs gets the placeholder.
REGISTRY=$(npm config get registry)
REGISTRY=${REGISTRY%/}

PUBLISH_ARGS=()
case "$REGISTRY" in
"" | *registry.npmjs.org*) NPMJS=true ;;
*)
  NPMRC=$(mktemp)
  trap 'rm -f "$NPMRC"' EXIT
  printf '//%s/:_authToken="local"\n' "${REGISTRY#*://}" >"$NPMRC"
  export NPM_CONFIG_USERCONFIG=$NPMRC
  # The temp config replaces `~/.npmrc`, `registry=` included, so name the
  # registry on each publish rather than letting it fall back to npmjs.
  PUBLISH_ARGS=(--registry "$REGISTRY")
  echo "Publishing to $REGISTRY"
  ;;
esac

# A stable release to npmjs ends with a GitHub release. Check for gh before
# anything is published.
if [[ -z $1 && -n $NPMJS ]] && ! command -v gh &>/dev/null; then
  echo "gh is not installed. Please install it first."
  exit 1
fi

# Update version if publishing beta (--beta argument)
if [[ $1 == "--beta" ]]; then
  VERSION=$VERSION-beta.$DATE
elif [[ $1 == "--canary" ]]; then
  VERSION=$VERSION-canary.$DATE
fi

# ================ TILIA
cd tilia
npm --no-git-tag-version version $VERSION

if [[ $1 == "--beta" ]]; then
  pnpm publish --tag beta --access public --no-git-checks "${PUBLISH_ARGS[@]}"
elif [[ $1 == "--canary" ]]; then
  CANARY=true pnpm publish --tag canary --access public --no-git-checks "${PUBLISH_ARGS[@]}"
else
  pnpm publish --access public --no-git-checks "${PUBLISH_ARGS[@]}"
  git tag "v$VERSION"
fi
cd ..

echo "Wait for tilia version to propagate on npm"
sleep 3
echo "Wait for tilia version to propagate on npm"
sleep 3
echo "Wait for tilia version to propagate on npm"
sleep 3

# ================ REACT
cd react
npm --no-git-tag-version version $VERSION
# Extract base version (remove pre-release suffix if present)
BASE_VERSION="${VERSION%%-*}"
MAJOR_MINOR_VERSION="${BASE_VERSION%.*}"
# Use exact version for canary/beta, otherwise use caret range
if [[ $1 == "--beta" ]] || [[ $1 == "--canary" ]]; then
  npm pkg set dependencies.tilia="$VERSION"
else
  npm pkg set dependencies.tilia="^$MAJOR_MINOR_VERSION"
fi

if [[ $1 == "--beta" ]]; then
  pnpm publish --tag beta --access public --no-git-checks "${PUBLISH_ARGS[@]}"
elif [[ $1 == "--canary" ]]; then
  CANARY=true pnpm publish --tag canary --access public --no-git-checks "${PUBLISH_ARGS[@]}"
else
  pnpm publish --access public --no-git-checks "${PUBLISH_ARGS[@]}"
fi
cd ..

# Reset git repo
git reset --hard HEAD

if [[ -z $1 && -n $NPMJS ]]; then
  git push origin "v$VERSION"
  gh release create "v$VERSION" --verify-tag --title "tilia $VERSION" \
    --notes "tilia and @tilia/react $VERSION. See the [changelog](https://github.com/tiliajs/tilia/blob/v$VERSION/README.md#changelog)."
fi

if [[ $1 == "--beta" ]]; then
  echo "Beta versions published successfully!"
elif [[ $1 == "--canary" ]]; then
  echo "Canary versions published successfully!"
else
  echo "Published successfully!"
fi

