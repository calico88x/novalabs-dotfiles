# NovaLabs Fleet Rollout and Acceptance

## Overview

The NovaLabs infrastructure TUI initiative introduced a centralized,
declarative application catalog, profile-based application eligibility,
pinned application versions, and host-specific visual configuration.

Following automated regression testing and successful AMD64 and ARM64
canary deployments, the application and theme configuration was deployed
across all eight eligible Linux hosts.

This document records the consolidated fleet deployment results,
technical acceptance evidence, recovery provisions, and known
validation limitations.

Detailed application architecture, configuration ownership, automated
regression testing, and canary acceptance records are maintained in
[Application Catalog](application-catalog.md).

Historical migration and ownership decisions are maintained in
[Migration Ledger](migration-ledger.md).

## Release baseline

| Attribute | Value |
|---|---|
| Original migration baseline | `b24a714` |
| AMD64 canary acceptance baseline | `05ec568` |
| ARM64 canary acceptance baseline | `b7800a7` |
| Fleet rollout release | `ba5bde2` |
| Full fleet release commit | `ba5bde2f7fdd7e01cd068014d2093dd0ba0e9893` |
| Mise version | `2026.8.9` |
| ChezMoi version | `2.72.1` |
| Authoritative repository | Forgejo |
| Public distribution mirror | GitHub |
| Deployment status | Complete |
| Technical acceptance status | Passed |

The fleet rollout release includes the application catalog, infrastructure
TUI integrations, centralized theme configuration, resolved canary
findings, regression test suites, and ARM64 canary documentation.

The AMD64 and ARM64 canaries were deployed against earlier validated
implementation baselines. The fleet rollout release incorporates their
accepted implementation changes and subsequent documentation.

## Deployment objectives

The rollout was designed to:

- Preserve existing application identifiers and version pins.
- Install infrastructure applications according to profile eligibility.
- Preserve existing user-owned configuration.
- Apply consistent host-specific visual configuration.
- Validate native AMD64 and ARM64 application compatibility.
- Avoid unnecessary native package changes.
- Preserve existing infrastructure service availability.
- Establish recoverable configuration checkpoints.
- Verify configuration convergence following deployment.
- Maintain consistent distribution through the authoritative repository
  and its automatic public mirror.

## Fleet acceptance summary

| Host | Profile | Platform | Architecture | Mise applications | New enrollments | Acceptance |
|---|---|---|---|---:|---:|---|
| OpsLab | `any` | Ubuntu 24.04 | AMD64 | 27 | 10 | Passed |
| ZGX | `zgx` | Ubuntu 24.04 | ARM64 | 25 | 9 | Passed |
| Lovelace | `lovelace` | Debian 13 | ARM64 | 25 | 9 | Passed |
| Worker 01 | `worker1` | Debian 13 | AMD64 | 25 | 9 | Passed |
| DockerLXC | `docker` | Ubuntu 22.04 | AMD64 | 26 | 9 | Passed |
| Pi-hole | `pihole` | Debian 12 | AMD64 | 24 | 8 | Passed |
| Proxmox | `proxmox` | Debian 13 | AMD64 | 24 | 8 | Passed |
| Z270X | `any` | Ubuntu 24.04 | AMD64 | 27 | 10 | Passed |
| **Total** | | | | **203** | **72** | **8/8 passed** |

Application counts represent Mise-managed application enrollment
instances across hosts, rather than distinct application identifiers.

New enrollment counts include migration of previously installed K9s
executables into centralized Mise ownership.

Independently managed applications, native operating system packages,
and infrastructure workloads are excluded from these counts.

### Deployment metrics

| Metric | Result |
|---|---:|
| Eligible Linux hosts | 8 |
| Accepted Linux hosts | 8 |
| Fleet deployment coverage | 100% |
| Fleet technical acceptance coverage | 100% |
| Verified Mise application installations | 203 |
| Newly enrolled infrastructure application instances | 72 |
| Newly introduced application identifiers | 10 |
| Validated CPU architectures | 2 |
| Native package upgrades during standard bootstrap | 0 |
| Native package removals during standard bootstrap | 0 |
| New defects identified during post-canary fleet deployment | 0 |

The standard bootstrap transactions did not require native package
changes.

The separate AMD64 canary K9s ownership migration installed
`dpkg-repack` as a recovery utility and subsequently retired the
legacy K9s Debian package. Those deliberate recovery and migration
operations are not included in the standard bootstrap metrics.

## Infrastructure application enrollment

The following applications were introduced through the declarative
application catalog.

| Application | Pinned version | Fleet enrollments |
|---|---|---:|
| K9s | `0.51.0` | 4 |
| Dive | `0.13.1` | 4 |
| LazyJournal | `0.8.7` | 8 |
| Network Doctor | `2.2.2` | 8 |
| tui-cert | `1.1.1` | 8 |
| tui-disk | `1.0.3` | 8 |
| tui-systemd | `1.0.3` | 8 |
| tui-traffic | `0.1.5` | 8 |
| tui-cron | `1.0.0` | 8 |
| tui-ssh | `1.0.0` | 8 |
| **Total** | | **72** |

Application enrollment is determined by the declared profile policy.

An eligible application may be installed even when its associated
infrastructure service is not available locally.

Application installation eligibility and live infrastructure
connectivity are separate concerns.

### Application eligibility matrix

| Host | K9s | Dive | LazyDocker | Common infrastructure TUIs |
|---|---|---|---|---|
| OpsLab | Yes | Yes | Yes | Yes |
| ZGX | No | Yes | Yes | Yes |
| Lovelace | Yes | No | No | Yes |
| Worker 01 | Yes | No | No | Yes |
| DockerLXC | No | Yes | Yes | Yes |
| Pi-hole | No | No | No | Yes |
| Proxmox | No | No | No | Yes |
| Z270X | Yes | Yes | Yes | Yes |

The common infrastructure TUI group consists of LazyJournal,
Network Doctor, and the six tui-tools applications.

LazyDocker was already present in eligible profiles and is not
counted as a newly introduced infrastructure application.

## Theme acceptance

Host-specific visual configuration is generated from the centralized
theme catalog.

| Host | Primary TUI accent | LazyJournal accent | K9s skin | Network Doctor |
|---|---|---|---|---|
| OpsLab | `#FF79C6` | Magenta | `novalab` | Contrast |
| ZGX | `#5FF70D` | Green | Not enrolled | Contrast |
| Lovelace | `#AF63E1` | Magenta | `novalab` | Contrast |
| Worker 01 | `#FFE645` | Yellow | `novalab` | Contrast |
| DockerLXC | `#5AB7FF` | Cyan | Not enrolled | Contrast |
| Pi-hole | `#F8547A` | Red | Not enrolled | Contrast |
| Proxmox | `#FF9B3E` | Yellow | Not enrolled | Contrast |
| Z270X | `#FF79C6` | Magenta | `novalab` | Contrast |

All eight hosts passed the applicable theme integration acceptance
checks.

The shared tui-kit theme is activated through `TUI_THEME`.

Eligible K9s installations activate the managed skin through
`K9S_SKIN`.

LazyJournal and Network Doctor receive create-only initial
configuration, preserving subsequent user modifications.

Dive does not receive a managed visual configuration.

The theme catalog remains the authoritative source of visual
configuration. The table above records the accepted deployment
baseline rather than establishing an independent configuration source.

## Deployment methodology

### Canary validation

The AMD64 and ARM64 canaries were subjected to expanded validation
before the remaining fleet was deployed.

Canary validation included:

- Application eligibility and exact version verification.
- Native executable architecture verification.
- Configuration ownership and filesystem permission checks.
- Existing configuration preservation.
- Theme rendering and native application behavior.
- Live infrastructure integration where available.
- Recovery artifact verification.
- Post-deployment configuration convergence.

Findings discovered during canary validation were corrected and
integrated into the authoritative repository before fleet deployment.

Detailed canary findings and regression test results are maintained
in [Application Catalog](application-catalog.md#live-canary-deployment-validation).

### Fleet reconciliation

After canary acceptance, the remaining hosts were deployed using the
standard reconciliation workflow.

The workflow includes:

1. Inspect the source repository and current branch.
2. Synchronize using a fast-forward-only Git update.
3. Verify the intended release baseline.
4. Preview the bootstrap operation.
5. Review pending ChezMoi configuration differences.
6. Establish an appropriate recovery checkpoint.
7. Review native package requirements and simulate the transaction
   where additional scrutiny is required.
8. Perform a ChezMoi dry-run.
9. Apply the standard bootstrap.
10. Reload the login shell.
11. Verify application inventory and configuration convergence.
12. Perform representative runtime and service-specific smoke tests.
13. Verify recovery artifacts and applicable filesystem policies.

The actual acceptance procedure varied according to host
responsibilities, existing application ownership, available services,
and previous canary evidence.

### Runtime acceptance scope

Full native application testing was performed during canary validation
and the expanded Lovelace deployment.

Subsequent fleet deployments used representative runtime smoke tests
covering the three managed theme integration mechanisms:

- Shared tui-kit theme activation.
- LazyJournal initial configuration.
- Network Doctor theme selection.

Additional executable, filesystem, Kubernetes, Docker, DNS, and
hypervisor checks were performed where applicable.

Representative smoke tests do not constitute exhaustive functional
testing of every installed application on every host.

## Host acceptance records

### OpsLab

| Attribute | Result |
|---|---|
| Acceptance baseline | `05ec568` |
| Profile | `any` |
| Architecture | AMD64 |
| Mise applications | 27/27 |
| New enrollments | 10/10 |
| Acceptance | Passed |

OpsLab served as the initial AMD64 live canary.

The deployment identified an existing K9s directory permission
regression during preview. The regression was corrected before
live reconciliation.

Acceptance included:

- All declared application versions verified.
- Native application runtime checks passed.
- Managed theme activation verified.
- Existing K9s configuration and aliases preserved.
- K9s filesystem permissions verified.
- Legacy K9s Debian package retired following recovery package
  reconstruction and verification.
- Final K9s executable ownership resolved exclusively to Mise.
- Configuration convergence passed.

The original configuration and reconstructed recovery package remain
available locally.

Full Docker-dependent application functionality and actual recovery
package restoration were not tested.

### ZGX

| Attribute | Result |
|---|---|
| Acceptance baseline | `b7800a7` |
| Profile | `zgx` |
| Architecture | ARM64 |
| Mise applications | 25/25 |
| New enrollments | 9/9 |
| Acceptance | Passed |

ZGX served as the ARM64 live canary.

The initial preview identified unnecessary configuration directory
creation for an ineligible application. Live reconciliation was
paused until the directory eligibility policy was corrected.

Acceptance included:

- All declared application versions verified.
- All nine newly enrolled executables verified as native,
  statically linked ARM64 ELF binaries.
- Existing application pins preserved.
- Existing btop configuration preserved byte-for-byte.
- All eight theme-enabled applications passed interactive acceptance.
- Dive inspected two existing local Docker images successfully.
- K9s configuration subtree remained absent.
- Configuration convergence passed.
- Recovery artifact integrity verified before and after deployment.

No additional Docker images or containers were required for testing.

### Lovelace

| Attribute | Result |
|---|---|
| Acceptance baseline | `ba5bde2` |
| Profile | `lovelace` |
| Architecture | ARM64 |
| Mise applications | 25/25 |
| New enrollments | 9/9 |
| Acceptance | Passed |

Lovelace received the expanded production ARM64 deployment validation.

Acceptance included:

- All declared application versions verified.
- Existing application version pins preserved.
- All nine newly enrolled executables verified as native,
  statically linked ARM64 ELF binaries.
- Existing K9s configuration and aliases preserved during reconciliation.
- Existing btop configuration preserved byte-for-byte.
- K9s directory and skin permissions verified.
- Native application runtime checks passed.
- Read-only live K9s cluster inspection passed.
- Legacy K9s executable and Mise-managed executable verified as
  byte-for-byte identical.
- Legacy K9s executable link retired without deleting the original
  distribution.
- Both Kubernetes nodes remained Ready following deployment.
- Configuration convergence passed.
- Recovery artifact integrity verified.

The legacy K9s distribution and original symbolic link remain
recoverable from retained local artifacts.

Actual recovery restoration was not tested.

### Worker 01

| Attribute | Result |
|---|---|
| Acceptance baseline | `ba5bde2` |
| Profile | `worker1` |
| Architecture | AMD64 |
| Mise applications | 25/25 |
| New enrollments | 9/9 |
| Acceptance | Passed |

Worker 01 was deployed using the streamlined fleet reconciliation
procedure.

Acceptance included:

- All declared application versions verified.
- Existing application version pins preserved.
- K9s executable version verified.
- Managed theme environment variables activated.
- Representative theme integration smoke tests passed.
- Configuration convergence reported no differences.
- Source repository remained clean and synchronized.

A separate predeployment recovery checkpoint was not demonstrated
for this host.

Live Kubernetes connectivity from Worker 01 was not required for
acceptance. No additional cluster credentials were distributed
for application testing.

### DockerLXC

| Attribute | Result |
|---|---|
| Acceptance baseline | `ba5bde2` |
| Profile | `docker` |
| Architecture | AMD64 |
| Mise applications | 26/26 |
| New enrollments | 9/9 |
| Acceptance | Passed |

Acceptance included:

- All declared application versions verified.
- All existing version pins, including LazyDocker, preserved.
- Representative theme integration smoke tests passed.
- Dive successfully inspected an existing local Docker image.
- K9s configuration subtree remained absent.
- Configuration convergence passed.
- Recovery artifact integrity verified before and after deployment.
- All 25 containers reported by the post-deployment running
  container inventory were running.
- Reported container uptimes indicated no deployment-related restarts.

Container status verification was a point-in-time operational check,
not a comprehensive application or service health audit.

### Pi-hole

| Attribute | Result |
|---|---|
| Acceptance baseline | `ba5bde2` |
| Profile | `pihole` |
| Architecture | AMD64 |
| Mise applications | 24/24 |
| New enrollments | 8/8 |
| Acceptance | Passed |

Acceptance included:

- All declared application versions verified.
- Existing application version pins preserved.
- Representative theme integration smoke tests passed.
- Pi-hole FTL service remained active.
- Internal DNS resolution succeeded.
- External DNS resolution succeeded.
- K9s configuration subtree remained absent.
- Configuration convergence passed.
- Recovery artifact integrity verified before and after deployment.

No Pi-hole configuration changes or DNS service restarts were
required.

### Proxmox

| Attribute | Result |
|---|---|
| Acceptance baseline | `ba5bde2` |
| Profile | `proxmox` |
| Architecture | AMD64 |
| Mise applications | 24/24 |
| New enrollments | 8/8 |
| Acceptance | Passed |

The hypervisor deployment retained additional scrutiny of native
package requirements and core service availability.

Acceptance included:

- Predeployment APT simulation reported zero package changes.
- Actual native package transaction matched the simulation.
- All declared application versions verified.
- Existing application version pins preserved.
- Independently managed Chronytop `v0.6.1` remained unchanged.
- Representative theme integration smoke tests passed.
- All four inspected Proxmox services remained active:
  `pve-cluster`, `pvedaemon`, `pveproxy`, and `pvestatd`.
- K9s configuration subtree remained absent.
- Configuration convergence passed.
- Recovery artifact integrity verified before and after deployment.

Core hypervisor service availability was verified before and after
deployment.

Comprehensive guest workload health verification was outside the
acceptance scope.

### Z270X

| Attribute | Result |
|---|---|
| Acceptance baseline | `ba5bde2` |
| Profile | `any` |
| Architecture | AMD64 |
| Mise applications | 27/27 |
| New enrollments | 10/10 |
| Acceptance | Passed |

Z270X completed the final fleet deployment and validated the generic
Linux profile on a general-purpose Ubuntu workstation.

Acceptance included:

- Public GitHub mirror delivered the exact fleet release commit.
- Minimal generic Linux native package policy was applied.
- Predeployment APT simulation and actual transaction matched.
- All declared application versions verified.
- Existing application version pins preserved.
- K9s `0.51.0` executable and upstream build commit verified.
- Dive `0.13.1` executable version verified.
- Representative theme integration smoke tests passed.
- K9s parent and skin directories used `0700` permissions.
- Managed K9s skin used `0644` permissions.
- Configuration convergence passed.
- Recovery artifact integrity verified before and after deployment.
- Final source commit matched the exact fleet release SHA.

Live Kubernetes and Docker integration were not required for
workstation acceptance.

## Recovery provisions

Targeted recovery checkpoints were established for seven of the
eight eligible hosts.

Recovery artifacts were retained locally in private directories
created for the deployment.

Depending on existing application ownership, recovery checkpoints
included:

- Previous Mise configuration.
- Previous shell environment configuration.
- Existing btop configuration.
- Existing K9s configuration.
- Legacy K9s executable or package recovery artifacts.
- Symbolic link destination records where applicable.
- SHA-256 integrity manifests.

### Recovery verification summary

| Host | Recovery checkpoint | Integrity verification | Restoration tested |
|---|---|---|---|
| OpsLab | Configuration and reconstructed K9s package | Passed | No |
| ZGX | Targeted configuration backup | Passed | No |
| Lovelace | Configuration and legacy K9s distribution | Passed | No |
| Worker 01 | Not demonstrated | Not demonstrated | No |
| DockerLXC | Targeted configuration backup | Passed | No |
| Pi-hole | Targeted configuration backup | Passed | No |
| Proxmox | Targeted configuration backup | Passed | No |
| Z270X | Targeted configuration backup | Passed | No |

The recovery checkpoints are not full operating system backups or
hypervisor snapshots.

Integrity verification establishes that the recorded artifacts
match their checksum manifests. It does not demonstrate a
successful recovery procedure.

Recovery artifact locations remain local operational information
and are intentionally omitted from the public repository.

## Configuration convergence

All eight eligible hosts passed:

```bash
chezmoi verify --exclude=scripts
```

The verification establishes convergence of the applicable managed
configuration state at the time of acceptance.

Scripts are excluded because their execution and operational
side effects are validated separately.

Create-only configuration remains subject to its intended ownership
semantics and is not continuously overwritten by reconciliation.

Successful configuration convergence does not independently establish
the health of every installed application or infrastructure service.

## Repository distribution

The authoritative Forgejo repository distributes changes through
an automatic GitHub push mirror.

Managed hosts may synchronize from either repository according to
their existing remote configuration.

Release consistency was established by comparing commit identifiers
rather than assuming that mirror propagation had completed.

The fleet rollout preserved existing host remote configuration.

The public mirror was independently exercised during the Z270X
deployment, which synchronized to the exact accepted fleet commit.

Direct pushes to the public mirror were not required.

## Resolved canary findings

The following findings were addressed during the engineering and
canary validation phases.

| Finding | Resolution |
|---|---|
| K9s directory permissions would be relaxed during reconciliation | Introduced private source directory attributes and filesystem regression tests |
| Existing K9s installations had overlapping executable ownership | Migrated eligible installations to Mise after establishing recovery provisions |
| Repository distribution required consistent release verification | Verified authoritative and mirrored commit identifiers |
| Ineligible application configuration directories were being created | Excluded complete application configuration subtrees |
| Shared templates had inconsistent working-tree line endings | Introduced explicit LF normalization for shared ChezMoi templates |

The directory permission and application eligibility corrections
were validated through actual reconciliation against isolated
filesystem fixtures and representative live hosts.

The corrected implementation completed the subsequent fleet rollout
without requiring additional corrective application, theme, or
installer patches.

Detailed findings and regression evidence are maintained in
[Application Catalog](application-catalog.md).

## Operational boundaries

The accepted implementation preserves the following boundaries:

- Mise owns declared portable application installations.
- ChezMoi owns declared managed configuration.
- Existing user-owned configuration remains subject to its defined
  ownership policy.
- Native package management remains the responsibility of the
  operating system and bootstrap policy.
- Independently managed application exceptions retain their
  existing ownership.
- Application enrollment does not provision Kubernetes credentials
  or Docker access.
- Installation and smoke testing do not authorize privileged
  infrastructure administration.
- Production infrastructure workloads remain independently managed.

No new privilege grants were required for the fleet rollout.

Pending operating system updates and APT autoremove suggestions
were outside the scope of this initiative.

## Validation limitations

The following limitations remain applicable to the accepted fleet:

| Area | Limitation |
|---|---|
| Recovery | Actual restoration was not tested |
| Worker 01 | Predeployment recovery checkpoint was not demonstrated |
| Runtime testing | Full per-host application runtime suites were not repeated after expanded acceptance |
| Kubernetes | Live cluster integration was tested on selected eligible hosts |
| Docker | Live image inspection was tested on selected eligible hosts |
| Privileged functionality | Administrative and deliberately destructive application features were not exercised |
| Production workloads | Service-specific checks were limited to representative operational verification |
| Configuration verification | Script side effects are outside `chezmoi verify --exclude=scripts` |
| Supply chain | Comprehensive artifact verification beyond confirmed attestations remains a separate improvement |
| FreeBSD | Native FreeBSD application reconciliation remains unvalidated |

Network Doctor GitHub artifact attestation verification succeeded
during the recorded deployments.

This does not establish equivalent artifact attestation or checksum
verification for every installation backend and application.

## OPNsense scope exclusion

OPNsense is excluded from the Linux infrastructure TUI deployment.

Its existing configuration ownership and platform-specific
management policies remain unchanged.

Native FreeBSD application installation and reconciliation were
not part of the validated implementation.

OPNsense is therefore not included in the eight-host fleet
deployment denominator.

## Future operational improvements

The following items are independent follow-up opportunities rather
than blockers for the accepted fleet release:

- Exercise recovery restoration in an isolated environment.
- Standardize recovery checkpoint creation across all deployments.
- Expand artifact checksum and attestation verification policies.
- Introduce additional automated native runtime acceptance tests.
- Evaluate additional platform support independently.
- Continue staged application upgrades through representative
  AMD64 and ARM64 validation.

Future application changes must follow the established declarative
catalog, configuration ownership, Git workflow, and validation
policies.

## Final acceptance

The NovaLabs declarative application catalog and infrastructure
TUI initiative completed technical acceptance across all eight
eligible Linux hosts.

All 203 declared Mise application enrollment instances were
verified at their requested versions.

All 72 newly introduced infrastructure application enrollment
instances completed installation successfully.

Both AMD64 and ARM64 deployment paths were validated.

All eligible hosts passed applicable configuration convergence
and representative runtime acceptance checks.

The fleet rollout required no additional corrective implementation
patches after canary acceptance.

The recorded validation limitations remain explicit and do not
represent unresolved deployment failures.

**Fleet deployment status: Complete.**

**Technical acceptance status: Passed.**
