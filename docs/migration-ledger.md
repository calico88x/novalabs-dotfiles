# Migration Ledger

Migration source: `server-dotfiles`
Migration target: `novalabs-dotfiles`

This document records the migration decisions and current parity state. It is historical and operational context rather than the primary usage guide. See the repository [`README.md`](../README.md) for day-to-day operation.

## Current status

Seven Linux profiles have completed migration to ChezMoi + Mise.

OPNsense remains deliberately stage-only pending FreeBSD-specific validation.

| New profile | Legacy profile | Current host identity | Platform | Status |
|---|---|---|---|---|
| `proxmox` | `proxmox` | `nova` | Debian AMD64 | migrated |
| `docker` | `docker` | `docker` | Debian/Ubuntu AMD64 | migrated |
| `pihole` | `pihole` | `pihole`, `pihole2` | Debian/Raspbian AMD64 | migrated |
| `ubuntulab` | `ubuntulab` | `ubuntulab`, `ubuntu-proxmox` | Ubuntu AMD64 | migrated |
| `lovelace` | `lovelace` | `lovelace` | Debian ARM64 | migrated |
| `worker1` | `worker` | `k8s-worker-01` | Debian AMD64 | migrated + renamed |
| `zgx` | `zgx` | `zgx`, `zgx-40e6` | Ubuntu ARM64 | migrated |
| `opnsense` | `opnsense` | `opnsense`, `opnsense2` | FreeBSD AMD64 | stage-only / pending |

## Migration ownership

| Component | Legacy owner | Current owner | State |
|---|---|---|---|
| Bash configuration | `server-dotfiles` common | ChezMoi modifier + managed Bash modules | migrated |
| Git configuration | `server-dotfiles` common | ChezMoi modifier + managed shared include | migrated |
| bat configuration | `server-dotfiles` common | ChezMoi | migrated |
| btop configuration | common config + host theme | ChezMoi; writable config preserved | migrated |
| Fastfetch configuration | generated host identity | ChezMoi per-profile templates | migrated |
| htop configuration | `server-dotfiles` common | ChezMoi | migrated |
| LazyDocker configuration | `server-dotfiles` common | ChezMoi on Docker-role hosts | migrated |
| LazyGit configuration | `server-dotfiles` common | ChezMoi | migrated |
| lsd configuration | `server-dotfiles` common | ChezMoi | migrated |
| Starship configuration | generated host identity | ChezMoi per-profile templates | migrated |
| Superfile configuration | `server-dotfiles` common | ChezMoi | migrated |
| tmux configuration | `server-dotfiles` common | ChezMoi | migrated |
| Vim configuration | `server-dotfiles` common | ChezMoi | migrated |
| Portable CLI binaries | mixed package/upstream installers | Mise with exact pins | migrated |
| OS/system packages | package adapters | native package layer | preserved |
| Host detection/policy | package policy files | ChezMoi data + bootstrap validator | migrated |
| Docker engine | mixed host/platform ownership | external on Docker LXC, UbuntuLab and ZGX | preserved externally |
| Legacy deployment engine | `server-dotfiles` install/scripts | ChezMoi + Mise + new `install.sh` | replaced for Linux profiles |

## Portable tool baseline

The current common Mise configuration uses exact pins.

| Tool | Version | Notes |
|---|---:|---|
| bat | 0.26.1 | common |
| ChezMoi | 2.72.1 | common; also bootstrap-pinned |
| Fastfetch | 2.68.1 | common |
| fd | 10.5.0 | common |
| fzf | 0.74.3 | common |
| LazyGit | 0.64.1 | common |
| lsd | 1.2.0 | common |
| Neovim | 0.12.5 | common |
| Node | 26.8.1 | common |
| ripgrep | 15.2.0 | common |
| Starship | 1.26.0 | common |
| Superfile | 1.6.0 | common |
| usage | 6.8.0 | common |
| btop | 1.4.7 | all managed Linux profiles except ZGX |
| LazyDocker | 0.25.2 | Docker LXC, ZGX and UbuntuLab when Docker is enabled |

## Native package baseline

The Debian-family bootstrap currently converges:

```text
ca-certificates
curl
git
gzip
libatomic1
htop
openssh-server
procps
sudo
tar
tmux
vim
```

`libatomic1` was added after Node failed to start on Pi-hole without `libatomic.so.1`.

## Host-specific decisions

### Proxmox

- Profile: `proxmox`
- Hostname: `nova`
- `/etc/pve` is an additional identity marker.
- Docker is not part of the profile.
- Migration completed and runtime references to `server-dotfiles` were removed.

### Docker LXC

- Profile: `docker`
- Docker is distribution-owned and treated as `external`.
- Bootstrap requires an existing usable Docker runtime.
- NovaLabs does not install, upgrade, remove or configure the Docker engine.
- LazyDocker is managed by Mise/ChezMoi.

### Pi-hole

- Profile: `pihole`
- Accepts hostnames `pihole` and `pihole2`.
- `libatomic1` became part of the baseline after the initial Node 26.8.1 install exposed the missing runtime dependency.
- Docker is not part of the profile.

### UbuntuLab

- Profile: `ubuntulab`
- Accepts `ubuntulab` and `ubuntu-proxmox`.
- Docker tooling is optional at enrollment.
- With Docker enabled, the existing Docker CE installation is `optional-external`.
- LazyDocker is managed only when Docker tooling is enabled.
- Personal Git identity remains host-local outside the managed Git include.

### Lovelace

- Profile: `lovelace`
- Debian ARM64.
- Uses containerd rather than Docker.
- Portable tools are installed through the ARM64 Mise backends.

### Worker node

- Legacy profile `worker` was intentionally renamed to `worker1`.
- Actual hostname remains `k8s-worker-01`.
- Debian AMD64.
- Uses containerd rather than Docker.

### ZGX

- Profile: `zgx`
- Ubuntu ARM64 / NVIDIA DGX Spark platform.
- Docker CE and NVIDIA container integration are supplied by NVIDIA platform repositories and are treated as `external`.
- Bootstrap validates Docker but does not manage it.
- LazyDocker is managed through Mise.
- ZGX retains a custom `/usr/local/bin/btop` built with GPU support.
- The generic Mise btop entry is excluded for ZGX.
- Existing `btop.conf` contents are preserved.
- ZGX Starship retains the Python and Conda prompt modules.

### OPNsense

- Profile: `opnsense`
- FreeBSD AMD64.
- Current mutation policy is `stage-only`.
- SSH is GUI-managed.
- The generic bootstrap detects FreeBSD and exits without mutation.
- FreeBSD-specific package/bootstrap behavior has not yet been validated.

## Configuration parity decisions

### Bash

The old Bash modules were migrated, but NovaLabs does not replace the complete user `.bashrc`.

A ChezMoi modifier owns only the NovaLabs managed block.

Mise is activated before aliases and Starship initialization so managed tools resolve correctly in fresh shells.

### Git

The shared Git defaults were migrated to:

```text
~/.config/novalab/git/config
```

A ChezMoi modifier manages only the shared include block in `~/.gitconfig`.

Personal name, email, credentials and other local Git settings remain outside repository ownership.

### btop

The existing writable `btop.conf` behavior was preserved.

`create_btop.conf` seeds a missing config but does not replace an existing regular file.

Legacy config symlinks are converted to writable regular files by the migration script.

The NovaLabs theme remains managed.

ZGX keeps its platform-specific GPU-aware btop binary.

### Fastfetch

Legacy per-host identities were copied into ChezMoi templates with parity preserved.

### Starship

Legacy per-host prompt definitions were copied into ChezMoi templates with parity preserved.

ZGX retains Python and Conda modules.

The worker profile was renamed to `worker1`, while its existing internal Starship palette name was retained for parity.

### LazyDocker

LazyDocker configuration is rendered only for:

- Docker LXC
- ZGX
- UbuntuLab when optional Docker support is enabled

The Docker engine itself remains externally owned on all three.

## Permission model

ChezMoi uses:

```toml
umask = 0o022
```

The source tree uses `private_dot_config` so `~/.config` remains private.

Typical resulting permissions:

```text
~/.config                         0700
ordinary config subdirectories    0755
managed config files              0644
Superfile private directories     0700
```

The migration deliberately avoided inheriting host `umask 0002`, which had initially produced group-writable files and directories.

## Bootstrap safety

The new bootstrap is preview-first.

```bash
./install.sh
```

makes no changes.

Mutation requires:

```bash
./install.sh --apply
```

Safety behavior includes:

- refusing root execution
- pinning Mise and ChezMoi bootstrap versions
- running host validation before `sudo` or package mutation
- validating hostname/marker, kernel, OS ID and architecture
- requiring externally owned Docker to already exist and be usable
- refusing generic FreeBSD/OPNsense mutation
- converging native Debian-family packages
- applying ChezMoi
- installing the exact Mise toolchain

## Version policy

All Mise-managed tools use exact committed version pins.

Floating selectors such as:

```text
latest
major-only versions
release channels
```

are not used in fleet configuration.

Version upgrades are deliberate repository changes and should appear as normal Git diffs.

Bootstrap infrastructure is pinned separately:

- Mise: `2026.8.5`
- ChezMoi: `2.72.1`

## Repository topology

Forgejo is authoritative.

GitHub is a public mirror used for external visibility and for hosts that do not yet have Forgejo SSH access.

Authoring workflow:

```powershell
git push origin main
git push github main
```

## Remaining migration work

The Linux fleet has reached runtime parity with the new repository.

Remaining work before the old repository can be considered fully retired:

1. inspect OPNsense/FreeBSD behavior
2. decide whether OPNsense remains stage-only or receives a dedicated FreeBSD bootstrap path
3. validate any OPNsense-specific configuration without interfering with GUI-managed system state
4. perform final documentation and architecture cleanup
5. retire `server-dotfiles` only after the OPNsense decision is complete

Until then, `server-dotfiles` remains a reference and rollback source rather than an active runtime dependency on migrated Linux hosts.
