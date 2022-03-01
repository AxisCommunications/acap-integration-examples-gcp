#!/bin/bash
set -e

if [[ $# -ne 3 ]]; then
  echo "Error: Unsupported number of arguments"
  echo
  echo "USAGE:"
  echo "    create-cloud-resources.sh <project> <name> <location>"
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

echo "Checking if bucket [$common_name] exists, otherwise creating it..."
gsutil ls -b gs://"$common_name" || gsutil mb -l "$location" gs://"$common_name"

service_account_email=$common_name@$project.iam.gserviceaccount.com
echo "Checking if service account [$service_account_email] exists..."

existing_service_account=$(gcloud iam service-accounts list \
  --filter="email='$service_account_email'" \
  --format="value(email)")

if [ -z "$existing_service_account" ]; then
  echo "Service account [$service_account_email] does not exist, creating it..."
  gcloud iam service-accounts create "$common_name" \
    --description="Service account for Axis image upload" \
    --display-name="$common_name"
fi

echo "Deploying Cloud Function [$common_name]..."
gcloud functions deploy "$common_name" \
  --region="$location" \
  --runtime=nodejs14 \
  --trigger-http \
  --source=./src \
  --entry-point=handler \
  --security-level=secure-always \
  --set-env-vars=BUCKET_NAME="$common_name" \
  --quiet

echo "Give service account [$service_account_email] objectCreator role on bucket [gs://$common_name]"
gsutil iam ch serviceAccount:"$service_account_email":objectCreator gs://"$common_name"

echo "Give service account [$service_account_email] cloudfunctions.invoker role on Cloud Function [$common_name]"
gcloud functions add-iam-policy-binding "$common_name" \
  --region="$location" \
  --member=serviceAccount:"$service_account_email" \
  --role="roles/cloudfunctions.invoker"

echo "Creating OpenAPI document for the API Gateway deployment..."
function_url=$(gcloud functions describe "$common_name" --region "$location" --format="value(httpsTrigger.url)")
openapi_spec=openapi-$common_name.yaml
sed "s,CLOUD_FUNCTION_URL,$function_url,g" openapi.yaml >"$openapi_spec"

echo "Checking if API [$common_name] exists..."
api_name=projects/$project/locations/global/apis/$common_name
existing_api=$(gcloud api-gateway apis list \
  --filter="name=\"$api_name\"" \
  --format="value(name)")

if [ -z "$existing_api" ]; then
  echo "API [$common_name] does not exist, creating it..."
  gcloud api-gateway apis create "$common_name"
fi

config_id=axis-image-upload-config
config_name=projects/$project/locations/global/apis/$common_name/configs/$config_id
echo "Checking if API Config [$config_id] exists in API [$common_name]..."
existing_api_config=$(gcloud api-gateway api-configs list \
  --filter="name=\"$config_name\"" \
  --format="value(name)")

if [ -z "$existing_api_config" ]; then
  echo "API Config [$config_id] does not exist in API [$common_name], creating it..."
  gcloud api-gateway api-configs create "$config_id" \
    --api="$common_name" \
    --openapi-spec="$openapi_spec" \
    --backend-auth-service-account="$service_account_email"
fi

gateway_name=projects/$project/locations/$location/gateways/$common_name
project_number=$(gcloud projects describe "$project" --format="value(projectNumber)")
config_name=projects/$project_number/locations/global/apis/$common_name/configs/$config_id

echo "Checking if API Gateway [$common_name] exists in $location..."
existing_api_gateway=$(gcloud api-gateway gateways list \
  --filter="name=\"$gateway_name\" AND apiConfig=\"$config_name\"" \
  --format="value(name)")

if [ -z "$existing_api_gateway" ]; then
  echo "API Gateway [$common_name] does not exist, creating it..."
  gcloud api-gateway gateways create "$common_name" \
    --api="$common_name" \
    --api-config="$config_id" \
    --location="$location"
fi

hostname=$(gcloud api-gateway gateways describe "$common_name" \
  --location "$location" \
  --format="value(defaultHostname)")

managed_service=$(gcloud api-gateway apis describe "$common_name" \
  --format="value(managedService)")
echo "Enabling API-key usage for service [$managed_service]"
gcloud services enable "$managed_service"

echo "Checking if API key [$common_name] exists..."
existing_api_key=$(gcloud alpha services api-keys list \
  --filter="display_name=\"$common_name\"" \
  --format="value(display_name)")

if [ -z "$existing_api_key" ]; then
  echo "API key [$common_name] does not exist, creating it..."
  gcloud alpha services api-keys create \
    --display-name="$common_name" \
    --api-target=service="$managed_service"
fi

api_key_name=$(gcloud alpha services api-keys list \
  --filter="display_name='$common_name'" --format="value(name)")

api_key_value=$(gcloud alpha services api-keys get-key-string "$api_key_name" \
  --format="value(keyString)")

echo "Done."
echo
echo "Use the following parameters when setting up your Axis camera to send images to Google Cloud Storage."
echo
echo "API Gateway URL:    https://$hostname"
echo "API key:            $api_key_value"
echo
echo "Images will be stored in https://console.cloud.google.com/storage/browser/$common_name"
