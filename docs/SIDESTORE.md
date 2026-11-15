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
  (build source `c23583282c3f21cbd70d215822037c5cd17c37ca`). The run succeeded;
  its IPA SHA-256 is
  `516c23afd379f3bb4651273be99ec42db17f3eac999a3594890e232891d3c6bc`.
  Device installation failed with a lock-screen extension bundle-ID mismatch,
  including after the user retried removing extensions in SideStore.
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
- A hosted macOS build succeeded. Device installation failed as recorded above;
  launch, login, notifications, and tweak behavior remain unverified.

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

## Extension-removal repair

The built IPA contained seven extensions in `PlugIns/` and an eighth in
`Extensions/InstagramExtensionLockScreenCamera.appex`. SideStore's prompt listed
seven; the user-reported repeated failure named the eighth. Its bundle ID lacked
the signing suffix that SideStore appended to the main bundle ID.

`scripts/strip_extensions.py` removes every embedded `.appex` tree from either
location without modifying retained entry contents. `build.sh` now applies it
after ipapatch for sideload builds, and the workflow rejects leftover extensions.
The regression fixture covers both locations, retained resources, and unchanged
input. The `--check` command failed on the actual first-build IPA, passed on the
repaired IPA, and every retained entry was compared byte-for-byte by SHA-256.
On-device signing and installation remain the final verification step.

Replacement: `output/SCInsta-no-extensions.ipa`, 300,422,061 bytes, SHA-256
`47774f06c8d429cafbe17a1f43975bb7530ac65c24efd4db7ddb5f71dda7d277`.
This is a repack of the successful first build, not a new tweak compilation.
Main executable and all tweak libraries are unchanged. Widgets, sharing into
Instagram, lock-screen camera and notification extensions have been removed.
Draft destination: `scinsta-455-no-extensions-1`; keep unpublished.

## Launch crash and helper repair trial

The user reports the extension-free IPA installs, then exits immediately on
launch. The supplied crash report identifies iPhone OS 27.0.1 (24A446),
SIGABRT from an Objective-C exception. The exception trace passes through
`NSURL URLByAppendingPathComponent:`, `zxPluginsInject.dylib` at offset 18664,
and `IGFamilyLegacyAppGroupContainerURL`. All required injected libraries and
CydiaSubstrate are present and loaded; this is not a missing-library failure.

The pinned helper's `containerURLForSecurityApplicationGroupIdentifier:` hook
appends its argument to an emulated app-group URL without validating it. The
trace and source point to a nil group identifier. This remains an inference
until device testing of the repair. The helper now uses a stable local fallback
identifier for nil/empty requests, preserving the original handling of named
groups. Patch: `patches/zxPluginsInject-nil-group.patch`; upstream source revision:
`d849cd510f9a925d692941b8d43c5efe1ca56649` (asdfzxcvbn/zxPluginsInject).

The hosted build first compiles a Foundation harness from the actual hook
method body, requires the unpatched nil case to throw, then applies the patch
and requires nil/empty/named cases to pass. It compiles the patched helper and
passes it through ipapatch's custom `--dylib` option. Extension removal remains
enabled. Linux preparation verified patch applicability and workflow/script
syntax; the macOS harness and build must still run. Device launch remains the
final feedback loop, and Instagram 455 feature compatibility is unverified.

The private crash attachment is not copied into Git; this note records only
the diagnostic stack and OS version.

Helper-repair trial run: https://github.com/danzola01/SCInsta/actions/runs/43664402825
Source: `0d3346f708d461bce4b755afadb4216d82f5a80a`. Failed before testing
the patch: the harness used Objective-C instead of Objective-C++ for upstream
C++ condition declarations. Corrected to `.mm` and `clang++`.

### Successful helper-repair build

- Run: https://github.com/danzola01/SCInsta/actions/runs/43664553515
- Source: `6cb53222f73f4d5b0acf4543f219df6ad69a516a`.
- Hosted macOS harness reproduced `NSInvalidArgumentException` for the original
  nil-group call, then passed patched nil/empty/named cases. Helper compilation,
  IPA build, decryption/identity/library checks and extension-free check passed.
- Output draft: `scinsta-ipa43664553515-1`, verified unpublished.
- Owner page: https://github.com/danzola01/SCInsta/releases/tag/untagged-37bdf5e3be6f5a18e0f8
- Asset: `SCInsta.ipa`, 291,809,779 bytes, remote SHA-256
  `25089c7017b32525ba784f68ecae1d0947f307acaf71c7549fb377238928d2a8`.
- Install this new asset over the existing SCInsta using the same signing account.
  Device launch/login and tweak behavior remain unverified; request a fresh
  crash report if launch still fails. Do not treat the harness as device proof.

Device update: user reports the helper-repair build opens successfully. This
confirms launch by user report; login, feature controls and signing refresh
have not been separately verified. Settings access is a long press on the
profile menu button; recommended feature selection is listed above.

## Settings access repair trial

After launch/login, the user reports that holding the profile menu does not open
settings on Instagram 455. The old hook targets `IGBadgedNavigationButton` and
only attaches if that view has no gesture recognizers; the screenshot does not
identify the actual class or recognizers, so the precise private-UI mismatch is
unverified. A new public-UIKit `UIWindow.becomeKeyWindow` hook adds one two-finger,
one-second long press per normal-level window. It leaves the old shortcut in
place and avoids duplicate registration with an associated object.

The settings presenter now walks to the already-presented controller and refuses
to stack duplicate SCInsta settings navigation controllers. Onboarding describes
the two-finger shortcut. No feature preferences were changed. Hosted compilation
will validate the UIKit code; actual gesture delivery and feature behavior need
user testing. The existing device report is the failing UI feedback loop; no
local iOS runtime is available for a UI regression test.

Settings-access trial build succeeded:
https://github.com/danzola01/SCInsta/actions/runs/43665728372
(source `e041ed310d7b06d89035e096ed13804692b61e33`). UIKit compilation, helper
regression harness and IPA checks passed; gesture handling awaits device testing.
Unpublished draft: `scinsta-ipa43665728372-1`.
Owner page: https://github.com/danzola01/SCInsta/releases/tag/untagged-74e9e73f8e4794f3f3c7
Asset: `SCInsta.ipa`, 291,811,120 bytes. Remote SHA-256:
`df4e588f20187006ebc475f762bb3394538999e096aa551232d87cc669f36f00`.
Install over the previous app, then hold two fingers still for one second on
a normal app screen and verify the SCInsta settings sheet opens.

## Session persistence and beta-prompt trial

The user reports the settings-access build is working, but swiping the app away
and reopening requires login again. This is an ordinary force quit, not an
unprompted crash. They also report a recurring beta-update prompt. The attached
image was the earlier Analytics Logs screen, so the exact prompt is not captured.

Candidates considered: automatic cache cleanup, keychain access-group routing,
and emulated app-group persistence. No local iOS runtime or signed device session
is available to reproduce the logout here. The user-device feedback loop is:
install over the existing app, log in, swipe away, reopen, repeat twice; record
whether password entry or only a saved-account Continue action is required and
whether the beta prompt recurs. Do not mark session persistence fixed from a
successful compilation or archive check.

Primary reference discovered after the beta clue:
https://github.com/Mihir-A/Unscroll/blob/01c5ed9b0678ae233dcdc81033e4500e6eac30e6/runtime_fix/UnscrollRuntimeFix.m
It covers both forced-quit logouts and TestFlight misclassification. The base IPA
contains all three targeted keychain wrapper class names and receipt selectors.
`SessionCompatibility.xm` adapts just the wrapper access-group and receipt hooks.
It probes the access group available to the current signature using a metadata
item; it does not request or log credential data. If discovery fails, the wrapper
keeps its original behavior. Only the main bundle's sandbox receipt URL is mapped
to a normal receipt path. This does not create a receipt or change purchase data.
MIT attribution is retained under `licenses/IGSideloadFix-MIT.txt`.

The first trial changes these two related compatibility behaviors only. Existing
app-group paths, nil-group fallback, startup cache cleanup, app identity and
feature preferences are preserved. Cache deletion was a candidate, not a proven
cause; it remains a separate experiment if the targeted helper repair fails.
Native compilation and existing helper/IPA checks will run on hosted macOS.
Session persistence and beta-prompt behavior require user-device verification.

Session-compatibility trial build succeeded:
https://github.com/danzola01/SCInsta/actions/runs/43687216576
Source: `dfdd00f5dc6a2adfe2a48bf0d31fd75e39d904ae`.
Hosted compilation, existing nil-group regression harness, IPA encryption/identity/
library checks and extension-free check passed. No device session test has run.
Unpublished draft: `scinsta-ipa43687216576-1`.
Owner page: https://github.com/danzola01/SCInsta/releases/tag/untagged-81d7a86e2b6929520cf2
Asset: `SCInsta.ipa`, 291,813,522 bytes, remote SHA-256:
`1ed1f7f991b4e9120c8a9c5f1a884f5568ca6351a1683e64d3c59aed0a41b8b4`.
Install over the current app. User should log in once if necessary, then perform
two force-quit/reopen cycles and report login persistence and beta-prompt behavior.
