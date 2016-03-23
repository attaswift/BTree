#!/bin/bash

set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

module="BTree"
scheme="BTree-Mac"

version="$(grep VERSION_STRING version.xcconfig | sed 's/^VERSION_STRING = //' | sed 's/ *$//')"
case "$version" in
*-dev)
  # For dev versions, use the current revision.
  ref="$(git rev-parse HEAD)"
  ;;
*)
  # For releases, use the tagged commit.
  ref="v$version"
  ;;
esac

jazzy \
    --clean \
    --author "Károly Lőrentey" \
    --author_url "https://twitter.com/lorentey" \
    --github_url "https://github.com/lorentey/$module" \
    --github-file-prefix "https://github.com/lorentey/$module/tree/$ref" \
    --module-version "$version" \
    --xcodebuild-arguments "-scheme,$scheme" \
    --module "$module" \
    --root-url "https://lorentey.github.io/$module/reference/" \
    --theme fullwidth \
    --output gh-pages/api \
    --swift-version 2.2
