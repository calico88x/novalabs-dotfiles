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

## Infrastructure TUI applications

The application catalog includes infrastructure administration, diagnostics, and observability tools.

| Application | Executable | Purpose | Enrollment |
|---|---|---|---|
| K9s | `k9s` | Kubernetes resource inspection and administration | `any`, `lovelace`, `worker1` |
| Dive | `dive` | Container image and layer inspection | `any`, `docker`, `zgx` |
| LazyJournal | `lazyjournal` | System, container, and Kubernetes log inspection | All managed Linux profiles |
| Network Doctor | `netdoc` | Network diagnostics | All managed Linux profiles |
| tui-cert | `tui-cert` | TLS certificate inspection | All managed Linux profiles |
| tui-disk | `tui-disk` | Disk and storage inspection | All managed Linux profiles |
| tui-systemd | `tui-systemd` | Systemd service inspection and management | All managed Linux profiles |
| tui-traffic | `tui-traffic` | Network traffic inspection | All managed Linux profiles |
| tui-cron | `tui-cron` | Scheduled task inspection and management | All managed Linux profiles |
| tui-ssh | `tui-ssh` | SSH connection management | All managed Linux profiles |

Exact application versions and backend identifiers are maintained exclusively in `apps.toml`.

### Installation backends

Aqua registry recipes are preferred when available and compatible. Applications without suitable Aqua recipes may use Mise's native GitHub backend.

All ten infrastructure TUI applications have been validated using Mise `2026.8.9` on native Linux AMD64 and ARM64 environments.

No architecture-specific overrides, custom installation scripts, source compilation, or elevated installation privileges were required.

### Runtime boundaries

Application installation does not imply ownership of the underlying infrastructure or permission to administer it.

- K9s requires an appropriate Kubernetes configuration and existing RBAC authorization.
- Dive requires a compatible container image source.
- LazyJournal can only access log sources available to the current user.
- Systemd and scheduled task management remain subject to existing operating system permissions.
- Network inspection capabilities depend on available interfaces, system facilities, and permissions.
- SSH credentials and private keys remain outside repository ownership.

Do not automatically grant elevated privileges, Linux capabilities, group memberships, or additional Kubernetes permissions to support these applications.

Do not execute user-writable Mise-managed binaries with elevated privileges as a workaround for insufficient access.

### Cross-architecture validation

Initial installation validation was performed in isolated Mise environments:

| Environment | Architecture | Distribution | Installation | Executable smoke tests |
|---|---|---|---|---|
| NOVA-Z790 Ubuntu WSL2 | AMD64 | Ubuntu 24.04.4 LTS | 10/10 passed | 10/10 passed |
| ZGX | ARM64 | Ubuntu 24.04.5 LTS | 10/10 passed | 10/10 passed |

All twenty installed executables were confirmed to be statically linked ELF binaries for their respective native architectures.

The complete ARM64 test environment occupied approximately 177 MiB, including installation metadata and cache. K9s accounted for approximately 118 MiB.

These results establish installation and basic executable compatibility. Full interactive functionality, host-specific runtime dependencies, and application configuration compatibility require separate validation.

### Release integrity

All applications use exact version pins.

Mise explicitly reported successful GitHub artifact attestation verification for Network Doctor on both architectures.

Checksum enforcement for the remaining applications was not independently established during the initial installation tests.

Exact version pins provide deterministic version selection but must not be treated as equivalent to cryptographically pinned artifact digests.

Repository-managed artifact checksums and lockfiles remain candidates for a separate supply-chain hardening initiative.

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
- Lovelace's existing standalone K9s installation is retained until the
  Mise-managed replacement has been installed and verified.
- The existing Lovelace K9s executable resolves from `~/.local/bin/k9s`
  to `~/.local/opt/k9s-v0.51.0/bin/k9s`.
- K9s ownership migration must preserve existing configuration,
  Kubernetes credentials, and a recoverable copy of the previous binary.
- Worker1 has no existing K9s installation detected and requires no
  ownership migration before initial installation.
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
- Independent LazyDocker enrollment policy assertions.
- Independent K9s and Dive profile eligibility assertions.
- Mandatory infrastructure TUI enrollment on managed Linux profiles.
- ZGX btop preservation.
- OPNsense application exclusion.

Application policy assertions are intentionally independent of the
application catalog. They detect unintended enrollment changes even
when the rendered Mise configuration correctly follows the catalog.

Version pins are not duplicated in these policy assertions.

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