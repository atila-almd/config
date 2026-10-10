# Public release audit (2026-10-10)

The audit ran before source changes. It covered the working tree and the complete
local Git object database, including branch/tag/checkpoint refs, reflogs and
unreachable commits. Git history remained private and was not rewritten.

- Working tree: 240 tracked files, 19 untracked files, 259 files scanned.
- Git: 257 commits reachable through refs, one additional reflog commit and
  nine additional unreachable commits; 1,112 unique blobs scanned.
- Gitleaks v8.30.1 (official release, checksum verified): zero findings in
  history, working tree and complete blob scans.
- Manual/pattern review: private/public key material, tokens, credentials,
  emails, usernames, home paths, hostnames, IPv4/IPv6, Wi-Fi state, serials,
  MACs and UUIDs. Two historical screenshots were also reviewed.

No credential, private SSH/GPG key, saved Wi-Fi network, machine serial or
unique host identity was found. Personal author/committer emails occurred in
old metadata. Checkpoint history also retained private Git identity mappings,
a temporary access helper containing a public SSH key and VM address, and
screenshots. Three current documents embedded personal evidence/home paths.
Those findings make the old full history unsuitable for this public release,
even though Gitleaks found no credentials.

The [complete tracked-file classification](pre-release-tracked-files.tsv) is a
snapshot of the audited input. All 240 files were Managed Configuration or its
supporting source/tests/docs; no complete Local State file was tracked in the
current index. The three documents with embedded Local State are identified
in the inventory. Historical identities and access evidence are excluded from
the public history; personal document paths and test usernames are sanitized.

The owner selected fresh sanitized history, MIT, the existing public GitHub
noreply commit identity, and the same physical desktop on a secondary SSD.
The release uses a separate repository with a new root commit, preserving the
original checkout, dirty work and private history. An app-owned T3 orchestration checkpoint ref was added during the session;
existing refs and source HEAD stayed unchanged. During preparation, no force
push, remote visibility change or disk operation was performed. Hardware model names in the
approved profile are Managed Configuration; unique identifiers are excluded.

Local State locations, examples and bootstrap behavior are owned by
[the operator guide](../../README.md#local-state-and-reruns). Status/evidence are
owned by `components.tsv` and rendered into that guide. Audit artifacts with
private candidate strings remain outside the release tree.

Before publication, rescan both the final tree and new history with Gitleaks,
review staged paths/metadata, and run repository checks. The original history
must not be uploaded as extra refs, tags, bundles or an imported `.git` directory.

## Owner-selected remote handoff

The owner selected the existing `atila-almd/config` remote and requested
unchanged visibility. Only `main` receives sanitized history. The existing
`quickshell-shell` branch contains all of old `main` and is retained for recovery;
its legacy personal metadata remains private. A complete pre-update mirror and
verified Git bundle are stored outside source. The
[operator recovery notes](../../README.md#history-and-recovery) own access to
old history and the constraint before a future public visibility change.
