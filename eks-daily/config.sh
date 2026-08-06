#!/usr/bin/env bash

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"

export CLUSTER_NAME="${CLUSTER_NAME:-roboshop-dev}"
export NODEGROUP_NAME="${NODEGROUP_NAME:-roboshop-dev-ng}"

export DESIRED_NODES="${DESIRED_NODES:-2}"
export MAX_NODES="${MAX_NODES:-2}"
export NODE_TYPE="${NODE_TYPE:-t3.medium}"

export LAB_NAMESPACE="${LAB_NAMESPACE:-daily-lab}"
