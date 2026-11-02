# Chaossynergy (repo: chaossynergy-server)
The OS is called **Chaossynergy** — full stop (Panos, 2026-11-02). As of Edition 1 it
is NOT atomic like the Bluefin-based v1 prototype: Arch base + snapper/limine snapshot
A/B rollback; atomicity may be reconsidered for a later edition.
Status: DRAFT v0.4 — both expert reviews merged; SCOPE per Panos: Edition 1 is
       SINGLE-DISK only; btrfs RAID1 deferred to Edition 2 (findings preserved in Annex A)
Date: 2026-11-02

## 0. Thesis
The new Chaossynergy is *this box, packaged*: an agent-native server OS that installs a
headless shell layer plus the full ai-lab quadlet stack, offline, on one disk; the lab
stays dormant until a post-install app finalizes it for the target's hardware.
Three principles from Chaossynergy v1 survive verbatim:
1. the substrate is sacred and dumb (appliance, not a workstation),
2. the agent is disposable (container; delete and recreate in seconds),
3. safety by construction, not policy (A/B snapshots + rollback, not discipline).
Inherited method rule: "every machine is built from the repo; a live machine is only ever
a deployment target." One production reference deployment exists (internal); its
identity details never appear in this repo.

NAMING RULE (Panos, standing): the product and everything user-visible must NEVER be
called "ryoku" — derivation/influence fine, name not. "ryoku-*" below = upstream code
being forked/ported. Fork renames: `RYOKU_*` contract -> `CHAOS_*`, installer binary ->
`chaos-install`, enablement app -> `chaos-lab` (working title), payload dir ->
`/usr/share/chaos-lab/`. Licensing: upstream installer bits are GPL-3.0 -> the fork keeps
them GPL; lab payload stays Apache-2.0 (like v1); keep the directory boundary clean
(ADR-013 includes naming + licensing).

GPU IDENTITY RULE (Panos, standing): templates, registry keys, and unit names use
GENERIC INDEXED SLOTS — `nvidia-gpu-0`, `nvidia-gpu-1`, ... — card names (5090/4070Ti)
are probe METADATA only (model/VRAM/UUID -> model sizing), never identity; ports derive
from slot index (11435+i) with services.json as single writer. Example: upstream
`llama-cpp-5090` renders as `llama-cpp-nvidia-gpu-0` on the trial box.

## 1. Inheritance audit (verified by two expert reviews, file:line)
- **Upstream distro monorepo**: archiso releng ISO (build.sh / stage-variant.sh /
  profiledef.sh / packages.x86_64); Bubble Tea TUI with layout-math + safety-gate unit
  tests; pure-bash backend, one lib file per stage (preflight, disk, luks, filesystem,
  pacstrap, mirrors, chroot, deploy, network, drivers, bootloader, aur, snapshots,
  offline), env-var contract, full dry-run; offline-repo.sh bakes the COMPLETE package
  closure into a file:// [offline] repo consumed by lib/offline.sh (verify-before-wipe,
  SigLevel=Never pacstrap -C, repo bind-mounted into chroot transactions, [offline]
  stripped from the target afterwards; integrity test exists). Boot = Limine + snapper +
  limine-snapper-sync. Services: strict 6-column manifest.tsv, validator rejects unknown
  columns; activation vocabulary boot | enable-once | conditional (system) and
  session* | on-demand (user); preserve:/condition: marker files. `..._PROFILE` is a
  package-SET selector (amd-nvidia|amd|intel|vm), not a detector; the real GPU detector
  ranks DRM cards behind a hermetic test seam (reusable) but its consumers are
  desktop-only. Release: signed pkg repo + keyring imported at install, ISO latest.json
  channel pointers, R2 retention, reusable build-iso workflow taking a variant input.
  Verified gaps: filesystem stage mkfs is single-device (line 27) and disk stage REJECTS
  multi-device btrfs as foreign (line 985); compositor env vars are required-and-abort
  (ryoku-install:149-150); the ISO live session is a cage+foot Wayland kiosk; mkinitcpio
  HOOKS are desktop-shaped (plymouth, kms, console-keys, gpu-trim); no zram on the Arch
  path; skopeo in no package list.
- **Reference machine** (this box, verified live): NVMe GPT (4 GiB ESP + LUKS2) ->
  btrfs (labeled volume; internal label withheld), subvolumes @/@home/@log/@pkg/@.snapshots,
  compress=zstd, zram swap,
  Limine — plus a SECOND identical disk joined RAID1 and Limine on both ESPs (live proof
  of the Edition-2 design; see Annex A).
- **ai-lab-quadlets** (payload, 142 files): services.json 49 services (image_digest pin,
  tier, boot, gpu, group, variant, exclusive); 10-unit boot allowlist enforced by
  policy tests (no [Install] outside allowlist, no network-online deps,
  SuccessExitStatus=143, GPU pinning rules); install gate hardcodes THIS box's two card
  names; `__GPU_*_UUID__`/`__CPUS_*__` placeholders rendered by name; gpu-arbiter.py for
  runtime arbitration; per-service service.env/keys.txt secrets (generated, never in
  repo, rotation script exists); strata-family install deliberately never starts the
  heavy first pull.
- **ai-box-restore**: 05-mkdisks.sh (the hand-written RAID1+LUKS recipe), 70-system-state
  (root config capture list), usb-copy-chain (restic two-copy); 7/~10 stages unwritten,
  no package manifest — SUBSUMED by this project.
- **chaossynergy v1**: bootc/Bluefin prototype kept as principles + ADRs + THEPATTERN
  comparison method + cosign/GHCR precedent; base moves to Arch per ADR-013.

## 2. Base decision — ADR-013
Option A (CHOSEN): Arch substrate via the ported installer pipeline (archiso + bash
backend + Limine/snapper). Option B (rejected): stay bootc/ostree — stronger immutability
but contradicts "based on this one" (reference box, offline story, shell layer all Arch).
Honest sizing (review): even Edition 1 has SIX genuinely-new mechanisms — non-desktop
contract, server variant gates, lab payload + dormancy mechanism, enablement app, offline
OCI channel, server package closure. A port with real delta, not a re-skin. Positioning
(Panos, 2026-11-02): **not atomic as of Edition 1** — no immutability claim for now;
atomicity stays an open option for later editions. Safety =
snapshot A/B rollback (snapper + limine-snapper-sync) + "services only as containers"
appliance discipline; the mutable-base boundary (what may ever be installed on the host)
is defined in the same ADR.

## 3. Architecture (Edition 1 = single disk)
- **L0 ISO**: archiso releng profile + new `server` variant (variant case in
  stage-variant.sh, validation in build.sh, variant case in offline-repo.sh — three
  gates). Headless airootfs: kiosk session staged OUT -> plain tty1/serial. [offline]
  repo carries the full server closure incl. net-new names (podman, skopeo,
  zram-generator, tailscale). OCI images baked on ISO payload partition or USB companion.
- **L1 Appliance backend** (`chaos-install`): contract EXTENSION — edition switch
  (CHAOS_EDITION=server), compositor/config-dir required vars relaxed (precedent: the
  per-variant gate pattern). Single-disk btrfs layout AS TODAY (no raid1 in E1: avoids
  the whole Annex-A surface). Fork points beyond deploy (all must be gated): chroot stage
  HOOKS -> headless line (strip plymouth; upstream already drops undeliverable hook
  names); network stage wifi carry-in -> wired/none; drivers stage gpu-mode; aur stage
  browser wiring; default browser/file-manager vars. Deploy adds
  `loginctl enable-linger <labuser>` — WITHOUT linger, the user manager, the
  podman-user-generator, and every lab unit die at boot (live-verified here: Linger=yes).
- **L2 Lab payload (dormant, NOT finalized at install)**: `*.container.in` templates +
  ai.network + baseline services.json + llama.cpp preset catalog, shipped as a SIGNED
  `chaos-lab` package through the [chaos] repo (payload-package pattern), not loose ISO
  files. DORMANCY MECHANISM (Linux review, showstopper S1 fixed): quadlet units are
  ALWAYS `generated` in is-enabled — the discriminator is the `[Install]` stanza.
  Templates MUST SHIP WITHOUT [Install]; upstream boot-tier templates carry it, so
  verbatim materialization would silently auto-start dufs/syncthing/prometheus at first
  login. Split: template (no [Install]) vs activation drop-in
  (`<name>.container.d/chaos-lab.conf` = [Install] WantedBy=default.target), or
  `podman quadlet install/rm` (podman >= 6.1, owns the bookkeeping — preferred for L3).
  Activation rows follow the existing 6-column vocabulary: `scope=user
  activation=on-demand` = dormant by reconcile design; `condition:` markers arm.
- **L3 Enablement app = post-install customization step**: `chaos-lab` TUI (own Go
  module; installerplan embedded-TSV idiom as model). Steps: probe hardware (GPU
  enumeration via the hermetic detector seam -> gpu_slots[] {index,model,vram,uuid},
  RAM, CPUs, disks) -> resolve registry (indexed placeholders, ports 11435+i, preset
  catalog sizes models to VRAM+RAM, no two-card gate) -> render `*.container` from
  templates -> generate fresh per-install secrets (never printed; rotation included) ->
  import OCI images (`skopeo copy oci-archive: containers-storage:` AS the lab user) ->
  apply activation drop-ins / `podman quadlet install` for chosen tiers -> start.
  Explicit human gate before heavy weight pulls. Idempotent; re-run on hardware change.
- **L4 Asset channel**: weights NOT on the ISO: (a) offline USB bundle + sha256 sidecars,
  (b) private-network seed from the reference server (dufs/rclone/rsync); keyed by
  preset-catalog digests.

## 4. Workstreams (Edition 1)
W1 chaos-install contract + server gates: edition switch, compositor vars relaxed,
   kiosk removal, headless HOOKS trim, linger in deploy; dry-run fixtures per upstream
   test conventions (tests/ fixtures at repo root).
W2 offline closure: offline-repo.sh `server` variant case + added names (podman, skopeo,
   zram-generator, tailscale); CI pre-publish step resolving the EXACT server set
   against the baked db (partial closure otherwise fails AFTER partitioning); keyring
   packages (archlinux + chaos) inside the closure — offline path never touches the live
   keyring, re-verification happens on the target's first online -Syu.
W3 OCI image channel: bake `skopeo copy --preserve-digests docker://img@sha256:PIN
   oci-archive:`; import as lab user via skopeo (NOT containers-storage via podman load:
   podman save/load BREAKS digest pins — quadlet `Image=name@sha256:` then fails to
   resolve offline; upstream maintainer guidance + issue #27323). Verify with
   `skopeo inspect --raw containers-storage:img | sha256sum` == pin (manifest digest;
   never image ID — config digest != manifest digest). Snag: `--preserve-digests --all`
   fails on zstd-annotated indexes -> single-platform bake (--override-os/-arch).
W4 dormancy: templates without [Install]; activation = drop-in or `podman quadlet
   install`; policy test asserts after install: NO lab unit in
   `/run/user/$uid/systemd/generator/default.target.wants` AND `is-active=inactive` for
   every lab unit (is-enabled is useless — always `generated`); after chaos-lab render,
   every unit provably derives from template+probe; per-target tier set materializes the
   boot allowlist instead of a baked 10-unit list.
W5 chaos-lab TUI (probe/resolve/render/secrets/import/enable + weight gate) and GPU-slot
   registry portability (services.json gpu_slots, indexed placeholders, relaxed install
   gate) — biggest true redesign; trial box with ONE small GPU is the falsifying case.
W6 identity & release: repo + name (open Q), GH Actions ISO matrix via reusable variant
   workflow, [chaos] signed pkg repo + keyring, ISO latest.json pointers, cosign on OCI
   images (v1 precedent); precedent exists for pacman repos + ISO channels, OCI/skopeo
   machinery is net-new. ADRs: 013 base/naming/licensing, 014 dormancy mechanism,
   015 asset channel + OCI, 016 gpu-slot registry.
W7 verification gates: `CHAOS_DRYRUN` in CI; QEMU single-disk install -> boot ->
   snapper/limine rollback -> chaos-lab full cycle (probe with 0/1 GPU via vm profile);
   W3 digest equality on-metal trial with measurement protocol ("mine, today, against
   the live service").

## 5. Trial on the small-GPU / big-RAM machine
Trial machine: owner-designated, name withheld from this repo. E1 needs only: UEFI +
one disk. RAM governs model choice (big IQ3 weights need RAM >= weights+KV; otherwise
preset-catalog model sized to VRAM+RAM). Falsifying case for W5: exactly one GPU slot ->
no coder/maya slots rendered; ports from index. Matrix: VM dry-run -> VM install ->
on-metal install -> full measurement run (data for chapter 66).

## 6. Milestones
M0 spike: contract decision (edition switch) + chaos-install dry-run completes server
M1 server-variant ISO: offline install of headless Arch; Limine/snapper rollback proven
M2 chaos-lab payload package + dormancy policy test green (W4)
M3 chaos-lab TUI end-to-end in VM (probe -> render -> enable -> health)
M4 on-metal trial (machine TBD), full measurement run
M5 release pipeline + ISO publication + Philosophical Developer ch. 66 written during
   the build (voice: Panos's call; Sisyphus arc fits the co-builder build-out)
E2: Annex A (multi-disk RAID1) — scheduled when a >=2-disk target is chosen.

## 7. Open questions (need Panos)
0. Later-edition stance on atomicity (bootc/ostree or A/B partition scheme) — parked,
   not rejected; revisit after E1 proves the appliance model.
1. Trial machine identity + specs (GPU model, RAM)? (name stays private)
2. ~~Repo home & name~~ RESOLVED (Panos, 2026-11-02): fresh repo
   **github.com/dark5un/chaossynergy-server** (public); ADR numbering continues from v1
   (001-012 inherited). Still open: audit inherited names in binary/--help/error
   strings/URLs during the port.
3. Weights channel: USB primary + tailnet fallback (recommended) — confirm.
4. Host-policy ADR: post-deploy pacman from official + signed [chaos] only, AUR-free?
5. E2 trigger: Annex A scheduling (needs the >=2-disk target decision anyway).

## Annex A — Edition 2: multi-disk btrfs RAID1 (Linux-review findings, preserved)
Proven by the live reference machine; upstream repo has ZERO raid support (mkfs
single-device; disk stage rejects multi-device as foreign). Full touch-list for E2:
1. `mkfs.btrfs -d raid1 -m raid1 dev1 dev2` at mkfs (or device add + balance); N>=3 ->
   `-m raid1c3` (kernel 5.5+); NO 2-disk single-parity exists; NEVER raid5/6 for
   metadata (man 5 btrfs).
2. Degraded boot is NOT automatic: `rootflags=...,degraded` on kernel cmdline AND
   `degraded` in fstab (root-on-array requirement); after disk returns, `btrfs balance`
   (rw degraded rewrites new chunks as SINGLE). Cmdline builder is the touch point.
3. btrfs membership is by FS UUID (one fstab UUID line suffices); multi-device in initrd
   needs udev OR systemd hook (already has udev — do NOT append systemd blindly;
   replacing udev with systemd changes btrfs module expectations).
4. PARTLABEL collisions: per-disk unique labels (chaos-1/chaos-2); upstream leftover/
   reclaim matchers compare exact partlabels -> collision = second disk seen as foreign
   debris -> WIPE RISK. Both ESPs share vfat label BOOT -> address ESPs by UUID only.
5. Dual-ESP Limine: the entry tool owns ESP_PATH=/boot only -> ESP2 ROTS on every kernel
   update unless a mirror pacman hook (precedent exists: the alongside stage hook) rsyncs
   limine.conf + EFI files + kernels + initramfs to ESP2; two efibootmgr entries (per
   disk), removable fallback on both. Requires plural disk var (array) first.
6. LUKS: one LUKS per disk, btrfs joins the two dm nodes (the reference deployment proves this);
   upstream opens a single `root` mapper.
7. fstab/boot single-device assumptions + swapfile BAN on multi-device (single-device
   swapfile + data-single only; zram for raid) + TUI layout-math constants mirror backend.
8. Tests: QEMU 2 disks — raid1 mount; degraded boot after pulling one; ESP2 sync across
   a kernel-update cycle; alongside/reclaim paths refuse raid1 disks.

## 8. Review log
- [x] Payload inventory — merged v0.2
- [x] Ryoku-codebase expert review (13 claims, file:line): 'unchanged contract' false;
      6-col manifest vocabulary adopted; variant = 3 gates; kiosk removal; OCI machinery
      net-new; payload ships as signed package — merged v0.3
- [x] Linux-systems expert review (5 topics, 15 edits, 5 showstoppers): dormancy =
      [Install] stanza (S1 -> fixed in W4); linger required (-> L1); rootflags=degraded,
      ESP2 rot, partlabel collision, LUKS-per-disk (S2-S5 -> DEFERRED with single-disk
      scope, preserved in Annex A); skopeo --preserve-digests + podman-load ban + digest
      verification (-> W3); offline keyring timing + closure-resolution CI check +
      hook-provided-by-package mkinitcpio pitfall (-> W1/W2) — merged v0.4
