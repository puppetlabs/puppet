#! /usr/bin/env bash

set -e
set -x

JOB_NAME=$1
[[ (-z "$JOB_NAME") ]] && echo "No job name passed in" && exit 1

rake --trace package:implode
rake --trace package:bootstrap

# This obtains either the sha or tag if the commit is tagged
REF=`rake pl:print_build_params |grep "^ref: " |cut -d ":" -f 2 | tr -d ' '`
rake --trace pl:jenkins:uber_build DOWNSTREAM_JOB="http://jenkins-foss.delivery.puppetlabs.net/job/$JOB_NAME/buildWithParameters?token=iheartjenkins&SHA=$REF&BUILD_SELECTOR=$BUILD_NUMBER&FORK=$GIT_FORK"

rake ci:acceptance_artifacts SHA=$REF
