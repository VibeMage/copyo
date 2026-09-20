# Copyo

[简体中文](README.md)

Copyo (formerly Paster) is an open-source clipboard manager for macOS: it lives in the menu bar, `⇧⌘V` brings up a card panel at the bottom of the screen, and you search your history as you type.
Data lives on this Mac (`~/Library/Application Support/Copyo/`) and syncing is off by default; there are no third-party SDKs, no analytics and no crash reporting, which makes it a fit for workplaces that do not allow third-party closed-source tools.

## Features

- **Clipboard history**: records what you copy in the background — plain text, rich text, links, colors (`#RRGGBB`), images, files
- **Slide-up panel**: press `⇧⌘V` and a card panel slides up from the bottom of the screen, showing your history as a horizontal flow of cards
- **Search as you type**: once the panel is open, just start typing to filter; searches content, file names and the source app
- **Keyboard first**: `← →` to navigate, `↩` to copy and return to the previous app, `⌥↩` to copy as plain text, `Space` to preview, `⌘⌫` to delete, `Esc` to close
- **Pinboards**: pin the clips you use often into groups of your own; history-limit cleanup never touches them
- **Source app badge**: each card's header shows the icon and accent color of the app the clip came from (the average color of that app's icon)
- **Drag and drop**: drag a card straight out into any app
- **Privacy**: content that password managers and the like mark as Concealed/Transient is skipped automatically; you can also ignore specific apps by bundle ID
- **Sync (optional, pick one of three)**: Off / Folder / iCloud. The folder option writes your history and Pinboards out as snapshots into iCloud Drive
  or any directory all of your devices can read and write (a company NAS, another cloud-sync folder, and so on), and **does not propagate deletions** — an entry you delete on one Mac
  stays on your other Macs. The iCloud option syncs through your own iCloud private database, where additions, edits and deletions all take effect, so **a deletion disappears from every device at once**.
  Either way the data only ever passes through storage you own. Sync is off by default, so Copyo can stay completely offline in a corporate environment
- **Custom shortcut**: `⇧⌘V` by default; record any key combination in Settings
- **History limit**: 100/300/500/1000/unlimited; past the limit, the oldest unpinned entries are cleaned up automatically
- **Launch at login**, plain-text mode and other settings
- **Three languages**: English, Simplified Chinese and French, following the system language, built on a String Catalog

## Installation

The Mac App Store build is back in review under the name Copyo (the old Paster record was taken down and deleted). The new link will go here once it is approved.

For now, grab the DMG from [Releases](https://github.com/VibeMage/copyo/releases), open it and drag Copyo
into Applications. Official releases are signed with a Developer ID and notarized by Apple, so a double-click is all it takes —
you only get the standard "app downloaded from the Internet" confirmation dialog the first time.

## Building from source

Requires Xcode 16+ and macOS 14+.

```bash
git clone <repo-url> && cd copyo
xcodebuild -project Copyo.xcodeproj -scheme Copyo -configuration Release -derivedDataPath build build
open build/Build/Products/Release/Copyo.app   # or copy it to /Applications
```

You can also just open `Copyo.xcodeproj` in Xcode and run it (⌘R).

The iOS / iPadOS app lives in the same project (scheme `Copyo iOS`, iOS 18+, sharing `CopyoCore` and the iCloud data with the Mac app). To build it for the simulator:

```bash
xcodebuild -project Copyo.xcodeproj -scheme "Copyo iOS" -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

The project uses Xcode's automatic signing, with the maintainer's Team filled in. Contributors should switch the Team
to their own under Signing & Capabilities in Xcode, or pass it in at build time:

```bash
xcodebuild -project Copyo.xcodeproj -scheme Copyo -configuration Release \
  -derivedDataPath build DEVELOPMENT_TEAM=<your-team-id> build
```

If you only want to compile and take a look, with no plans to install it on another machine, add `CODE_SIGNING_ALLOWED=NO` to skip signing entirely.
Note that iCloud sync depends on an iCloud container and the push capability on the App ID, so it is unavailable when you build with your own Team
(you would need to create an iCloud container in your own developer account and change `CopyoStore.cloudKitContainerIdentifier`).
Everything else works as usual.

## Packaging for distribution (maintainers)

```bash
NOTARY_PROFILE=copyo-notary ./scripts/build-release.sh
# archive → export with Developer ID (signing, entitlements and the profile are all handled by Xcode)
# → Apple notarization → staple → produces dist/Copyo-<version>.dmg + .zip
```

The notarization credentials need a one-time setup (generate the app-specific password at account.apple.com):

```bash
xcrun notarytool store-credentials copyo-notary \
  --apple-id <apple-id-email> --team-id <TEAMID> --password <app-specific-password>
```

- The script needs a Developer ID certificate and the matching provisioning profile (including the iCloud container and the push capability).
  **Without a developer certificate** (when building from source yourself, say): just build with `CODE_SIGNING_ALLOWED=NO` as described
  above. The result is only good for your own machine; on any other machine macOS says the app "is damaged and can't be opened"
  (Gatekeeper's boilerplate for apps with no developer identity), which one run of `xattr -cr /Applications/Copyo.app` clears.
- In a corporate environment with MDM (Jamf and friends), you can distribute it through an allowlist instead.

### Updating

Official releases always carry the same signing identity, so installing a new DMG over the old version (drag it into Applications and replace) is all you need.
Your history lives in `~/Library/Application Support/Copyo/` and is left untouched (the `Paster/` directory from 1.0 is moved over automatically on first launch).

## Icon

The two platforms have separate icons, so changing the icon means running **both** commands:

```bash
./scripts/make-icon.sh          # macOS: scale art/icon-master.png into the 10 sizes in the asset catalog
./scripts/make-icon.sh --ios    # iOS: redraw the light / dark / tinted variants from art/icon/paster-icon-spec.md
```

The macOS run reads `art/icon-master.png` (1024×1024); replace that file with your own design.
The iOS run takes no input image — an iOS icon has to be full-bleed with no alpha and needs three
appearance variants, none of which can be derived from a single raster master, so the script draws it
from the spec; changing the iOS icon means editing the geometry and color tables inside the script.
The iOS path needs Pillow (`python3 -m pip install --user Pillow`); the macOS path only uses the
system's own `sips`.

Run the bare command alone and the iOS AppIcon keeps the old artwork, so the build ships a stale icon.

Then rebuild to pick it up. The repository currently ships a programmatically drawn placeholder icon.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Open / close the panel | `⇧⌘V` (global, customizable in Settings) |
| Move between cards | `←` `→` |
| Copy the selection and return to the previous app | `↩` or double-click the card |
| Copy as plain text | `⌥↩` |
| Preview the selection | `Space` (when the search field is empty; while typing it inserts a space) |
| Search | just start typing |
| Clear the search / close the panel | `Esc` |

## Architecture

```
Copyo/
├── App/        app entry point, menu-bar residency (NSStatusItem)
├── Models/     SwiftData models: ClipItem, Pinboard
├── Services/   clipboard polling, writing back to the clipboard and returning focus to the previous app, global hotkey, iCloud sync, icon color extraction, thumbnail cache
├── Panel/      the bottom slide-up panel (NSPanel + SwiftUI): card flow, search, preview
└── Settings/   Settings window (General / Clipboard / Sync / Shortcuts / About)
```

Implementation notes:

- macOS has no notification API for clipboard changes, so `ClipboardMonitor` polls `NSPasteboard.changeCount` every 0.3s (what every clipboard tool does)
- Text wins over images when capturing: apps like Excel and Numbers put an image rendering on the clipboard alongside the text you copied, so the entry has to be recorded as text
- The global hotkey uses Carbon `RegisterEventHotKey`, with zero third-party dependencies; the app does not use the Accessibility permission
- Storage is SwiftData (SQLite); images go through `externalStorage` plus SHA-256 deduplication and a thumbnail cache
- Sync has two mutually exclusive channels: the folder option merges snapshots (iCloud Drive or any shared directory works,
  no paid developer account needed, but deletions are not propagated); the iCloud option has SwiftData mirror straight into the CloudKit
  private database, syncing additions, edits and deletions in full. Both use the same `Copyo.store`, and only one is ever active at a time

## License

[MIT](LICENSE)
