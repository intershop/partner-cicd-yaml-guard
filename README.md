# partner-cicd-yaml-guard

This repository provides reusable Azure DevOps YAML-linting pipeline templates and
validation scripts for partner repositories. Pipeline definitions and templates
are kept at the repository root; Azure DevOps pipeline support and check runners
are grouped under `.azure-devops/`.

## Repository layout

```text
.
├── .azure-devops/
│   ├── pr-validation.yml
│   ├── yaml-validation/
│   ├── kubeconform-validation/
│   ├── kustomize-validation/
│   └── haproxy-validation/
├── azure-pipelines.yml.tmpl
├── lint-yaml-template.yml
├── LICENSE
└── README.md
```

Each validation directory contains a `run.sh` entry point and any check-specific
configuration. The PR-validation template invokes each check as a separate
Azure Pipelines task. See [`.azure-devops/README.md`](.azure-devops/README.md)
for check behavior, options, and local commands.

## Reusable YAML lint pipeline

`lint-yaml-template.yml` is a reusable job template for YAML linting and custom
validation. `azure-pipelines.yml.tmpl` is an example consumer pipeline. Adapt
its repository names, branch, target folder, and agent-pool settings to your
Azure DevOps project before using it.

The example expects an `environments` repository resource and the
`yamlinter-variables` variable group to be available in the consuming project.
The linter image also needs to provide the custom validation script referenced
by the template.

## Running this repository's PR validations

To run the repository checks from an Azure Pipeline, include the PR-validation
template in a job:

```yaml
jobs:
  - job: validation
    steps:
      - template: .azure-devops/pr-validation.yml
        parameters:
          dockerHubServiceConnection: dockerhub-public-image-pull
```

Configure the pipeline as a required build-validation policy on the relevant
Azure Repos branches. The service connection must exist in the Azure DevOps
project and have permission to pull the validation image.

## Running checks locally

The validation scripts require Bash and Docker. From the repository root, run
the checks individually:

```bash
bash .azure-devops/yaml-validation/run.sh
bash .azure-devops/kubeconform-validation/run.sh
bash .azure-devops/kustomize-validation/run.sh
bash .azure-devops/haproxy-validation/run.sh
```

Each runner accepts `--help` to show its options. By default, YAML,
kubeconform, and kustomize checks inspect `clusters/`; HAProxy validation
inspects the repository root.
