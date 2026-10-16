# Fonts

| File | Role |
|------|------|
| `NotoSans-Regular.ttf` | Latin / digits base (OFL Noto Sans) |
| `DroidSansFallback.ttf` | CJK fallback (Apache/Android) |

`DroidSansFallback` in this repo is CJK-only (no ASCII digits). UI themes that need both Latin digits and Chinese should compose these (e.g. FontVariation) rather than relying on system fonts.
