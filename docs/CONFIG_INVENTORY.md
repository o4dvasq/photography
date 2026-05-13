# Configuration Inventory — photography

Last updated: 2026-05-13

---

## Hosting / DNS

| Surface | Value | Notes |
|---|---|---|
| Distribution | Personal use only | Native macOS menubar app; not published |
| GitHub repo | `https://github.com/o4dvasq/photography` | Source of record |

---

## Build Steps

| Step | Tool | Notes |
|---|---|---|
| Build | Xcode (macOS, Swift) | Project at `PhotoPipeline/PhotoPipeline.xcodeproj` |
| Deploy | Run from Xcode or exported app bundle | No CI/CD workflow |

---

## Source Files

| Path | Contents | Notes |
|---|---|---|
| `PhotoPipeline/PhotoPipeline.xcodeproj` | Xcode project | macOS menubar app |
| `PhotoPipeline/PhotoPipeline/` | Swift source | App, views, models, services |

---

## Local Dev Setup

1. Open `PhotoPipeline/PhotoPipeline.xcodeproj` in Xcode
2. Build and run (⌘R)
3. Photos storage: `~/Photography/` (not in git; configurable in app preferences)

---

## Auth Surfaces

| Auth Surface | Type | Notes |
|---|---|---|
| iCloud Photos | Apple account (implicit) | Handoff to iPhone via iCloud Photos |
| SD Card / filesystem | Local disk access | macOS sandboxing may require explicit permission |

---

### Inference Notes

- No environment variables, secrets, scheduled jobs, or network services.
- Native macOS app; all config is in user preferences (Swift `@AppStorage`).
- `~/Photography/` is the working storage path; can be changed in app preferences.
