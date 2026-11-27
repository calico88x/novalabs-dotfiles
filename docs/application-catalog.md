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
| tui-ssh | `tui-ssh` | SSH server configuration and administration | All managed Linux profiles |

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

## Infrastructure TUI themes

Infrastructure TUI appearance is derived from the centralized theme catalog:

```text
.chezmoidata/theme.toml
```

Application installation and configuration eligibility remain controlled by the application catalog and shared application selector.

Theme templates consume host-specific palette data and shared interface colors without duplicating application enrollment policy.

### Theme catalog structure

| Catalog section | Responsibility |
|---|---|
| `theme.shared` | Shared foreground, background, and semantic colors |
| `theme.tui` | Common interface surfaces and supplementary colors |
| `theme.hosts.<profile>` | Host-specific visual identity and application color mappings |
| `theme.preferences` | Shared application-specific appearance preferences |

The existing theme catalog schema version is retained because these additions are backward-compatible.

Host-specific accents are derived from the selected ChezMoi profile, not from the runtime hostname or the infrastructure endpoint an application connects to.

### Application theme strategies

Not every terminal application supports the same customization capabilities. NovaLabs uses native application configuration rather than requiring patched binaries or application-specific launch wrappers.

| Application | Theme strategy | Configuration ownership |
|---|---|---|
| tui-cert | Shared tui-kit RGB palette | Managed |
| tui-disk | Shared tui-kit RGB palette | Managed |
| tui-systemd | Shared tui-kit RGB palette | Managed |
| tui-traffic | Shared tui-kit RGB palette | Managed |
| tui-cron | Shared tui-kit RGB palette | Managed |
| tui-ssh | Shared tui-kit RGB palette | Managed |
| K9s | Native host-specific RGB skin | Managed skin and directory permissions |
| LazyJournal | Native ANSI color configuration | Create-only |
| Network Doctor | Native `contrast` preset | Create-only |
| Dive | Native appearance | Unmanaged |

All theme configuration is managed at the user level. Theme integration does not grant privileges or change the configuration of underlying system services.

### Configuration paths

| Repository source | Deployment target |
|---|---|
| `private_dot_config/novalab/themes/tui-kit.toml.tmpl` | `~/.config/novalab/themes/tui-kit.toml` |
| `private_dot_config/private_k9s/private_skins/novalab.yaml.tmpl` | `~/.config/k9s/skins/novalab.yaml` |
| `private_dot_config/lazyjournal/create_config.yml.tmpl` | `~/.config/lazyjournal/config.yml` |
| `private_dot_config/netdoc/create_theme.tmpl` | `~/.config/netdoc/theme` |

Configuration eligibility is evaluated using the shared application selector in `.chezmoiignore.tmpl`.

The shared tui-kit palette is deployed when at least one compatible application is eligible.

K9s, LazyJournal, and Network Doctor configuration files are deployed only when their respective applications are eligible.

OPNsense is excluded from infrastructure TUI theme deployment.

### Configuration ownership

Managed theme files are rendered from the repository and converged through ChezMoi. Changes to these files should be made in the repository rather than directly on individual hosts.

Create-only files use ChezMoi's `create_` attribute. They are initialized when absent but existing files and subsequent user modifications are preserved.

Changes to LazyJournal or Network Doctor defaults therefore affect new configurations rather than automatically overwriting existing preferences.

Configuration exclusion does not remove previously deployed files. Retiring obsolete configuration requires a separate, explicitly reviewed cleanup operation.

### Shell activation

The shared Bash environment activates managed themes when their corresponding configuration files are readable.

| Environment variable | Default |
|---|---|
| `TUI_THEME` | `${XDG_CONFIG_HOME}/novalab/themes/tui-kit.toml` |
| `K9S_SKIN` | `novalab` |

Existing non-empty environment overrides are preserved.

Empty or unset variables receive the NovaLabs defaults when the corresponding files are available.

If a managed theme file is missing, the activation logic does not assign its default environment variable or clear an existing value.

No application-specific aliases or executable wrappers are required.

The activation logic respects `XDG_CONFIG_HOME`. However, ChezMoi currently deploys these files under `~/.config`. Custom XDG configuration locations require separately arranged file placement.

Start a fresh login shell after reconciliation to activate the managed environment.

```bash
exec bash -l
```

### Shared tui-kit palette

The six infrastructure applications maintained by the tui-tools project share a single generated palette compatible with the tui-kit Omarchy theme format.

The palette combines host-specific accent colors with shared foreground, background, surface, selection, and semantic colors.

Applications load the palette through the `TUI_THEME` environment variable. An explicit application theme selection can be used for temporary appearance overrides.

The shared palette is managed as one configuration file to keep compatible applications visually consistent.

### K9s

K9s uses a native skin generated from the selected host's palette.

The NovaLabs skin and its parent directory permissions are managed.
General K9s configuration, context configuration, Kubernetes credentials,
plugins, and runtime state remain user-owned.

#### Directory permission policy

ChezMoi's `private_` directory attributes enforce restrictive permissions
on the K9s configuration hierarchy.

| Deployment target | Permissions | Policy |
|---|---|---|
| `~/.config/k9s/` | `0700` | Managed private directory |
| `~/.config/k9s/skins/` | `0700` | Managed private directory |
| `~/.config/k9s/skins/novalab.yaml` | `0644` | Managed skin |
| Existing K9s configuration and aliases | Unchanged | User-owned |

The private parent directories prevent other ordinary users from
traversing the K9s configuration hierarchy.

Existing unmanaged configuration files are not rewritten or removed
during theme reconciliation.

The initial OpsLab canary dry-run identified that non-private source
directory attributes would relax existing K9s directory permissions
from `0700` to `0755`. Private source attributes and Linux filesystem
regression tests were introduced to prevent this behavior.

#### Skin activation

The skin is selected through `K9S_SKIN=novalab` unless a non-empty environment override already exists.

The skin uses host-specific accents for headings, focused borders, normal resource text, and normal resource selection backgrounds.

#### Status-aware selection

K9s v0.51.0 derives selected resource row backgrounds from the selected cell's color.

The configured `cursorBgColor` is applied during style initialization but can be overridden by the resource selection handler.

NovaLabs preserves this native status-aware behavior rather than modifying the K9s binary.

In this release, `frame.status.newColor` controls the standard resource color, including healthy running pods.

| Resource color role | NovaLabs palette |
|---|---|
| Standard and modified resources | Host accent |
| Added and initializing resources | Shared success |
| Pending and container creation | Shared warning |
| Invalid and error resources | Shared error |
| Highlighted resources | Shared warning |
| Completed and terminating resources | Shared muted |

Consequently, selecting a healthy running pod uses the host accent, while rows assigned warning or error colors retain their corresponding semantic selection backgrounds.

The selected row foreground uses the shared dark background color.

The relevant upstream implementation was inspected at the pinned K9s v0.51.0 release:

- `internal/ui/table.go`
- `internal/ui/select_table.go`
- `internal/ui/config.go`
- `internal/render/pod.go`
- `internal/model1/color.go`

Revalidate these mappings when upgrading K9s because native rendering behavior may change between releases.

The skin follows the local NovaLabs host identity, not the identity of the connected Kubernetes cluster.

### LazyJournal

LazyJournal v0.8.7 supports named terminal colors rather than arbitrary RGB theme values.

NovaLabs provides an initial configuration using the closest supported named color for each managed host.

| Profile | Accent |
|---|---|
| `any` | magenta |
| `proxmox` | yellow |
| `docker` | cyan |
| `pihole` | red |
| `ubuntulab` | yellow |
| `lovelace` | magenta |
| `worker1` | yellow |
| `zgx` | green |

Actual displayed colors depend on the terminal's ANSI palette.

Only interface color preferences are initialized. Other settings retain native application defaults.

The configuration is create-only to preserve subsequent application preferences and existing user configuration.

LazyJournal searches for configuration in the following order:

1. Current working directory.
2. Executable directory.
3. `/etc/lazyjournal/config.yml`.
4. `~/.config/lazyjournal/config.yml`.

Higher-priority configuration files may take precedence over the NovaLabs-generated file.

The pinned release does not use `XDG_CONFIG_HOME` for this configuration lookup.

### Network Doctor

Network Doctor v2.2.2 supports native theme presets rather than arbitrary host-specific palettes.

NovaLabs initializes the `contrast` preset on all eligible hosts.

This preference provides a consistent, high-contrast diagnostic interface independent of the host palette.

The initial preference is create-only. Users may subsequently select another native theme using the application's theme picker (`T`).

Existing preferences are preserved during reconciliation.

### Dive

Dive v0.13.1 retains its native appearance.

The pinned release does not expose a documented custom color palette through its native configuration.

NovaLabs does not introduce a patched binary or terminal-wide color override solely to customize Dive.

### Runtime validation

All nine customized applications successfully loaded their native NovaLabs appearance during isolated AMD64 runtime testing.

The six tui-kit applications were tested using their demo modes without privilege escalation.

LazyJournal and Network Doctor were tested using temporary user configuration directories.

K9s was tested against the Lovelace cluster from Ubuntu WSL using an explicit Kubernetes context and application read-only mode. The existing kubeconfig was referenced directly without duplicating credentials.

K9s native logs confirmed loading the generated NovaLabs skin. The final host-accent selection behavior was visually confirmed.

Warning and error color propagation was verified through pinned upstream source inspection and configuration assertions. Unhealthy workloads were not intentionally created in Lovelace for cosmetic testing.

These tests complement the native AMD64 and ARM64 installation and executable smoke tests. They do not constitute a complete interactive validation of every application on both architectures.

Fleet reconciliation and host-specific runtime validation remain separate deployment activities.

## Existing ownership exceptions

- ZGX retains its externally managed GPU-enabled btop installation.
- LazyDocker is enabled on the `any`, `docker`, and `zgx` profiles.
- LazyDocker is optional on UbuntuLab and requires `withDocker` enrollment.
- Chronytop retains its separate Proxmox-specific installation workflow.
- Lovelace's existing standalone K9s installation is retained until the
  Mise-managed replacement has been installed and verified.
- The existing Lovelace K9s executable resolves from `~/.local/bin/k9s`
  to `~/.local/opt/k9s-v0.51.0/bin/k9s`.
- OpsLab retains an existing dpkg-managed K9s v0.51.0 installation
  at `/usr/bin/k9s` until its Mise-managed replacement has been
  installed and verified.
- On OpsLab, `/bin/k9s` and `/usr/bin/k9s` resolve to the same
  physical executable.
- Package-managed K9s installations must be retired through their
  package manager rather than by manually deleting executables.
- K9s ownership migration must preserve existing configuration,
  Kubernetes credentials, and a recoverable rollback path for the
  previous installation.
- Legacy executables are retained until the Mise-managed replacement,
  shell PATH precedence, and native application behavior have been
  verified.
- Worker1 has no existing K9s installation detected and requires no
  ownership migration before initial installation.
- Docker engine, containerd, NVIDIA platform components, and system services remain outside the portable application catalog.

## Validation

### Development requirements

- Python 3.11 or newer.
- ChezMoi available on PATH.
- PyYAML available in the Python development environment.
- Bash for shell environment and filesystem regression testing.
- A Linux environment or WSL for running the shell regression suites.
- Linux filesystem utilities, including `stat`, `chmod`, `mktemp`,
  and `sha256sum`, for destination permission validation.

PyYAML is a development and testing dependency only. It is not required for normal NovaLabs host reconciliation.

### Application catalog validation

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

Application policy assertions are intentionally independent of the application catalog. They detect unintended enrollment changes even when the rendered Mise configuration correctly follows the catalog.

Version pins are not duplicated in these policy assertions.

### Theme catalog validation

```bash
python scripts/test-theme-catalog.py
```

The test validates:

- Centralized theme catalog structure and color values.
- Host palette coverage.
- Native LazyJournal color mappings.
- Network Doctor's initial theme preference.
- Theme configuration eligibility.
- Agreement between application enrollment and configuration deployment.
- Independent configuration eligibility expectations.
- Deterministic theme rendering.
- Generated configuration formatting.
- Native TOML and YAML parsing.
- Shared tui-kit palette mappings.
- K9s interface and semantic color assignments.
- K9s host-specific cursor and resource color mappings.
- K9s private source directory attributes.
- Absence of the legacy non-private K9s source directory.
- LazyJournal initial interface configuration.
- Network Doctor preference file content.
- OPNsense theme configuration exclusion.

The current validation baseline covers ten enrollment scenarios and thirty eligible theme configurations.

### Shell environment validation

From a Linux shell or WSL, run:

```bash
bash scripts/test-theme-env.sh
```

The test uses temporary configuration directories and isolated shell environments to validate eight activation scenarios:

| Scenario | Expected behavior |
|---|---|
| Neither theme file exists | No managed theme defaults assigned |
| Only tui-kit theme exists | Activate `TUI_THEME` |
| Only K9s skin exists | Activate `K9S_SKIN` |
| Both theme files exist | Activate both variables |
| Explicit overrides | Preserve existing non-empty values |
| Empty variables | Assign eligible NovaLabs defaults |
| Custom XDG configuration path | Resolve themes from the supplied path |
| Repeated initialization | Stable environment without duplicate PATH changes |

The test also checks Bash syntax and removes its temporary test directory on exit.

### Linux filesystem permission validation

From a Linux shell or WSL with ChezMoi available on PATH, run:

```bash
bash scripts/test-theme-permissions.sh
```

The test performs actual ChezMoi reconciliation against a temporary
Linux destination using the repository's K9s template and theme data.

The isolated source contains no bootstrap scripts, application
installation scripts, or unrelated host configuration.

| Scenario | Expected behavior |
|---|---|
| Fresh installation | Create private K9s directories and the managed skin |
| Existing installation | Correct directory permissions and preserve existing user configuration |
| Permission drift and repeated reconciliation | Restore restrictive permissions, preserve content, and converge without further differences |

The test validates:

- `0700` permissions on the configuration root and both K9s directories.
- `0644` permissions on the generated NovaLabs skin.
- Preservation of existing `0600` configuration and aliases files.
- SHA-256 content integrity of existing user-owned files.
- Skin content stability during permission drift correction.
- Empty ChezMoi diffs after successful reconciliation.
- Repeated, unattended reconciliation.

ChezMoi configuration, source, destination, cache, and persistent
state are isolated within a temporary test directory.

The test uses `chezmoi apply --force` only against its isolated
destination to avoid interactive prompts when correcting deliberately
introduced configuration drift.

This does not change the conflict protection policy used during
normal host reconciliation.

Temporary test directories are removed automatically when the test exits.

The filesystem regression suite was validated using the pinned
ChezMoi v2.72.1 release on an AMD64 Linux filesystem.

### Configuration ownership validation

Create-only configuration behavior was separately validated for LazyJournal and Network Doctor using temporary ChezMoi source and destination environments.

The tests confirmed that missing configuration files are initialized and existing user-modified files are preserved during subsequent reconciliation.

### Validation boundaries

The automated regression suites do not install applications, modify
live host configuration, or connect to Kubernetes clusters.

The application and theme catalog suites are render-only.
The shell environment suite uses isolated shell environments.
The filesystem permission suite performs actual reconciliation
exclusively against a temporary source and destination.

Native application runtime testing remains a separate validation activity.

Successful template parsing does not guarantee that an application consumes every supported configuration property. Verify native application behavior when changing theme configuration or upgrading pinned application versions.

Before committing application or theme changes, run the applicable regression suites and review the Git diff.

```bash
python scripts/test-app-catalog.py
python scripts/test-theme-catalog.py
bash scripts/test-theme-env.sh
bash scripts/test-theme-permissions.sh
git diff --check
```

## Application updates

1. Create a feature branch.
2. Verify the upstream release, architecture support, and installation backend.
3. Update the exact version in `apps.toml`.
4. Review native configuration and theme compatibility against the pinned release.
5. Update application configuration when required and run the applicable
   application, theme, shell environment, and filesystem permission
   regression suites.
6. Review the Git diff.
7. Commit and push the change to Forgejo.
8. Validate on representative Linux hosts before fleet deployment.

Use the normal NovaLabs Dotfiles reconciliation workflow for deployment.

Do not modify generated Mise configuration directly.

## Migration baseline

The declarative application catalog was introduced against repository commit `b24a714`.

The migration preserved the existing application identifiers, version pins, advanced installation options, and deployment policies across all managed Linux enrollment scenarios.

OPNsense application exclusion was added as an explicit platform safety guard.
