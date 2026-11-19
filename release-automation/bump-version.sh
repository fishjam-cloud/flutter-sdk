#!/bin/bash
set -euo pipefail

# Called by the release automation during a release.
# Creates a release branch and bumps the package version without committing;
# the caller commits, pushes and opens the PR. Must print BRANCH_NAME:<branch>.
#
# Usage: ./bump-version.sh <version>

VERSION="${1:-}"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

BRANCH_NAME="release-$VERSION"
git checkout -b "$BRANCH_NAME"

# perl -pi works the same with GNU and BSD tools.
export VERSION
perl -pi -e 's/^version: .*/version: $ENV{VERSION}/' pubspec.yaml
echo "Updated pubspec.yaml to $VERSION"

# A test checks that this matches pubspec.yaml.
perl -pi -e "s/^const packageVersion = '.*';/const packageVersion = '\$ENV{VERSION}';/" lib/src/version.dart
echo "Updated lib/src/version.dart to $VERSION"

# pub.dev shows the changelog entry for the published version.
if ! grep -q "^## $VERSION\$" CHANGELOG.md; then
    printf '## %s\n\n- TODO: describe the changes in this release.\n\n' "$VERSION" | cat - CHANGELOG.md >CHANGELOG.md.tmp
    mv CHANGELOG.md.tmp CHANGELOG.md
    echo "Added a CHANGELOG.md entry for $VERSION"
fi

echo "BRANCH_NAME:$BRANCH_NAME"
