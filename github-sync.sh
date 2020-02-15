#!/bin/sh

set -e

UPSTREAM_REPO=$1
BRANCH_MAPPING=$2
EXCLUDED_FILES=$3

if [[ -z "$UPSTREAM_REPO" ]]; then
  echo "Missing \$UPSTREAM_REPO"
  exit 1
fi

if [[ -z "$BRANCH_MAPPING" ]]; then
  echo "Missing \$SOURCE_BRANCH:\$DESTINATION_BRANCH"
  exit 1
fi

if ! echo $UPSTREAM_REPO | grep '\.git'
then
  UPSTREAM_REPO="https://github.com/${UPSTREAM_REPO}.git"
fi

SOURCE_BRANCH="${BRANCH_MAPPING%%:*}"
DESTINATION_BRANCH="${BRANCH_MAPPING#*:}"

echo "UPSTREAM_REPO=$UPSTREAM_REPO"
echo "BRANCHES=$BRANCH_MAPPING"

# GitHub actions v2 no longer auto set GITHUB_TOKEN
git remote set-url origin "https://$GITHUB_ACTOR:$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY"
git remote add tmp_upstream "$UPSTREAM_REPO"
git fetch tmp_upstream
git remote -v

if git ls-remote --exit-code --heads origin "${DESTINATION_BRANCH}"; then
  # When the destination branch already exists, switch to it and merge in the source branch
  git checkout -b "${DESTINATION_BRANCH}" "refs/remotes/origin/${DESTINATION_BRANCH}"
  git merge --commit --no-edit -ff "refs/remotes/tmp_upstream/${SOURCE_BRANCH}"
  # TODO: handle merge conflicts
else
  # When the destination does not exist yet, checkout the source branch as destination
  git checkout -b "${DESTINATION_BRANCH}" "refs/remotes/tmp_upstream/${SOURCE_BRANCH}"
fi

if [[ ! -z "$EXCLUDED_FILES" ]]; then
  git reset origin/master -- "${EXCLUDED_FILES}"

  if output=$(git status --porcelain) && [[ ! -z "$output" ]]; then
    git commit --message="Revert changes to excluded files"
    git clean -f
  fi
fi

git push origin "${DESTINATION_BRANCH}"
git remote rm tmp_upstream
git remote -v
