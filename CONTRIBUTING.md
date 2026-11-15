# Contributing to Pulso

Thanks for helping. This guide covers how to set up the project, the conventions the code follows, and how changes get merged.

## Before you start

- For anything larger than a small fix, open an issue first so we can agree on the approach.
- Check [`HANDOFF.md`](HANDOFF.md) for the product spec and the build order. Work on the current milestone is the most likely to be merged.
- Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md).

## Setup

1. Install Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. Run `xcodegen generate` to create `Pulso.xcodeproj`. Run it again whenever you add, move or remove a source file. The project file is generated and not checked in, so edit `project.yml` for build settings.
3. Open `Pulso.xcodeproj` and run the `Pulso` scheme. Signing uses the maintainer's team; see "Build from source" in the README to use your own.
4. Run the tests with `xcodebuild -project Pulso.xcodeproj -scheme Pulso -derivedDataPath build test`.

## Conventions

### Code

- Swift and SwiftUI. Use AppKit only where SwiftUI cannot do the job (status item, panel window behavior, vibrancy).
- No third-party dependencies without discussing it in an issue first.
- Verify Apple API names and availability against current documentation. The deployment target is macOS 26.
- Keep sampling cheap. Pulso must not show up in its own process list. Heavy samplers (process lists, per-process network) run only while the panel is open.

### Design

- `design/en/*.html` and `design/pt-BR/*.html` are the source of truth for layout, spacing, type sizes and colors. Read the exact values from the inline styles; `design/tokens.json` summarizes them.
- Compare your change against the matching screenshot in `design/screenshots/`, in both languages.
- The HTML is a reference only. Build natively, never embed a web view.

### Text and localization

- Every user-facing string goes through `localization/Localizable.xcstrings` with a semantic key (`cpu.loadAverage`, not English text). Never hardcode UI text.
- Add both English and Portuguese (Brazil) for every new key. If you cannot write one of them, add the English value, leave the other marked "Needs review", and say so in the pull request.
- Format numbers, bytes, rates, temperatures, durations and dates with locale-aware formatters. Never build these strings by hand.
- Process names, volume names, network names and IP addresses are data and are never translated.
- Do not use em dashes in UI copy, comments or docs.

### Accessibility

- Every icon-only button has an accessibility label.
- Every chart has a text description.
- Text meets 4.5:1 contrast on the glass, including over bright wallpapers.

## Pull requests

1. Fork the repository and create a branch from `main` (`feature/cpu-sampler`, `fix/panel-position`).
2. Keep each pull request focused on one change.
3. Write commit messages in the imperative mood ("Add CPU sampler", not "Added CPU sampler"). Keep the first line under 72 characters.
4. Add an entry under `Unreleased` in [`CHANGELOG.md`](CHANGELOG.md) for any user-visible change.
5. Before opening the pull request:
   - the app builds with no warnings and the tests pass,
   - with the panel closed, Pulso still uses well under 1% CPU (check with `ps -o %cpu -p $(pgrep -x Pulso)`),
   - you ran it and checked the affected screens in English and Portuguese,
   - UI changes include before and after screenshots in the pull request.

## Translations

Pulso ships in English and Portuguese (Brazil). To improve a translation, edit `localization/Localizable.xcstrings` in Xcode's String Catalog editor and open a pull request. To propose a new language, open an issue first: every string, the widget extension and notifications need full coverage before a language ships.

## Releases

Maintainers cut releases by following [`docs/RELEASING.md`](docs/RELEASING.md).
