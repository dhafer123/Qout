# Brand and design sources

Originals supplied by Dhafer Romdhani, who holds the rights to use them in Qout. The app
uses its own copies (under `app/assets/` and `app/android/`), some of them trimmed or
recoloured; change those through the steps below, never by hand-editing the originals.

## App icon

| File | What it is |
|---|---|
| `icon-sheet.png` | The chosen icon (leaf with a check in scanner corners), as delivered by the design AI. Source of every icon size. |
| `icon-1024.png` | Master icon, full square (App Store size). |
| `play-store-icon-512.png` | Play Store icon. |

All launcher, splash and in-app icon images are built from `icon-sheet.png` by
`scripts/make_icons.py` (instructions at the top of the script).

## Animations (Lottie)

| Original | Used for | App copy | Changes in the app copy |
|---|---|---|---|
| `animations/greeting-if-you-are-new-here.json` | Welcome page, the "hi." greeting | `app/assets/animations/greeting.json` | None in the file; in code: cropped to the middle, looped (in, a second on "hi.", away), recoloured to the brand green |
| `animations/security-status-safe.json` | Welcome page "Advice for you" (shield) | `app/assets/animations/privacy_shield.json` | None in the file; in code: shield recoloured to the brand green |
| `animations/qr-scan-successful.json` | Scanner, a barcode read | `app/assets/animations/scan_success.json` | Trimmed to its last 1.1 s (frames 36 to 69); in code: recoloured to the accent |
| `animations/loading-dots.json` | Launch splash, under the icon | `app/assets/animations/loading_dots.json` | Recoloured: brand green dots with a light-green flash |
| `animations/sign-in-green.json` | Sign in / sign up illustration | `app/assets/animations/sign_in.json` | The phone recoloured from pink and purple to the brand greens |
| `animations/walking-orange.json` | Not used yet | — | — |

## Design handoff

`handoff/form-submission-decisions-handoff.zip`: the 2026-11-18 design handoff ("Qout
Directions", the Nocturne design system, the earlier navy logo). Kept for reference; the
navy logo was replaced by the icon above in T45a.
