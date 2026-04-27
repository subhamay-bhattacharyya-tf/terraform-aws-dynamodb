# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this module does

This is a **Terraform module** that creates and manages AWS DynamoDB tables and their associated auto-scaling targets and policies as two independent submodules:

- `modules/dynamodb-table/` — creates `aws_dynamodb_table` resources (no inline auto-scaling)
- `modules/dynamodb-autoscaling/` — creates `aws_appautoscaling_target` and `aws_appautoscaling_policy` resources

Both submodules accept a single map-based input (`tables` and `autoscaling` respectively) and expose maps of resource attributes as outputs. The split-module design avoids circular dependencies when auto-scaling targets reference table and GSI capacity, and prevents drift from inline auto-scaling configuration on the table resource.

## Common commands

```bash
# Format check (must pass before commit)
terraform fmt -check -recursive

# Validate both submodules
cd modules/dynamodb-table && terraform init -backend=false && terraform validate
cd modules/dynamodb-autoscaling && terraform init -backend=false && terraform validate

# Validate examples
cd examples/basic && terraform init -backend=false && terraform validate
cd examples/provisioned-with-autoscaling && terraform init -backend=false && terraform validate

# Run Terratest integration test (requires AWS auth + AWS_REGION env var)
cd test && go test -v -timeout 30m -run TestDynamoDBTableBasic ./dynamodb_table_basic_test.go ./helpers_test.go

# Install local dev tools (Linux/devcontainer only)
bash install-tools.sh
bash install-tools.sh --tools=terraform,tflint,trivy  # install subset
bash install-tools.sh --dry-run                        # preview only

# Run pre-commit hooks
pre-commit run --all-files
```

## Architecture

```text
.
├── modules/
│   ├── dynamodb-table/              # Creates aws_dynamodb_table
│   │   ├── main.tf
│   │   ├── variables.tf             # tables map variable with validations
│   │   ├── outputs.tf               # Maps of id, arn, name, stream_arn, gsi_names
│   │   └── versions.tf
│   └── dynamodb-autoscaling/        # Creates appautoscaling target + policy resources
│       ├── main.tf
│       ├── variables.tf             # autoscaling map variable with validations
│       ├── outputs.tf               # Maps of scalable target id, policy arn, policy name
│       └── versions.tf
├── examples/
│   ├── basic/                       # Single on-demand table with GSIs and TTL
│   └── provisioned-with-autoscaling/ # Provisioned table with auto-scaling on table + GSI
└── test/
    ├── dynamodb_table_basic_test.go # Terratest: creates real tables + scaling, asserts outputs, destroys
    └── helpers_test.go              # Shared test helpers
```

## Key Conventions

- Each submodule uses the standard Terraform layout (main.tf, variables.tf, outputs.tf, versions.tf)
- GitHub Actions uses OIDC — no stored AWS access keys
- All infrastructure changes go through Terraform — never modify AWS resources manually
- Both submodules accept a single `map(object({...}))` input, consumed via `for_each`
- The map key is a logical Terraform identifier; the actual AWS resource name is a field inside the object
- Inline auto-scaling configuration on `aws_dynamodb_table` is intentionally avoided — auto-scaling targets and policies are always separate resources to prevent drift
- `package.json` and `package-lock.json` must always have their `name` field set to the current repository name (`terraform-aws-dynamodb`)
- `CONTRIBUTING.md` must always reference the current repository (`terraform-aws-dynamodb`), including the **Reporting Issues** section which must link to this repository's issues page
- `README.md` must always reflect the current repository (`terraform-aws-dynamodb`) and the AWS service this module provisions (DynamoDB tables and their auto-scaling configuration). Every surface that carries the repo name or service name must be kept in sync — specifically:
  - Title (`# Terraform AWS DynamoDB Module`) and the one-line description below it
  - All shields.io badges that interpolate the repo slug (`subhamay-bhattacharyya-tf/terraform-aws-dynamodb`) — leftover slugs from the upstream template (e.g. `terraform-aws-s3`) must be swapped
  - The shields.io custom-endpoint badge, which points to a gist-hosted JSON file named `<repo-name>.json` — e.g. `https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/bsubhamay/<gist-id>/raw/terraform-aws-dynamodb.json`. If the `<repo-name>.json` file does not exist in a gist yet, create a new secret gist (e.g. `gh gist create <file> --desc "<repo-name>.json"`) and update the badge URL; any leftover reference to a prior template's JSON file (e.g. `terraform-aws-s3.json`) must be replaced
  - The **Modules** table — entries must list the submodules that actually exist under `modules/` (`dynamodb-table`, `dynamodb-autoscaling`)
  - All **Usage** HCL snippets — `source = "github.com/subhamay-bhattacharyya-tf/terraform-aws-dynamodb/modules/<name>?ref=main"` must match the current repo and submodule names; example inputs must use this module's variable shapes (`tables`, `autoscaling`), not leftover template shapes (`s3_config`, `sqs_notifications`, etc.)
  - The **Examples** table — entries must match the directories under `examples/` (`basic`, `provisioned-with-autoscaling`)
  - Submodule **Inputs** / **Outputs** / **Resources Created** tables — must match the fields declared in each submodule's `variables.tf` / `outputs.tf` and the resources in each `main.tf`
  - **Validation**, **Testing**, and **CI/CD** sections — test commands, CI job names, and required secrets/variables (`AWS_ROLE_ARN`, `AWS_REGION`, `AWS_KMS_KEY_ARN`) must reference DynamoDB tables, not leftover services
  - **All GFM tables in `README.md` must be pipe-aligned (markdownlint rule MD060, `table-column-style: aligned`).** After any edit that adds or changes a table, re-align every table so the `|` characters line up vertically across the header, the separator row, and all body rows. Either hand-pad cells with spaces, or re-run the Python auto-aligner that pads each cell to the max width of its column — whichever is faster. Do not leave mixed-width tables behind; MD060 will flag them in the IDE. A quick structural check: every row of a given table must have its `|` characters at the same string-column positions (this can be verified by scripting `[k for k,c in enumerate(row) if c=='|']` and asserting the list is identical for every row in the table)
  - **Every heading in `README.md` must be unique across the whole document (markdownlint rule MD024, `no-duplicate-heading`), regardless of heading level.** This repo's structure naturally produces collisions — both submodules want `### Inputs` / `### Outputs`, and the "Resources Created" section wants ``### `dynamodb-table` submodule`` / ``### `dynamodb-autoscaling` submodule`` that duplicate the H2 section titles. Disambiguate by scoping every otherwise-duplicate heading with its submodule name — e.g. ``### `dynamodb-table` inputs``, ``### `dynamodb-table` outputs``, ``### `dynamodb-autoscaling` inputs``, ``### `dynamodb-autoscaling` outputs``, and ``### `dynamodb-table` resources`` / ``### `dynamodb-autoscaling` resources`` under "Resources Created". A quick structural check: collect every non-fenced `#{1,6}` heading and assert `collections.Counter(texts)` has no value `> 1`
- `.github/workflows/ci.yaml` must always reflect the AWS service being provisioned by this module — job names, step descriptions, test targets, and required secrets/variables must reference DynamoDB tables and auto-scaling (not leftover references from the upstream template such as GCS, S3, or other services)

All validation (billing mode values, stream view types, capacity ranges, mutual exclusivity of `provisioned_capacity` with `billing_mode`, scope-vs-index_name coherence, `min_capacity <= max_capacity`, `target_utilization` 1–100, required fields) lives in each submodule's `variables.tf`.

## CI pipeline (`.github/workflows/ci.yaml`)

Runs on pushes/PRs to `main`, `feature/**`, `bug/**` when `modules/**`, `examples/**`, or `test/**` files change. All job names, step descriptions, and environment variables in this workflow must reference AWS DynamoDB — any leftover references to other services (GCS, S3, IAM, etc.) from the upstream template must be replaced.

1. **terraform-validate** — `fmt -check`, `init`, `validate` on both submodules (`modules/dynamodb-table`, `modules/dynamodb-autoscaling`)
2. **examples-validate** — `init` + `validate` on all `examples/*` configurations (needs step 1)
3. **terratest** — real AWS integration test via OIDC (needs step 2); requires `AWS_ROLE_ARN`, `AWS_REGION`, and `AWS_KMS_KEY_ARN` repo vars; test job names should reference DynamoDB (e.g., `dynamodb-table-terratest`)
4. **generate-changelog** — runs `git-cliff` on non-main branches (needs step 2)
5. **semantic-release** — runs only on `main` after steps 2 and 3; uses Conventional Commits to auto-version

## Commit message convention

Follows **Conventional Commits** — semantic-release uses this to determine the next version:

- `feat:` → minor bump
- `fix:` → patch bump
- `chore:`, `docs:`, `refactor:`, etc. → no release
- Breaking changes via `BREAKING CHANGE:` footer → major bump
