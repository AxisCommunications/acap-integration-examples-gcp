#!/bin/bash
set -e

if [[ $# -ne 3 ]]; then
  echo "Error: Unsupported number of arguments"
  echo
  echo "USAGE:"
  echo "    delete-cloud-resources.sh <project> <name> <location>"
  echo
  echo "WHERE:"
  echo "    project     The Google Cloud Project to deploy resources in"
  echo "    name        A name postfix appended to the name of created resources"
  echo "    location    The name of the Google location where the resources"
  echo "                should be created. Supported locations are"
  echo "                  - asia-northeast1"
  echo "                  - australia-southeast1"
  echo "                  - europe-west1"
  echo "                  - europe-west2"
  echo "                  - us-east1"
  echo "                  - us-east4"
  echo "                  - us-central1"
  echo "                  - us-west2"
  echo "                  - us-west3"
  echo "                  - us-west4"
  echo

  exit 1
fi

project=$1
name=$2
location=$3

if [ ${#name} -gt 12 ]; then
  echo "Length of 'name' input argument must not exceed 12 characters"
  exit 1
fi

if [[ ! $name =~ ^[a-z0-9\-]+$ ]]; then
  echo "'name' input argument should only contain lowercase alphanumeric characters and hyphens"
  exit 1
fi

valid_locations=(
  "asia-northeast1"
  "australia-southeast1"
  "europe-west1"
  "europe-west2"
  "us-east1"
  "us-east4"
  "us-central1"
  "us-west2"
  "us-west3"
  "us-west4"
)

if [[ ! " ${valid_locations[*]} " =~ [[:space:]]${location}[[:space:]] ]]; then
  echo "Invalid location [$location] specified. Use one of the following locations:"
  echo "  - asia-northeast1"
  echo "  - australia-southeast1"
  echo "  - europe-west1"
  echo "  - europe-west2"
  echo "  - us-east1"
  echo "  - us-east4"
  echo "  - us-central1"
  echo "  - us-west2"
  echo "  - us-west3"
  echo "  - us-west4"

  exit 1
fi

echo "Setting default GCP project to [$project]"
gcloud config set project "$project"
common_name=axis-image-upload-$name

existing_api_key=$(gcloud alpha services api-keys list \
  --filter="display_name=\"$common_name\"" \
  --format="value(name)")

if [ -n "$existing_api_key" ]; then
  echo "Deleting API key [$common_name]..."
  gcloud alpha services api-keys delete "$existing_api_key"
fi

gateway_name=projects/$project/locations/$location/gateways/$common_name
project_number=$(gcloud projects describe "$project" --format="value(projectNumber)")
config_id=axis-image-upload-config
config_name=projects/$project/locations/global/apis/$common_name/configs/$config_id
config_name_proj_number=projects/$project_number/locations/global/apis/$common_name/configs/$config_id

existing_api_gateway=$(gcloud api-gateway gateways list \
  --filter="name=\"$gateway_name\" AND apiConfig=\"$config_name_proj_number\"" \
  --format="value(name)")

if [ -n "$existing_api_gateway" ]; then
  echo "Deleting API Gateway [$gateway_name]..."
  gcloud api-gateway gateways delete "$existing_api_gateway" --location="$location" --quiet
fi

existing_api_config=$(gcloud api-gateway api-configs list \
  --filter="name=\"$config_name\"" \
  --format="value(name)")

if [ -n "$existing_api_config" ]; then
  echo "Deleting API Config [$config_id]..."
  gcloud api-gateway api-configs delete "$config_name" --quiet
fi

api_name=projects/$project/locations/global/apis/$common_name
existing_api=$(gcloud api-gateway apis list \
  --filter="name=\"$api_name\"" \
  --format="value(name)")

if [ -n "$existing_api" ]; then
  echo "Deleting API [$common_name]..."
  gcloud api-gateway apis delete "$common_name" --quiet
fi

function_name=projects/$project/locations/$location/functions/$common_name
existing_function=$(gcloud functions list \
  --filter="name='$function_name'" \
  --format="value(name)")

if [ -n "$existing_function" ]; then
  echo "Deleting function [$common_name]..."
  gcloud functions delete "$common_name" --region="$location" --quiet
fi

service_account_email=$common_name@$project.iam.gserviceaccount.com
existing_service_account=$(gcloud iam service-accounts list \
  --filter="email='$service_account_email'" \
  --format="value(email)")

if [ -n "$existing_service_account" ]; then
  echo "Deleting service account [$service_account_email]..."
  gcloud iam service-accounts delete "$service_account_email" --quiet
fi
