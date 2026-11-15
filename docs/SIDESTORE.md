# Personal SCInsta build

## Current state

- Personal source fork: https://github.com/danzola01/SCInsta
- Personal/default branch: `sidestore`; upstream: https://github.com/SoCuul/SCInsta.
- Initial upstream revision: `7bb71807190518ed45d21c716704c38e45a19253`.
- Upstream README lists SCInsta v1.1.1 as tested on Instagram 418.2.0.
- Target reported for the existing YouMod setup: iPhone 17 / iOS 27.0.
- Supplied base: Instagram 455.0.0 (1109782713), minimum iOS 16.3,
  358,943,896 bytes. SHA-256:
  `9b739ddad2bdb7368972d612eaac350213ffee78d41e4b4296ddacaac61d5dc3`.
- Archive CRC passed; all 15 detected Mach-O executables have `cryptid: 0`.
  No dylibs or provisioning profiles were detected. The earlier 879-byte file
  was a download error and is not used. Inspection does not establish provenance.
- Base draft tag: `base-instagram-455.0.0`. This is a trial with a version newer
  than upstream lists as tested; compatibility and device behavior are unverified.
- Remote base asset digest and size match the local inspection; the release
  remains an unpublished draft.
- First trial dispatched: https://github.com/danzola01/SCInsta/actions/runs/43661971200
  (build source `c23583282c3f21cbd70d215822037c5cd17c37ca`). The run was
  in progress when recorded; no successful output or device result yet.
- App name: `SCInsta`; bundle ID: `com.danzola.scinsta`, for installation beside
  App Store Instagram. Keep this identity and SideStore signing account stable
  across updates. Push notifications need device verification.

## First-build settings

Configure these in SCInsta settings after installation:

- General: Hide ads; Hide Meta AI.
- Feed: No suggested posts; No suggested for you; No suggested reels;
  No suggested threads posts.
- Navigation: Hide reels tab (requires restart).
- Saving: Download feed posts; Download reels; Download stories;
  Save profile picture.

Leave other preferences at upstream defaults for the initial trial. Hiding the
Reels tab still allows opening a shared Reel. A separate switch disables
scrolling between Reels. Privacy and message-retention features are optional.
No preference defaults have been changed in source.

## Supply the base IPA later

Prefer a plain decrypted Instagram 418.2.0 IPA for the initial trial. Do not
assume an arbitrary newer version is compatible. Save it under `packages/`;
all `*.ipa` files are ignored by Git.

Run commands from this app's directory. Inspect before upload:

```bash
mkdir -p output
python3 scripts/inspect_ipa.py packages/com.burbn.instagram.ipa --require-decrypted --output output/base-ipa.json
```

Review the version, bundle ID (`com.burbn.instagram`), minimum OS, SHA-256,
encryption metadata, and existing libraries. Metadata inspection does not
establish provenance or device compatibility. Create an unpublished base release
and upload with authenticated GitHub access:

```bash
gh release create base-instagram-418.2.0 packages/com.burbn.instagram.ipa --repo danzola01/SCInsta --target sidestore --draft --title 'Personal Instagram base 418.2.0' --notes 'Keep unpublished.'
```

If the supplied version differs, choose a matching tag and reassess compatibility.
Set `ipa_release` and `ipa_sha256` in `config/sidestore-inputs.json` to the tag
and inspected hash. These now select the inspected 455.0.0 base.
Never put credentials or signed download URLs in this file.

## Build and retrieve

```bash
bash scripts/build_ipa.sh --dry-run
bash scripts/build_ipa.sh
gh run list --repo danzola01/SCInsta --workflow buildapp.yml --branch sidestore
```

The dispatcher refuses missing inputs. The workflow runs only from this fork's
`sidestore` branch, requires exactly one IPA in an unpublished base release,
verifies its SHA-256 and encryption metadata, and builds on hosted macOS using
upstream's Theos, cyan, ipapatch, and Logos compatibility pin. It preserves
upstream FLEX dependencies. Personal identity options are passed to cyan.

The workflow validates output encryption metadata, bundle ID, and expected
library files, and creates only an unpublished output draft tagged
`scinsta-ipa<RUN_ID>-<RUN_ATTEMPT>`. It does not upload IPA Actions artifacts.
Library-file checks do not establish that hooks will function on the device.
Before installation, also inspect injected load commands as in YouMod's first
build. Record the run URL, source revision, draft tag, and output hash here.

Download `SCInsta.ipa` with authenticated `gh release download` or the draft's
owner-only GitHub page. Inspect the downloaded hash against `built-ipa.json`,
then install through the existing SideStore setup. Keep releases unpublished.

## Validation completed during preparation

- Workflow YAML parsed; workflow shell blocks and build scripts passed `bash -n`.
- Synthetic IPA checks accepted unencrypted executable metadata and rejected
  encrypted executable metadata and an incorrect expected hash.
- Dispatcher rejected blank saved inputs and generated a valid payload with
  fixture inputs in dry-run mode; no workflow dispatch was made.
- A full macOS build, signing, login, notifications, and device behavior remain
  unverified until the base IPA is supplied.

## Device acceptance and updates

Have the user verify launch/login, feed and Story loading, ads and suggestions
hidden, Reels tab hidden after restart, shared Reel opening, downloads to Photos,
DMs, notification behavior, and SideStore refresh. Record results as user reports.

For updates, inspect upstream changes and merge into `sidestore`, preserving the
personal workflow. Reuse the inspected base while supported; a new base requires
fresh inspection and a new unpublished draft release. Rebuild and install over
the existing app with the same identity. Signing refresh does not rebuild it.

Keep app-specific configuration, artifacts, and notes here. Never commit IPAs,
signing material, credentials, or signed URLs. Commit app changes here before
updating the parent submodule revision, and ensure the referenced commit is on
the app remote before pushing the parent. Never publish proprietary IPA releases.
