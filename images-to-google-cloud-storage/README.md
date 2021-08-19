_Copyright (C) 2021, Axis Communications AB, Lund, Sweden. All Rights Reserved._

# Images to Google Cloud Storage

[![Build images-to-google-cloud-storage](https://github.com/AxisCommunications/acap-integration-examples-gcp/actions/workflows/images-to-google-cloud-storage.yml/badge.svg)](https://github.com/AxisCommunications/acap-integration-examples-gcp/actions/workflows/images-to-google-cloud-storage.yml)

## Table of contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [File structure](#file-structure)
- [Instructions](#instructions)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Overview

In this example we create an application that sends images from an Axis camera to Google Cloud Storage. We start by deploying the infrastructure in the cloud, and then continue with configuring the camera.

![architecture](./assets/architecture.png)

The application consists of the following GCP resources.

- API Gateway
- Cloud Function
- Service account
- Cloud Storage bucket

The camera sends images to the Cloud Function via the API Gateway. Requests are authorized using an API-key provided to the camera. The Cloud Function uploads the image to a bucket in Cloud Storage. Authorization between resources in GCP is handled using a service account.

## Prerequisites

- A network camera from Axis Communications (example has been verified to work on a single channel camera with firmware version >=9.80.3)
- Google Cloud SDK (specifically the gcloud and gsutil tools) ([install](https://cloud.google.com/sdk/docs/install))
- A GCP project linked to a billing account

## File structure

```
images-to-google-cloud-storage
├── src
│   ├── env.js - Exports environment variables
│   ├── index.js - Exports the function handler
│   ├── package-lock.json - npm package lock file
│   └── package.json - npm package
├── create-cloud-resources.sh - Bash script to create GCP resources
├── delete-cloud-resources.sh - Bash script to delete GCP resources
└── openapi.yaml - OpenAPI specification template
```

## Instructions

The instructions are divided into two parts. The first part covers deploying the GCP resources and the second part covers configuring the camera.

To start of, make sure to clone the repository and navigate into the example directory.

```bash
git clone https://github.com/AxisCommunications/acap-integration-examples-gcp.git
cd acap-integration-examples-gcp/images-to-google-cloud-storage
```

### Deploying the GCP resources

Let's deploy the GCP resources required to receive images sent from a camera. All resources are created using the bash script `create-cloud-resources.sh`. Before you run the script, enable the required GCP resources for your GCP project.

```bash
gcloud services enable \
  apigateway.googleapis.com \
  servicemanagement.googleapis.com \
  servicecontrol.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  storage.googleapis.com
```

In order to programmatically create API-keys via the gcloud command line tool we must install the alpha component using the following command.

```bash
gcloud components install alpha
```

The `create-cloud-resources.sh` script should be called with the following positional arguments.

1. `project` - The name of the GCP project where all resources should be created.
2. `name` - A name postfix that will be attached to relevant resource names to avoid naming conflicts.
3. `location` - The GCP location where resources will be created. A subset of available locations are supported due to restrictions imposed by some of the GCP resources. Use one of: `asia-northeast1`, `australia-southeast1`, `europe-west1`, `europe-west2`, `us-east1`, `us-east4`, `us-central1`, `us-west2`, `us-west3`, `us-west4`.

The example output below indicates that the resources have been created successfully. The script runs a number of gcloud commands to check the existence of previously deployed resources, but if no resources are found a warning is output to the console. These warnings are expected and do not indicate a problem with the script.

```
$ ./create-cloud-resources.sh my-gcp-project xyz us-east1
> Setting default GCP project to [my-gcp-project]
> Updated property [core/project].
> Checking if bucket [axis-image-upload-xyz] exists, otherwise creating it...
> BucketNotFoundException: 404 gs://axis-image-upload-xyz bucket does not exist.
> Creating gs://axis-image-upload-xyz/...
> Checking if service account [axis-image-upload-xyz@my-gcp-project.iam.gserviceaccount.com] exists...
> Service account [axis-image-upload-xyz@my-gcp-project.iam.gserviceaccount.com] does not exist, creating it...
> Created service account [axis-image-upload-xyz].
> Deploying Cloud Function [axis-image-upload-xyz]...
> WARNING: Function created with limited-access IAM policy (shortened for brevity)...
> Deploying function (may take a while - up to 2 minutes)...⠹
> For Cloud Build Logs, visit: https://console.cloud.google.com/cloud-build/builds;region=us-east1/...
> Deploying function (may take a while - up to 2 minutes)...done.
> (function details omitted for brevity)
> Give service account [axis-image-upload-xyz@my-gcp-project.iam.gserviceaccount.com] objectCreator role on bucket [gs://axis-image-upload-xyz]
> Give service account [axis-image-upload-xyz@my-gcp-project.iam.gserviceaccount.com] cloudfunctions.invoker role on Cloud Function [axis-image-upload-xyz]
> (role assignment details omitted for brevity)
> Creating OpenAPI document for the API Gateway deployment...
> Checking if API [axis-image-upload-xyz] exists...
> WARNING: The following filter keys were not present in any resource : name
> API [axis-image-upload-xyz] does not exist, creating it...
> Waiting for API [axis-image-upload-xyz] to be created...done.
> Checking if API Config [axis-image-upload-config] exists in API [axis-image-upload-xyz]...
> WARNING: The following filter keys were not present in any resource : name
> API Config [axis-image-upload-config] does not exist in API [axis-image-upload-xyz], creating it...
> Waiting for API Config [axis-image-upload-config] to be created for API [axis-image-upload-xyz]...done.
> Checking if API Gateway [axis-image-upload-xyz] exists in us-east1...
> WARNING: The following filter keys were not present in any resource : apiConfig, name
> API Gateway [axis-image-upload-xyz] does not exist, creating it...
> Waiting for API Gateway [axis-image-upload-xyz] to be created with [projects/my-gcp-project/locations/global/apis/axis-image-upload-xyz/configs/axis-image-upload-config] config...done.
> Enabling API-key usage for service [axis-image-upload-xyz-<random id>.apigateway.my-gcp-project.cloud.goog]
> Operation "operations/<guid>" finished successfully.
> Checking if API key [axis-image-upload-xyz] exists...
> API key [axis-image-upload-xyz] does not exist, creating it...
> (api key details omitted for brevity)

> Done.

> Use the following parameters when setting up your Axis camera to send images to Google Cloud Storage.

> API Gateway URL:    https://axis-image-upload-xyz-<random id>.gateway.dev
> API key:            <api key value>

> Images will be stored in https://console.cloud.google.com/storage/browser/axis-image-upload-xyz"
```

### Configuring the camera

Now that the resources in GCP are ready to accept images, let's continue with configuring the camera to send them.

Navigate to the camera using your preferred web browser. In the user interface of the camera, select _Settings_ -> _System_ -> _Events_ -> _Device events_. In this user interface we'll do all configuration, but first let's get an overview of the available tabs.

- **Rules** - Here we'll create a rule that sends images to Google Cloud Storage
- **Schedules** - In this sample we'll use a schedule to define _when_ an image should be sent. If a schedule doesn't fit your specific use case, you can replace it with any event generated on the camera or even an event generated by any ACAP installed on the camera.
- **Recipients** - Here we'll define _where_ images are sent

Let's start with _Recipients_. Select the tab and create a new recipient with the following settings.

- **Name**: `Google Cloud Storage`
- **Type**: `HTTPS`
- **URL**: Back when we deployed the GCP resources we ended up with two output values, the first was the API Gateway URL. Enter that value here.

Click the _Save_ button.

Now let's navigate to the _Schedules_ tab. In this sample we'll use a schedule to define when an image should be send. Create a new schedule with the following settings.

- **Type**: `Pulse`
- **Name**: `Every minute`
- **Repeat every**: `1 Minute`

Click the _Save_ button.

Now let's navigate to the _Rules_ tab. Here we'll finally create a rule that combines the recipient and the schedule into a rule. Create a new rule with the following settings.

- **Name**: `Images to Google Cloud Storage`
- **Condition**: `Pulse`
  - **Pulse**: `Every Minute`
- **Action**: `Send images through HTTPS`
  - **Recipient**: `Google Cloud Storage`
  - **Maximum images**: `1`
  - **Custom CGI parameters**: Back when we deployed the GCP resources we ended up with two output values, the second value was the API key. Enter the following value in this field: `key=<api key value>`, replace `<api key value>` with the value of your API key.

Click the _Save_ button.

At this point the rule will become active and send an image to Google Cloud Storage every minute.

## Cleanup

To delete resources from this example, run the script `delete-cloud-resources.sh`. This script will delete all resources except the storage bucket where all uploaded images are stored. Run the script using the same input parameters you used for the `create-cloud-resources.sh` script.

```
$ ./delete-cloud-resources.sh my-gcp-project xyz us-east1
> Setting default GCP project to [my-gcp-project]
> Updated property [core/project].
> Deleting API key [axis-image-upload-xyz]...
> Operation "operations/<random id>" finished successfully.
> Deleting API Gateway [projects/my-gcp-project/locations/us-east1/gateways/axis-image-upload-xyz]...
> Waiting for API Gateway [axis-image-upload-xyz] to be deleted...done.
> Deleting API Config [axis-image-upload-config]...
> Waiting for API Config [axis-image-upload-config] to be deleted...done.
> Deleting API [axis-image-upload-xyz]...
> Waiting for API [axis-image-upload-xyz] to be deleted...done.
> Deleting function [axis-image-upload-xyz]...
> Waiting for operation to finish...done.
> Deleted [projects/my-gcp-project/locations/us-east1/functions/axis-image-upload-xyz].
> Deleting service account [axis-image-upload-xyz@my-gcp-project.iam.gserviceaccount.com]...
> deleted service account [axis-image-upload-xyz@my-gcp-project.iam.gserviceaccount.com]
```

## Troubleshooting

This section will highlight some of the common problems one might encounter when running this example application.

### No images are sent to Google Cloud Storage

If the camera is unable to successfully send images to Google Cloud Storage, please make sure that the following statements are true.

- **The camera is not behind a proxy**. This example does not support a network topology where requests needs to traverse a proxy to reach the internet.

## License

[Apache 2.0](./LICENSE)