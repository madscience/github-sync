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
echo "EXCLUDED_FILES=$EXCLUDED_FILES"

# GitHub actions v2 no longer auto set GITHUB_TOKEN
echo "Setting URL for origin remote to: https://$GITHUB_ACTOR:$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY"
git remote set-url origin "https://$GITHUB_ACTOR:$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY"

echo "Adding tmp_upstream remote with URL: $UPSTREAM_REPO"
git remote add tmp_upstream "$UPSTREAM_REPO"

echo "Listing remotes:"
git remote -v

echo "Fetching from tmp_upstream remote..."
git fetch tmp_upstream

echo "Setting commit author..."
git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"
git config --global user.name "github-sync"

echo "Checking if branch ${DESTINATION_BRANCH} already exists on origin..."
if git ls-remote --exit-code --heads origin "${DESTINATION_BRANCH}"; then
  echo "refs/remotes/origin/${DESTINATION_BRANCH} exists. Checking out as ${DESTINATION_BRANCH}..."
  # When the destination branch already exists, switch to it and merge in the source branch
  git checkout -b "${DESTINATION_BRANCH}" "refs/remotes/origin/${DESTINATION_BRANCH}"

  echo "Merging changes from refs/remotes/tmp_upstream/${SOURCE_BRANCH}..."
  git merge --commit --no-edit --ff "refs/remotes/tmp_upstream/${SOURCE_BRANCH}"
  # TODO: handle merge conflicts
else
  echo "No existing branch. Checking out refs/remotes/tmp_upstream/${SOURCE_BRANCH} as ${DESTINATION_BRANCH}"
  # When the destination does not exist yet, checkout the source branch as destination
  git checkout -b "${DESTINATION_BRANCH}" "refs/remotes/tmp_upstream/${SOURCE_BRANCH}"
fi

if [[ ! -z "$EXCLUDED_FILES" ]]; then
  echo "Reverting changes to excluded files: ${EXCLUDED_FILES}"
  git reset origin/master -- "${EXCLUDED_FILES}"

  if output=$(git status --porcelain) && [[ ! -z "$output" ]]; then
    echo "Committing changes..."
    git commit --message="Revert changes to excluded files"

    echo "Cleaning work tree..."
    git clean -f
  fi
fi

echo "Pushing ${DESTINATION_BRANCH} to origin..."
git push origin "${DESTINATION_BRANCH}"

echo "Removing tmp_upstream remote..."
git remote rm tmp_upstream
git remote -v

echo "Done."
