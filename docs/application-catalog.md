# NovaLabs Application Catalog

## Overview

NovaLabs Dotfiles uses a declarative application catalog to manage portable userland applications across supported Linux hosts.

Application declarations are separated from configuration rendering and host-specific selection logic.

## Ownership

| Component | Owner |
|---|---|
| Application versions and deployment scope | Application catalog |
| Application installation and version management | Mise |
| Configuration rendering and deployment | ChezMoi |
| Host identity and platform policy | Host catalog |
| Host palettes and semantic colors | Theme catalog |
| System packages and services | Native OS or platform vendor |

Forgejo remains the authoritative repository. GitHub is a public mirror.

## Repository components

| Path | Responsibility |
|---|---|
| `.chezmoidata/apps.toml` | Application declarations |
| `.chezmoidata/hosts.toml` | Host identity and platform policy |
| `.chezmoidata/theme.toml` | Host themes |
| `.chezmoitemplates/apps/selection` | Reusable application eligibility selector |
| `private_dot_config/mise/config.toml.tmpl` | Mise configuration renderer |
| `.chezmoiignore.tmpl` | Application configuration exclusions |
| `scripts/test-app-catalog.py` | Automated catalog validation |

## Application schema

Each application is declared under `[apps.<name>]` in `apps.toml`.

| Field | Required | Description |
|---|---|---|
| `backend` | Yes | Mise tool identifier |
| `version` | Yes | Exact application version |
| `profiles` | Yes | Eligible host profiles |
| `exclude_profiles` | No | Explicit profile exclusions |
| `optional_profiles` | No | Enrollment-dependent profile inclusion |
| `options` | No | Additional Mise installation parameters |

The catalog schema version is defined under `[app_catalog]`.

## Profile selection

The application selector evaluates eligibility in the following order:

1. The host must use Linux and have a managed mutation policy.
2. Explicit profile exclusions take precedence over inclusions.
3. The `all-linux` selector includes every managed Linux profile.
4. Explicit profile names include the corresponding hosts.
5. Optional profile inclusion requires the associated enrollment flag to be enabled.
6. Applications without a matching inclusion are excluded.

OPNsense remains stage-only and receives no catalog-managed applications.

## Adding an application

Applications should use a supported Mise backend and an exact version pin.

Example:

```toml
[apps.example]
backend = "aqua:vendor/example"
version = "1.2.3"
profiles = ["all-linux"]
```

For a restricted deployment:

```toml
[apps.example]
backend = "aqua:vendor/example"
version = "1.2.3"
profiles = ["any", "docker"]
```

For an explicit host exception:

```toml
[apps.example]
backend = "aqua:vendor/example"
version = "1.2.3"
profiles = ["all-linux"]
exclude_profiles = ["zgx"]
```

The application backend identifier must be unique within the catalog.

Do not commit floating version selectors such as `latest`, `stable`, or partial version numbers.

## Advanced installation options

Applications that require additional Mise parameters may declare an `options` table.

Tree-sitter CLI is an existing example:

```toml
[apps.tree-sitter-cli]
backend = "cargo:tree-sitter-cli"
version = "0.26.9"
profiles = ["all-linux"]

[apps.tree-sitter-cli.options]
default-features = false
locked = true
depends = ["rust"]

[apps.tree-sitter-cli.options.install_env]
RUSTUP_TOOLCHAIN = "1.99.1"
```

The Mise renderer serializes these options into the generated TOML configuration.

## Configuration ownership

Application installation is managed by Mise. Application configuration is managed separately by ChezMoi.

When an application's configuration should only exist on eligible hosts, `.chezmoiignore.tmpl` must use the shared application selector rather than independently declaring profile conditions.

Application-specific exclusion paths remain in `.chezmoiignore.tmpl`.

## Existing ownership exceptions

- ZGX retains its externally managed GPU-enabled btop installation.
- LazyDocker is enabled on the `any`, `docker`, and `zgx` profiles.
- LazyDocker is optional on UbuntuLab and requires `withDocker` enrollment.
- Chronytop retains its separate Proxmox-specific installation workflow.
- Docker engine, containerd, NVIDIA platform components, and system services remain outside the portable application catalog.

## Validation

Requirements:

- Python 3.11 or newer.
- ChezMoi available on PATH.

From the repository root:

```bash
python scripts/test-app-catalog.py
```

The test validates:

- Every declared host profile.
- Both UbuntuLab Docker enrollment states.
- Application selection and exact rendered configuration.
- Deterministic template output.
- Unique Mise backend identifiers.
- LazyDocker configuration eligibility.
- ZGX btop preservation.
- OPNsense application exclusion.

The validation script does not install applications or apply host configuration.

## Application updates

1. Create a feature branch.
2. Verify the upstream release, architecture support, and installation backend.
3. Update the exact version in `apps.toml`.
4. Update application configuration when required.
5. Run the catalog validation script.
6. Review the Git diff.
7. Commit and push the change to Forgejo.
8. Validate on representative Linux hosts before fleet deployment.

Use the normal NovaLabs Dotfiles reconciliation workflow for deployment.

Do not modify generated Mise configuration directly.

## Migration baseline

The declarative application catalog was introduced against repository commit `b24a714`.

The migration preserved the existing application identifiers, version pins, advanced installation options, and deployment policies across all managed Linux enrollment scenarios.

OPNsense application exclusion was added as an explicit platform safety guard.