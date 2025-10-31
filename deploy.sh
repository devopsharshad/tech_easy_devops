#!/bin/bash
# Usage: ./deploy.sh dev  OR  ./deploy.sh prod

if [ -z "$1" ]; then
  echo "❌ Please specify environment: dev or prod"
  exit 1
fi

ENV=$1

if [ "$ENV" = "dev" ]; then
  VAR_FILE="Config/dev.tfvars"
elif [ "$ENV" = "prod" ]; then
  VAR_FILE="Config/prod.tfvars"
else
  echo "❌ Invalid environment. Use 'dev' or 'prod'."
  exit 1
fi

echo "🚀 Deploying $ENV environment using $VAR_FILE ..."
terraform init -reconfigure
terraform apply -var-file="$VAR_FILE" -auto-approve