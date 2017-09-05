#!/bin/bash

set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

module="BTree"
scheme="BTree-macOS"

version="$(grep VERSION_STRING version.xcconfig | sed 's/^VERSION_STRING = //' | sed 's/ *$//')"

if git rev-parse "v$version" >/dev/null 2>&1; then
    # Use the tagged commit when we have one
    ref="v$version"
else
    # Otherwise, use the current commit.
    ref="$(git rev-parse HEAD)"
fi

jazzy \
    --clean \
    --author "Károly Lőrentey" \
    --author_url "https://twitter.com/lorentey" \
    --github_url "https://github.com/attaswift/$module" \
    --github-file-prefix "https://github.com/attaswift/$module/tree/$ref" \
    --module-version "$version" \
    --xcodebuild-arguments "-scheme,$scheme" \
    --module "$module" \
    --root-url "https://attaswift.github.io/$module/reference/" \
    --theme fullwidth \
    --output gh-pages/api
