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

# Whatever the run leaves behind is undone here, on success or failure alike.
# A stamped version left in package.json would stop the *next* run at the
# clean-tree check above, so the retry never gets a chance.
NPMRC=""
cleanup() {
  [ -n "$NPMRC" ] && rm -f "$NPMRC"
  git checkout -- package.json
}
trap cleanup EXIT

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

pnpm i
pnpm test

DATE=$(date +'%Y%m%dT%H%M%S')

VERSION=$(npm pkg get version | sed 's/"//g')
is_semver "$VERSION"

if [[ $1 == "--beta" ]]; then
  VERSION=$VERSION-beta.$DATE
  npm --no-git-tag-version version $VERSION
  pnpm publish --tag beta --access public --no-git-checks "${PUBLISH_ARGS[@]}"
  echo "Beta version published successfully!"
elif [[ $1 == "--canary" ]]; then
  VERSION=$VERSION-canary.$DATE
  npm --no-git-tag-version version $VERSION
  CANARY=true pnpm publish --tag canary --access public --no-git-checks "${PUBLISH_ARGS[@]}"
  echo "Canary version published successfully!"
else
  pnpm publish --access public --no-git-checks "${PUBLISH_ARGS[@]}"
  git tag "query-v$VERSION"
  if [[ -n $NPMJS ]]; then
    git push origin "query-v$VERSION"
    gh release create "query-v$VERSION" --verify-tag --title "@tilia/query $VERSION" \
      --notes "See the [changelog](https://github.com/tiliajs/tilia/blob/query-v$VERSION/query/README.md#changelog)."
  fi
  echo "Published successfully!"
fi
