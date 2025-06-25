# yaml-lint-pipeline-template

## Overview

This repository provides an Azure DevOps pipeline template for YAML linting. It enables teams to validate YAML syntax and perform custom checks (e.g., `kustomize` validation) using a Docker-based linter image. The pipeline is designed to be reusable and configurable with minimal parameters, supporting both internal and external repositories.

Use this template **as-is**. Any custom behavior should be implemented externally and injected via parameters.

---

## How to Use the Pipeline Template

To use this pipeline in your project, create a `azure-pipelines.yml` file at the root of your repository with the following content:

```yaml
# azure-pipelines.yml

trigger:
  branches:
    include:
      - main

resources:
  repositories:
    - repository: yaml-lint-pipeline-template
      type: git
      name: <project-name>/yaml-lint-pipeline-template
      ref: refs/heads/main

stages:
- stage: Lint
  displayName: "YAML Lint Check"
  jobs:
    - template: lint-yaml-template.yml@yaml-lint-pipeline-template
      parameters:
        agentPool: '<YourAgentPool>'
        targetFolder: 'environments'
        dockerhubLogin: true
        dockerhubServiceConnection: '<YourDockerHubServiceConnection>'
        yamlinterImage: 'intershophub/yaml-guard'
        yamlinterImageTag: 'latest'
```

After committing this file, create a pipeline in Azure DevOps using this YAML file.

---

## Parameters

| Parameter Name               | Description                                                                     | Default Value                                | Required |
|------------------------------|---------------------------------------------------------------------------------|----------------------------------------------|----------|
| `agentPool`                  | Name of the agent pool to run the pipeline.                                     | `''`                                         | ✅       |
| `yamlinterImage`             | Docker image used for YAML linting.                                             | `'intershophub/yaml-guard'`                  | ✅       |
| `yamlinterImageTag`          | Tag for the YAML linter Docker image (e.g., `latest`, `v1.2.0`).                | `'latest'`                                   | ✅       |
| `targetFolder`               | Path inside the repository where YAML files are located.                        | `'.'`                                        | ✅       |
| `dockerhubLogin`             | Whether to perform DockerHub login before pulling the linter image.             | `false`                                      | ❌       |
| `dockerhubServiceConnection` | DockerHub service connection name used for login (if `dockerhubLogin` is true). | `'$(DOCKERHUB_PUBLIC_SERVICE_CONNECTION)'`   | 🔁       |

**Note:** Parameters marked with ✅ are required. 🔁 is only required when `dockerhubLogin` is `true`.

---

## Linter Behavior

The pipeline:

1. Validates the required parameters.
2. Pulls the Docker image (`yamlinterImage`) from DockerHub.
3. Lints all `.yaml` and `.yml` files under `targetFolder` using the image's internal configuration.
4. Optionally, runs a custom validation script (e.g., `validate_kustomize.sh`) if the image supports it.

---

## Important Information

- Always use tagged versions or a stable branch (`main`) for this template to avoid unexpected changes.
- The template assumes the presence of a repository named `environments` which is checked out under `externals/environments`. Update this behavior as needed if your folder structure differs.
- The `validate_kustomize.sh` script must exist within the Docker image at `/usr/local/bin`.
