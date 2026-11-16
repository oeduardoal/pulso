# Pulso

Menu bar system monitor for macOS. Read `HANDOFF.md` before writing any code: it holds the scope, the screens, the data sources and the open decisions.

## Design reference

- `design/en/*.html` and `design/pt-BR/*.html` are the source of truth for layout, spacing, type sizes and colors. Every value is an inline style, so read the exact numbers from the markup instead of estimating from the screenshots.
- `design/tokens.json` summarizes the shared values.
- `design/screenshots/` shows the intended result. All numbers in the mockups are sample data.
- The HTML is a visual reference only. Build the app natively; do not embed a web view.

## Brand

- `brand/README.md` describes the identity: app icon, logo, menu bar glyph, palette, type and icon set.
- `brand/ROLLOUT.md` is the task brief for applying the kit to the app and the repository. Follow its task order and ask before deciding anything under its "Open decisions".
- The SVG files are the masters. Never edit a derived PNG by hand; re-export it from its SVG.

## Conventions

- Swift and SwiftUI, with AppKit only where SwiftUI cannot do the job (status item, panel window behavior, vibrancy).
- No third-party dependencies without asking first.
- Every user-facing string goes through the String Catalog (`localization/Localizable.xcstrings`), in English and Portuguese (Brazil). Never hardcode UI text.
- Format numbers, bytes, rates, temperatures, durations and dates with locale-aware formatters. Never build these strings by hand.
- Do not use em dashes in UI copy, comments or docs.
- Keep sampling cheap: the monitor must not show up in its own process list.

## Workflow

- Verify API names and availability against current Apple documentation before relying on them. The pointers in `HANDOFF.md` are starting points, not guarantees.
- The Xcode project is generated from `project.yml` with XcodeGen. Run `xcodegen generate` after adding or removing files; never edit `Pulso.xcodeproj` by hand.
- Build and run after each milestone listed in `HANDOFF.md`, and compare against the matching screenshot.
- This is an open source project. Keep `README.md` (roadmap) and `CHANGELOG.md` (`Unreleased`) current with each user-visible change, and follow `CONTRIBUTING.md`.
- Code, comments, commit messages and docs are in English.
- English is the default everywhere: source strings, design files, brand assets and docs. Portuguese (Brazil) is the second localization, never the default.
- Ask before deciding any item under "Open decisions" in `HANDOFF.md`.
