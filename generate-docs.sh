#!/bin/sh

set -e

module="BTree"
scheme="BTree-Mac"

version="$(grep VERSION_STRING version.xcconfig | sed 's/^VERSION_STRING = //' | sed 's/ *$//')"
tag="v$version"

jazzy \
    --clean \
    --author "Károly Lőrentey" \
    --author_url "https://twitter.com/lorentey" \
    --github_url "https://github.com/lorentey/$module" \
    --github-file-prefix "https://github.com/lorentey/$module/tree/$tag" \
    --module-version "$version" \
    --xcodebuild-arguments "-scheme,$scheme" \
    --module "$module" \
    --root-url "https://lorentey.github.io/$module/reference/" \
    --theme fullwidth \
    --output gh-pages/api \
    --swift-version 2.1.1
