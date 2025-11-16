#!/bin/bash

export ORGANIZATION_NAME=SungjinPark0930
export REPO_NAME=sj-customer-api
export BRANCH_NAME=master
export OS_USER_NAME=akuserver

cd /git
rm -rf /git/$REPO_NAME

git clone https://github.com/$ORGANIZATION_NAME/$REPO_NAME.git

cd /git/$REPO_NAME
git switch $BRANCH_NAME

## Set certificates if needed
# cp /git/cert.pem /git/$REPO_NAME/cert.pem
# cp /git/key.pem /git/$REPO_NAME/key.pem

## GCP Project ID, Number Settings
cp /git/work/project_id /git/$REPO_NAME/project_id
cp /git/work/project_number /git/$REPO_NAME/project_number

chown $OS_USER_NAME:$OS_USER_NAME -R /git/$REPO_NAME
git branch

## Kill the existing process
ps -ef | grep cargo | awk -F " " '{ print $2 }' | xargs kill -9

## Start Application
cargo watch -x run
