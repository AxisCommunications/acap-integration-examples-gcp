*Copyright (C) 2021, Axis Communications AB, Lund, Sweden. All Rights Reserved.*

<!-- omit in toc -->
# Images to Google Cloud Storage

[![Build images-to-google-cloud-storage](https://github.com/AxisCommunications/acap-integration-examples-gcp/actions/workflows/images-to-google-cloud-storage.yml/badge.svg)](https://github.com/AxisCommunications/acap-integration-examples-gcp/actions/workflows/images-to-google-cloud-storage.yml)
![Ready for use in production](https://img.shields.io/badge/Ready%20for%20use%20in%20production-Yes-brightgreen)

This directory hosts the necessary code to follow the instructions detailed in [Send images to Google Cloud Storage](https://developer.axis.com/computer-vision/how-to-guides/send-images-to-google-cloud-storage) on Axis Developer Documentation.

## File structure

<!-- markdownlint-disable MD040 -->
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

## License

[Apache 2.0](./LICENSE)
