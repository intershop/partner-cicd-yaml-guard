# partner-cicd-yaml-guard PR Validation

This folder contains the pull request validation process for this repository and its partner-repository checks. Azure Repos runs `.azure-devops/pr-validation.yml` as a required build validation. Each check runs as a separate pipeline task.

## Checks

### YAML Validation

Uses `yamllint` to check YAML files in the test folder with the template's repository configuration. By default, the runner checks `clusters/` in the Azure Pipelines self repository checkout, or `clusters/` under the current working directory when run locally. The runner mounts the folder and configuration read-only in the tool image. Lint errors and warnings fail the check.

Run locally from the repository root with Docker installed and running:

```bash
bash .azure-devops/yaml-validation/run.sh
```

The script accepts these optional parameters:

- `--image IMAGE`: Docker image; defaults to `intershophub/yaml-guard:<TAG>` (or `YAML_GUARD_IMAGE` if set).
- `--test-folder FOLDER`: folder containing the YAML files to check; defaults to `clusters/` in the Azure Pipelines self repository checkout (or the current working directory when run locally).
- `--config FILE`: yamllint configuration; defaults to `tasks/yaml-validation/.yamllint-intershop-default`.

Directory and file paths can be absolute or relative to the current working directory. The PR-validation template passes the configured `testFolder` under the self-repository checkout and uses the lint configuration shipped with this template.

### kubeconform Validation

Builds every Kustomization under the test folder and validates the rendered manifests with `kubeconform` in the tool image. By default, the test folder is `clusters/` in the Azure Pipelines self repository checkout, or `clusters/` under the current working directory when run locally. Intentionally parked Kustomizations with no active resources are skipped; all other build and schema errors are reported before the check exits.

Run locally from the repository root with Docker installed and running:

```bash
bash .azure-devops/kubeconform-validation/run.sh
```

The script accepts `--image IMAGE` and `--test-folder FOLDER`. The image defaults to `intershophub/yaml-guard:1.0.0` (or `YAML_GUARD_IMAGE` if set). Set `KUBECONFORM_SCHEMA_LOCATION` to add an extra kubeconform schema location for custom resources. All validation runners also accept an explicit folder path when the target is in a different checkout.

### Kustomize Validation

Runs `kustomize build` for every Kustomization under the test folder. Intentionally parked Kustomizations with no active resources are skipped; other failures are all reported before the check exits. By default, the test folder is `clusters/` in the Azure Pipelines self repository checkout, or `clusters/` under the current working directory when run locally.

Run locally from the repository root with Docker installed and running:

```bash
bash .azure-devops/kustomize-validation/run.sh
```

The script accepts `--image IMAGE` and `--test-folder FOLDER`. The image defaults to `intershophub/yaml-guard:1.0.0` (or `YAML_GUARD_IMAGE` if set).

### HAProxy Validation

Runs Python-based HAProxy allowlist, `haproxy-aux.cfg` userlist, and `.cfg` final-newline checks inside Docker. The image needs Python 3, but not HAProxy. By default, the check folder is the Azure Pipelines self repository checkout, or the current working directory when run locally. IP allowlists are `**/acls/ip*.txt`, `clusters/global-acls/ip*.txt`, and `clusters/global-acls/global-block-list.txt`; each address must be a valid IPv4 address with an optional `/0`-`/32` subnet. Non-empty lines must not have leading or trailing whitespace; comments must start with `# ` (or be a bare `#`) in column 1.

A `haproxy-aux.cfg` may be empty; when it contains userlist blocks, each block must have `userlist <name>`, then `group authenticated-users`, then at least one `user <username> password <passwordhash> groups authenticated-users` line. Passwords must use bcrypt (`$2a$`, `$2b$`, or `$2y$`), SHA-256 crypt (`$5$`), or SHA-512 crypt (`$6$`) hash format. Comments must start with `# ` (or be a bare `#`) in column 1; blank lines are allowed. Non-empty files must end with a line break. Other non-empty `.cfg` files must also end with a newline. This check does not run `haproxy -c` or validate general HAProxy directives.

Output lists the files checked under IP allowlists, `haproxy-aux.cfg`, and other `.cfg` headings, without marking individual files valid. Auxiliary configs also receive the `.cfg` final-newline check. Validation errors appear at the bottom of this output and fail the check.

Run locally from the repository root with Docker installed and running:

```bash
bash .azure-devops/haproxy-validation/run.sh
```

Docker is required.

The script accepts these optional parameters:

- `--image IMAGE`: Python 3 Docker image; defaults to `intershophub/yaml-guard:1.0.0` (or `HAPROXY_VALIDATION_IMAGE` if set).
- `--test-folder FOLDER`: folder to check; defaults to the Azure Pipelines self repository checkout (or the current working directory when run locally).

## Adding checks

Give each check its own directory under `.azure-devops/`, containing its configuration and a single `run.sh` entry point. The runner should mount required repository inputs into its tool image and invoke the check directly. Add a separate `Bash@3` task to `pr-validation.yml` that runs the script. Document each check here with a short description and its local command. Add future checks as separate subsections under **Checks**.
