#!/bin/bash

export REPO_NAME=sj-customer-api
export BRANCH_NAME=master

cd /git/$REPO_NAME

git config --global user.name "Sungjin Park"
# git config --global user.email ""

echo ""
echo "==== Change List ===="
git status

echo ""
echo "==== Input the comments ===="
read COMMIT_COMMENTS

echo ""
echo "==== Add files ===="
git add -A

echo ""
echo "==== Check the username ===="
git config --global --list | grep user.name

echo ""
echo "==== Commit ===="
git commit -a -m "$COMMIT_COMMENTS"

echo ""
echo "==== Rebase ===="
git pull --rebase origin $BRANCH_NAME
git rebase --continue

echo ""
echo "==== Push ===="
git push origin $BRANCH_NAME

echo ""
echo "Please run again after clean-up the code conflicts."
