# Pulso brand kit

Identity assets for Pulso: app icon, logo, menu bar glyph, colors, type, icon set, wallpaper and a GitHub social preview. Open [`index.html`](index.html) for the visual overview, or see [`brand-sheet.png`](brand-sheet.png).

**Status:** the app uses the kit since 0.1.1. `Pulso/Assets.xcassets` is a copy of `xcode/Assets.xcassets` and provides the app icon, the accent color and the menu bar glyph, and the README shows the lockup. The layered macOS 26 icon is not built yet. [`ROLLOUT.md`](ROLLOUT.md) is the brief that applied the kit; see also [Wiring the app icon](#wiring-the-app-icon).

## Concept

A pulse line at dusk. The line is the live reading every panel draws, colored with the two accents the app uses most (blue to teal). The amber dot at the end is the newest sample, and also the setting sun from the dusk wallpaper in the design mockups. The dunes at the bottom of the icon come from the same wallpaper.

## Contents

| Path | What it is |
| --- | --- |
| `app-icon/pulso-icon.svg` | App icon master, 1024 pt canvas with the icon body at 824 pt |
| `app-icon/pulso-icon-*.png` | PNG exports at 16, 32, 64, 128, 256, 512 and 1024 px |
| `app-icon/layers/` | Background, dunes and pulse as separate full-bleed SVGs, for a layered icon |
| `xcode/Assets.xcassets` | Ready-made asset catalog: `AppIcon`, `AccentColor` and `MenuBarGlyph` |
| `logo/pulso-mark*.svg` | The pulse mark alone: for dark backgrounds, for light backgrounds, white, ink |
| `logo/pulso-wordmark-*.svg` | The wordmark alone, white and ink |
| `logo/pulso-lockup-*.svg`, `.png` | Mark plus wordmark, for dark and for light backgrounds |
| `menu-bar/` | 18 pt monochrome glyph as a template image (SVG, PNG at 1x and 2x) and a white variant |
| `icons/` | 16 UI icons as SVG, 24 pt grid, 1.8 pt stroke, `currentColor` |
| `colors.json`, `colors.css` | The palette as data and as CSS custom properties |
| `wallpaper/` | The dusk wallpaper, SVG and 2880 x 1800 PNG |
| `social/github-social-preview.png` | 1280 x 640 image for the repository's social preview |

## Logo

- Use the lockup where there is room and the mark alone where there is not (favicons, avatars, small badges).
- `pulso-lockup-dark` and `pulso-mark` are for dark backgrounds. `pulso-lockup-light` and `pulso-mark-on-light` use deeper colors so the line stays visible on white.
- Use the white or ink single-color versions over photos, busy backgrounds or when printing in one color.
- Keep clear space around the logo equal to the height of the letter "o" in the wordmark.
- Do not recolor the gradient, stretch the mark, add effects, or set the wordmark in another typeface.
- Minimum width: 96 px for the lockup, 24 px for the mark.

The wordmark is "Pulso" in Inter Display Semibold with -2% tracking, converted to outlines, so the SVGs need no font. Inter is licensed under the SIL Open Font License.

## App icon

`app-icon/pulso-icon.svg` is the master. It follows the classic macOS template: a rounded rectangle body of 824 pt centered on a 1024 pt canvas, with the drop shadow drawn in.

### Wiring the app icon

This is how the app uses the kit:

1. `brand/xcode/Assets.xcassets` is copied to `Pulso/Assets.xcassets`. The `Pulso` source folder is listed in `project.yml`, so XcodeGen adds the catalog to the app target. Keep `brand/xcode/` as the pristine copy: when an asset changes, re-export it from its SVG master, update `brand/xcode/`, then copy the catalog again.
2. The `Pulso` target in `project.yml` sets `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` and `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor`. The build produces `AppIcon.icns` and `Assets.car` and sets `CFBundleIconName` in the app's Info.plist.
3. The status item shows `MenuBarGlyph` as a template image when every module's menu bar widget is hidden (`Pulso/MenuBar/MenuBarView.swift`).

The icon was checked in Finder and in a signed DMG. The widget extension has no icon of its own; WidgetKit shows the containing app's icon in the widget gallery, which has not been checked by hand yet.

### macOS 26 layered icon

The deployment target is macOS 26, where app icons are normally authored as layered icons in Icon Composer so the system can render the glass, dark and tinted appearances. A flat `AppIcon` set still works, but the system may treat it differently from a layered icon. `app-icon/layers/` holds the three layers as full-bleed SVGs, back to front, with no mask and no shadow: `1-background.svg`, `2-dunes.svg`, `3-pulse.svg`. Building the `.icon` file from them is still to do, and the exact workflow should be checked against Apple's current documentation.

## Menu bar glyph

`menu-bar/pulso-glyph-template.svg` is an 18 pt template image: pure black with transparency, so the system tints it for light and dark menu bars. The app's menu bar item normally shows live widgets instead of an icon. Use the glyph where a static icon is needed: when every module's menu bar widget is turned off, in notifications, and in an About view. `MenuBarGlyph` in the asset catalog is already marked as a template image.

## Colors

Values are in `colors.json` and `colors.css`. Accent values match the `Accent` enum in `Pulso/Shared/Module.swift` and `design/tokens.json`. If one changes, change all three.

| Name | Hex | Role |
| --- | --- | --- |
| Pulse Blue | `#5AB0FF` | Primary brand color. CPU, download, read. App accent color. |
| Midnight | `#071230` | Darkest sky. Icon and wallpaper top. |
| Navy | `#0F3566` | Sky. |
| Dusk | `#2F6F9C` | Horizon blue. |
| Sunset | `#E9A06A` | Horizon glow. |
| Sand | `#F7C88F` | Lightest horizon. |
| Teal | `#54D6B4` | Memory, efficiency cores. End of the pulse gradient. |
| Amber | `#FFB454` | Disk. The dot in the mark. |
| Orange | `#FF9F5A` | Upload, write, system CPU. |
| Green | `#6BDB7A` | Battery, normal status. |
| Coral | `#FF7A6B` | Sensors, critical status. |
| Ink | `#0B0F1A` | Page background on the web and in docs. |
| Cloud | `#F2F3F5` | Light background, light text on dark. |

The accents are tuned for dark surfaces and are too light for text on white. On light backgrounds use the `onLight` values instead:

| Name | Hex | Contrast on white | Use |
| --- | --- | --- | --- |
| Blue | `#1663C7` | 5.76:1 | Text, links, the mark |
| Teal | `#0B7F6A` | 4.93:1 | Text, the mark |
| Amber | `#C96F0C` | 3.64:1 | Graphics and large text only |

## Typography

| Face | Use |
| --- | --- |
| SF Pro Rounded, semibold, tabular digits | Hero metrics in the app (`Theme.hero`) |
| SF Pro Text | Everything else in the app. This is the system font; do not bundle it. |
| Inter | The wordmark, the website and documentation, where the system font is not available |

## Icons

The app draws its icons with SF Symbols and should keep doing so. The SVGs in `icons/` are the same ideas redrawn for places where SF Symbols cannot be used: a website, documentation and social images. Apple's license limits SF Symbols to interfaces for Apple platforms.

| SVG | SF Symbol used in the app |
| --- | --- |
| `cpu.svg` | `cpu` |
| `memory.svg` | `memorychip` |
| `disk.svg` | `internaldrive` |
| `network.svg` | `arrow.up.arrow.down` |
| `battery.svg` | `battery.75percent` |
| `sensors.svg` | `thermometer.medium` |

The remaining SVGs (`bluetooth`, `settings`, `alerts`, `widgets`, `menu-bar`, `eject`, `copy`, `arrow-down`, `arrow-up`, `chevron-left`) cover the controls drawn in the mockups.

## Wallpaper and social preview

- `wallpaper/pulso-dusk.svg` is the dusk scene behind the panels in `design/`. Use it for screenshots, the website hero and the DMG background.
- `social/github-social-preview.png` is sized for GitHub: upload it under the repository's Settings, General, Social preview.
