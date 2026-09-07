# Migration Ledger

Migration source: `server-dotfiles`
Migration target: `novalabs-dotfiles`

## Host profiles

| New profile | Existing profile | Current host identity | Platform | Status |
|---|---|---|---|---|
| proxmox | proxmox | nova | Debian AMD64 | migrate |
| docker | docker | docker | Debian/Ubuntu AMD64 | migrate |
| pihole | pihole | pihole, pihole2 | Debian/Raspbian AMD64 | migrate |
| ubuntulab | ubuntulab | ubuntulab, ubuntu-proxmox | Ubuntu AMD64 | migrate |
| lovelace | lovelace | lovelace | Debian ARM64 | migrate |
| worker1 | worker | k8s-worker-01 | Debian AMD64 | migrate + rename |
| zgx | zgx | zgx, zgx-40e6 | Ubuntu ARM64 | migrate |
| opnsense | opnsense | opnsense, opnsense2 | FreeBSD AMD64 | stage only |

## Migration ownership

| Component | Existing owner | New owner | Action |
|---|---|---|---|
| Bash configuration | server-dotfiles common | ChezMoi | migrate |
| Git configuration | server-dotfiles common | ChezMoi | migrate |
| bat configuration | server-dotfiles common | ChezMoi | migrate |
| btop configuration | server-dotfiles common + host theme | ChezMoi | migrate |
| Fastfetch configuration | generated host identity | ChezMoi templates/data | migrate |
| htop configuration | server-dotfiles common | ChezMoi | migrate |
| LazyDocker configuration | server-dotfiles common | ChezMoi | migrate |
| LazyGit configuration | server-dotfiles common | ChezMoi | migrate |
| lsd configuration | server-dotfiles common | ChezMoi | migrate |
| Starship configuration | generated host identity | ChezMoi templates/data | migrate |
| Superfile configuration | server-dotfiles common | ChezMoi | migrate |
| tmux configuration | server-dotfiles common | ChezMoi | migrate |
| Vim configuration | server-dotfiles common | ChezMoi | migrate |
| Portable CLI binaries | mixed package/upstream installers | Mise where appropriate | reassess |
| OS/system packages | package adapters | native package layer | preserve |
| Host detection/policy | package policy files | ChezMoi data/bootstrap | migrate |
| Old deployment engine | install.sh + scripts | ChezMoi/Mise | retire after parity |

## New common tools

- neovim
- ripgrep
- fzf
- fd
- node
- chezmoi
- usage

Existing `lsd` and `bat` remain common and will move to Mise if supported cleanly.

## Migration principles

1. Preserve existing working configuration before adding new behavior.
2. Do not regenerate existing visual identities unless required by the new architecture.
3. Forgejo is authoritative; GitHub is a mirror.
4. Linux hosts are the initial implementation target.
5. OPNsense remains staged until FreeBSD-specific behavior is tested.
6. Retire legacy bootstrap logic only after equivalent behavior is verified.

## Version policy

All tools managed by Mise use exact committed version pins.

Existing tools retain their `server-dotfiles` release versions during migration
where an explicit release pin already exists. Tools previously supplied by the
OS package manager and newly introduced tools receive an explicit version when
they are first added to Mise.

Floating selectors such as `latest`, major-only versions, and release channels
are not used in the committed fleet configuration.

Version upgrades are deliberate repository changes and are reviewed as normal
Git diffs.

## Bootstrap versions

The initial validated bootstrap toolchain is:

- Mise: 2026.8.5
- ChezMoi: 2.72.1

Mise is bootstrap infrastructure and is pinned separately from the Mise-managed
`[tools]` configuration.
