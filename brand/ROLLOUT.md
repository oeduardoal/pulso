# Brand kit rollout: handoff

This is the task brief for applying the brand kit in `brand/` to the app and the repository. Read [`README.md`](README.md) in this folder first: it describes every asset and how it is meant to be used.

## Where things stand

- The app is at 0.1.0 and ships with no asset catalog and no app icon. Finder, the DMG, System Settings and notifications all show the generic icon.
- `brand/` was added after 0.1.0. Nothing in the app, the scripts or the release pipeline references it yet.
- The assets were rendered and checked visually, but nothing in this brief was built or run in Xcode. Treat every Xcode setting name here as a starting point and verify it against current documentation.
- English is the default language for strings, docs, design files and assets. Portuguese (Brazil) is the second localization.

## Tasks

Do them in order. Build and run the tests after each one, and commit each one separately.

### 1. Add the asset catalog and the app icon

1. Copy `brand/xcode/Assets.xcassets` to `Pulso/Assets.xcassets`. Keep `brand/xcode/` as the pristine copy. The `Pulso` folder is already a source path of the `Pulso` target in `project.yml`, so XcodeGen will add the catalog as a resource.
2. In `project.yml`, add to the `Pulso` target's base settings:
   - `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`
   - `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor`
3. Run `xcodegen generate` and build.
4. Check the icon in Finder (Get Info on the built app), in System Settings under Login Items and under Notifications, and on a notification banner. The app is an agent app with no Dock icon, so those are the places a user sees it.
5. Check whether the widget extension needs anything. Widgets normally show the containing app's icon in the widget gallery; confirm that it appears there.
6. Confirm the build still has no warnings and that CI's unsigned build (`CODE_SIGNING_ALLOWED=NO`, see `.github/workflows/build.yml`) still passes with the catalog in place.

### 2. Use the menu bar glyph as the fallback status item

`Pulso/MenuBar/MenuBarView.swift` shows the SF Symbol `waveform.path.ecg` when no module is visible in the menu bar. Replace it with the `MenuBarGlyph` image from the catalog, rendered as a template so it follows the menu bar's light and dark appearance.

- The glyph is drawn on an 18 pt canvas. Match the optical size and the vertical centering of the SF Symbol it replaces.
- Compare both menu bar appearances and the compact layout.
- The status item's accessibility label must stay as it is.

### 3. Show the logo in the README

Add the lockup at the top of `README.md`, above the first paragraph, switching with the reader's color scheme:

```html
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="brand/logo/pulso-lockup-dark.png">
    <img src="brand/logo/pulso-lockup-light.png" width="300" alt="Pulso">
  </picture>
</p>
```

Keep the existing screenshots and the rest of the page as they are.

### 4. Update the docs

- `CHANGELOG.md`: add the app icon and the menu bar glyph under `Unreleased`.
- `HANDOFF.md` (repository root): the introduction still says no app code exists. Bring that sentence and the "What is in this repository" table up to date.
- `README.md`: the `brand/` row in "Project layout" says the kit is not wired in yet. Update it once task 1 is done.
- `brand/README.md`: update the status line at the top and the "Wiring the app icon" section so they describe what was actually done.

### 5. Build a release candidate and look at it

Run `NOTARIZE=0 scripts/make-dmg.sh <version>` for a local dry run, open the DMG and check that the app inside shows the icon. Do not tag or publish a release without asking.

## Open decisions

Ask the owner before doing any of these.

1. **Layered icon for macOS 26.** The catalog ships a flat icon. A layered icon made in Icon Composer lets the system render the glass, dark and tinted appearances. `brand/app-icon/layers/` has the three layers ready. Icon Composer is a graphical tool, so this may need the owner to do it by hand. Decide whether 0.1.1 ships with the flat icon first.
2. **DMG presentation.** `scripts/make-dmg.sh` creates a plain DMG. Options: leave it, add a volume icon, or add a background image based on `brand/wallpaper/`. A background needs a different packing approach than `hdiutil create -srcfolder`.
3. **Release.** Whether the icon goes out as 0.1.1 right away or waits for the next feature release.
4. **About view.** The app has no About panel. Decide whether to add one (icon, version, link to the repository) to the status item's right-click menu.
5. **One source for colors.** The accent values live in three places: the `Accent` enum in `Pulso/Shared/Module.swift`, `design/tokens.json` and `brand/colors.json`. Decide whether to move them into color sets in the asset catalog or leave them as they are.
6. **"Working title".** The README still calls "Pulso" a working title. With a logo and an icon, decide whether that note stays.

## For the owner, outside the repository

- Upload `brand/social/github-social-preview.png` in the GitHub repository's Settings, General, Social preview. This cannot be done with a commit.

## Rules

- Do not redraw or restyle the assets as part of this work. If an asset needs to change, change the SVG master and re-export every derived PNG from it, for example `rsvg-convert -w 512 brand/app-icon/pulso-icon.svg -o brand/app-icon/pulso-icon-512.png` (`brew install librsvg`). Never edit a PNG by hand.
- The app keeps using SF Symbols for its interface icons. `brand/icons/` is for the web and docs only.
- Follow `CLAUDE.md` and `CONTRIBUTING.md`: no hardcoded strings, both languages checked, no em dashes, English for code, comments, commits and docs.

## Acceptance checklist

- The built app shows the Pulso icon in Finder, in Login Items, in notification settings and on notification banners.
- With every module hidden from the menu bar, the status item shows the Pulso glyph, correctly tinted in both menu bar appearances.
- The README shows the lockup, legible in GitHub's light and dark themes.
- `xcodegen generate`, the build and the tests all pass with no new warnings, locally and in CI.
- A local DMG dry run produces an app with the icon.
- `CHANGELOG.md`, `HANDOFF.md`, `README.md` and `brand/README.md` describe the new state.
- With the panel closed, Pulso still uses well under 1% CPU.
