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

When an application is ineligible, both its configuration directory
and descendants must be excluded from ChezMoi management.

File-level exclusions alone can leave parent directories under
management, resulting in unnecessary directory creation or permission
reconciliation.

Use the narrowest application-specific subtree. Exclusions must not
affect unrelated managed configuration.

Excluding a subtree does not delete existing configuration, uninstall
applications, or revoke user access. Existing excluded directories,
files, and permissions remain unmanaged.

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

K9s, LazyJournal, and Network Doctor configuration subtrees are
managed only when their respective applications are eligible.

| Configuration subtree | Eligibility condition |
|---|---|
| `~/.config/k9s/` | K9s is eligible |
| `~/.config/lazyjournal/` | LazyJournal is eligible |
| `~/.config/netdoc/` | Network Doctor is eligible |
| `~/.config/novalab/themes/` | At least one compatible tui-kit application is eligible |

For each ineligible subtree, `.chezmoiignore.tmpl` renders both the
directory exclusion and its recursive descendant exclusion.

OPNsense is excluded from all four infrastructure TUI configuration
subtrees.

The initial ZGX ARM64 canary dry-run identified that file-level
exclusions prevented K9s skin deployment but still permitted creation
of empty K9s directories. Subtree exclusions and native filesystem
regression tests were introduced to correct this behavior.

Existing excluded configurations are preserved rather than removed.

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

On K9s-eligible hosts, ChezMoi's `private_` directory attributes enforce
restrictive permissions on the K9s configuration hierarchy.

On K9s-ineligible hosts, the entire configuration subtree is excluded
from management. Existing directory permissions and user-owned files
are not reconciled.

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
- Application-specific directory and recursive descendant exclusions.
- Detection of obsolete file-level exclusion rules.
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

The test uses temporary configuration directories and isolated shell
environments to validate eight activation scenarios:

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

The test also checks Bash syntax and removes its temporary test
directory on exit.

### Linux filesystem permission validation

From a Linux shell or WSL with ChezMoi available on PATH, run:

```bash
bash scripts/test-theme-permissions.sh
```

The test performs actual ChezMoi reconciliation against temporary
Linux destinations using the repository's application selector,
ignore rules, theme data, and infrastructure TUI configuration
templates.

This validates native ChezMoi exclusion behavior rather than
reimplementing its ignore pattern semantics in the test suite.

The isolated source contains no bootstrap scripts, application
installation scripts, or unrelated host configuration.

| Scenario | Expected behavior |
|---|---|
| Fresh eligible installation | Create private K9s directories and the managed skin |
| Existing eligible installation | Correct directory permissions and preserve existing user configuration |
| Permission drift and repeated reconciliation | Restore restrictive permissions, preserve content, and converge without further differences |
| Fresh ZGX installation | Exclude the complete K9s subtree while deploying eligible infrastructure TUI configurations |
| Existing ZGX configuration | Preserve unmanaged K9s directories, permissions, configuration, aliases, and skin |
| OPNsense profile | Exclude all four infrastructure TUI configuration subtrees |

The test validates:

- `0700` permissions on the configuration root and both K9s directories.
- `0644` permissions on the generated NovaLabs skin.
- Preservation of existing `0600` configuration and aliases files.
- SHA-256 content integrity of existing user-owned files.
- Skin content stability during permission drift correction.
- Empty ChezMoi diffs after successful reconciliation.
- Repeated, unattended reconciliation.
- Absence of ineligible configuration directories on fresh destinations.
- Preservation of existing excluded directory permissions.
- SHA-256 content integrity of excluded user-owned configuration files.
- Continued deployment of eligible configuration on mixed-eligibility hosts.
- Complete infrastructure TUI configuration subtree exclusion for OPNsense.

ChezMoi configuration, source, destination, cache, and persistent
state are isolated within a temporary test directory.

The test uses `chezmoi apply --force` only against its isolated
destination to avoid interactive prompts when correcting deliberately
introduced fixture differences. This does not change the policy for
normal host reconciliation.

Temporary test directories are removed automatically when the test exits.

All six filesystem regression scenarios were validated using the
pinned ChezMoi v2.72.1 release on an AMD64 Linux filesystem.

The OPNsense scenario validates profile eligibility using an isolated
Linux test runner. Native FreeBSD reconciliation is outside the scope
of this validation.

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

## Live canary deployment validation

Live canary deployments complement isolated cross-architecture binary
testing and automated configuration regression testing.

Each canary validates the standard bootstrap workflow, host-specific
application enrollment, existing configuration preservation, native
application behavior, and post-deployment configuration convergence.

### AMD64 canary — OpsLab

| Attribute | Result |
|---|---|
| Host | `ops-lab-01` |
| Platform | Ubuntu / AMD64 |
| Enrollment profile | `any` |
| Optional Docker enrollment | `false` |
| Validated release | `05ec568` |
| Expected Mise applications | 27 |
| Newly installed infrastructure applications | 10 |
| Deployment status | Passed |

Acceptance results:

- Authoritative Forgejo and public GitHub mirror commit identifiers matched.
- All 27 declared applications were installed at their requested versions.
- All ten new infrastructure applications installed successfully.
- Network Doctor artifact attestation verification succeeded.
- Both managed theme environment variables activated correctly.
- All five K9s filesystem permission checks passed.
- Existing K9s configuration and aliases were byte-for-byte unchanged.
- Native application runtime checks passed.
- Mise-managed K9s took precedence over the existing dpkg installation.
- The legacy K9s package was retired through APT after recovery package
  reconstruction and verification.
- No additional packages were removed during K9s retirement.
- The final K9s executable resolved exclusively to the Mise installation.
- `chezmoi verify --exclude=scripts` passed.
- The source repository remained clean and synchronized.

The initial OpsLab dry-run identified a directory permission regression
that would have relaxed existing K9s configuration permissions.

The correction introduced private source directory attributes and was
integrated through PR #4 before live reconciliation.

The original K9s configuration, previous Mise manifest, and reconstructed
Debian package remain available in a private local recovery directory.
The recovery package passed metadata, contents, and SHA-256 verification.

The reconstructed package is a local recovery artifact rather than a
verified reproduction of the original upstream installer.

Validation limitations:

- Actual recovery package restoration was not tested.
- Full Docker-dependent application functionality was not validated.
- `dpkg-repack` was installed as a local recovery utility and is not a
  declared NovaLabs application dependency.

### ARM64 canary — ZGX

| Attribute | Result |
|---|---|
| Host | `zgx-40e6` |
| Platform | Ubuntu / ARM64 |
| Enrollment profile | `zgx` |
| Optional Docker enrollment | `false` |
| Initial preview release | `05ec568` |
| Validated release | `b7800a7` |
| Expected Mise applications | 25 |
| Newly installed infrastructure applications | 9 |
| Deployment status | Passed |

The initial live dry-run identified unnecessary K9s directory creation
on a host where K9s was ineligible. Live reconciliation was paused
before any configuration changes were applied.

The application subtree exclusion correction was integrated into
authoritative main and validated through 64 reported regression
checkpoints, including six native filesystem scenarios.

The corrected release was synchronized to ZGX after confirming
identical commit identifiers across the authoring workstation,
authoritative Forgejo repository, and automatic GitHub mirror.

The repeated live dry-run confirmed that the complete K9s
configuration subtree was excluded from management.

Acceptance results:

- Host identity, operating system, and ARM64 architecture validation passed.
- All 25 declared applications were installed at their requested versions.
- All 16 previously installed application version pins were preserved.
- All nine new infrastructure applications installed successfully.
- All nine new executables resolved to their Mise-managed installations.
- All nine executables were native, statically linked ARM64 ELF binaries.
- Network Doctor artifact attestation verification succeeded.
- The pinned native package baseline was already satisfied.
- No native OS packages were upgraded, installed, or removed.
- The unused Mise version audit returned no entries.
- The complete K9s configuration subtree remained absent after reconciliation.
- The existing btop configuration was byte-for-byte unchanged.
- All three eligible theme configuration files were deployed with
  user ownership and `0644` permissions.
- `TUI_THEME` activated correctly in a fresh login shell.
- `K9S_SKIN` remained unset.
- All eight theme-enabled applications passed visual and interactive
  acceptance.
- Dive successfully inspected two existing local Docker images:
  `alpine:3.22` and `curlimages/curl:latest`.
- No additional Docker images or containers were required for testing.
- `chezmoi verify --exclude=scripts` passed.
- The source repository remained clean and synchronized.

The application directory eligibility finding was resolved and
verified through actual live reconciliation on ZGX.

The original Mise manifest, shell environment configuration, and
btop configuration were preserved in a private local recovery
directory with `0700` permissions.

All three recovery artifacts passed SHA-256 verification before
deployment and again after final acceptance.

Validation limitations:

- Actual recovery restoration was not tested.
- The recovery checkpoint is a targeted configuration backup,
  not a full system snapshot.
- Privileged infrastructure administration features were not exercised.
- Docker integration testing was limited to inspection of existing
  local images using the current user's Docker permissions.
- Native FreeBSD reconciliation remains outside the validated scope.
- Comprehensive artifact integrity verification beyond the confirmed
  Network Doctor attestation remains a separate improvement.

### Regression baseline

The application directory eligibility correction passed:

| Validation suite | Passed |
|---|---:|
| Application enrollment scenarios | 10 |
| Theme enrollment scenarios | 10 |
| Generated theme configurations | 30 |
| Shell environment scenarios | 8 |
| Native filesystem scenarios | 6 |
| Total reported validation checkpoints | 64 |

These counts represent distinct scenario and configuration checks,
not a code coverage percentage.

The shared ChezMoi template directory also uses an explicit LF
normalization policy, including extensionless templates. This policy
was integrated independently through PR #5 (`26f96ec`).

## Fleet deployment validation

Following successful AMD64 and ARM64 canary acceptance, the
declarative application catalog and infrastructure TUI configuration
completed deployment across all eight eligible Linux hosts.

The fleet rollout release was:

`ba5bde2f7fdd7e01cd068014d2093dd0ba0e9893`

The earlier canary acceptance baselines remain recorded in the
preceding sections.

### Fleet acceptance results

| Metric | Result |
|---|---:|
| Eligible Linux hosts | 8 |
| Accepted Linux hosts | 8 |
| Fleet deployment coverage | 100% |
| Fleet technical acceptance coverage | 100% |
| Verified Mise application installations | 203 |
| Newly enrolled infrastructure application instances | 72 |
| Introduced infrastructure application identifiers | 10 |
| Validated CPU architectures | 2 |
| New post-canary deployment defects | 0 |

All declared application versions were verified against their
requested versions.

All eight hosts passed applicable configuration convergence and
representative native runtime acceptance checks.

The remaining fleet deployments required no corrective application,
theme, or installer patches following canary acceptance.

### Operational acceptance

The fleet deployment validated:

- Profile-based application and configuration eligibility.
- Preservation of existing application version pins.
- Host-specific theme rendering and shell environment activation.
- K9s configuration permission and subtree exclusion policies.
- Selected live Kubernetes and Docker integration.
- Representative production infrastructure service availability.
- Targeted recovery artifact integrity where checkpoints were established.
- Consistent release distribution through Forgejo and its automatic
  GitHub mirror.

Full native application acceptance was performed during canary
validation and the expanded Lovelace deployment.

Subsequent hosts used representative runtime smoke tests and
service-specific verification appropriate to their responsibilities.

### Acceptance boundaries

Fleet acceptance does not imply exhaustive functional testing of
every application on every host.

Actual recovery restoration remains untested. A separate
predeployment recovery checkpoint was not demonstrated for Worker 01.

Privileged administration, comprehensive production workload health
auditing, and native FreeBSD application reconciliation remain
outside the validated scope.

Comprehensive artifact integrity verification beyond the confirmed
Network Doctor attestations remains a separate improvement.

OPNsense remains excluded from the Linux infrastructure TUI
deployment denominator.

The consolidated host-by-host acceptance records, application
enrollment matrix, recovery provisions, deployment metrics, and
validation limitations are maintained in
[Fleet Rollout and Acceptance](fleet-rollout.md).

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
