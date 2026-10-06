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

To run the checks from an Azure Pipeline, declare the template repository as a
repository resource and include the PR-validation template from a job. The
template checks out both the consuming repository (`self`) and the template
repository:

```yaml
resources:
  repositories:
    - repository: partner-cicd-yaml-guard
      type: git
      name: YourProject/partner-cicd-yaml-guard
      ref: refs/heads/main

jobs:
  - job: validation
    steps:
      - template: pr-validation.yml@partner-cicd-yaml-guard
        parameters:
          dockerHubServiceConnection: dockerhub-public-image-pull
          enableDockerLogin: true
          templateRepository: partner-cicd-yaml-guard
          templateRepositoryFolder: partner-cicd-yaml-guard
          testFolder: /clusters
          enableYamlValidation: true
          enableKubeconformValidation: true
          enableKustomizeValidation: true
          enableHaproxyValidation: true
```

All validation switches default to `true`. Set `enableDockerLogin` to `false`
to skip both Docker login and logout (for example, when the image is public).
`templateRepository` is the repository resource alias containing the validation
scripts; use `self` if those scripts are in the consuming repository.
`templateRepositoryFolder` is the directory under `$(Pipeline.Workspace)/s`
where the scripts are checked out. `testFolder` is appended to the self-repository
checkout directory and defaults to `/clusters`. The Docker service connection
is only used when Docker login is enabled.

Configure the pipeline as a required build-validation policy on the relevant
Azure Repos branches. When Docker login is enabled, the service connection must
exist in the Azure DevOps project and have permission to pull the validation
image.

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
