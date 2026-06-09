#!/bin/bash
# scripts/increment_build.sh

PUBSPEC="pubspec.yaml"
CURRENT_VERSION=$(grep '^version: ' "$PUBSPEC" | awk '{print $2}')
BASE_VERSION="${CURRENT_VERSION%+*}"
BUILD_NUM="${CURRENT_VERSION#*+}"

if [[ "$CURRENT_VERSION" != *"+"* || -z "$BUILD_NUM" ]]; then
  NEW_BUILD_NUM=1
else
  NEW_BUILD_NUM=$((BUILD_NUM + 1))
fi

NEW_VERSION="${BASE_VERSION}+${NEW_BUILD_NUM}"
if [[ "$(uname -s)" == "Darwin" ]]; then
  # macOS/BSD sed requires an empty string for the backup extension
  sed -i '' "s/^version: .*/version: ${NEW_VERSION}/" "$PUBSPEC"
else
  # GNU sed for Linux
  sed -i "s/^version: .*/version: ${NEW_VERSION}/" "$PUBSPEC"
fi
echo "Bumped version to $NEW_VERSION"
