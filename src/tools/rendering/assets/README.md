# Rendering Assets

## `star_reference.png`

Derived reusable color reference map for the current solar hybrid path.

- Source basis: user-provided solar reference image at `D:/Downloads/sun.png`
- Usage: visible solar surface/color source inside the existing `body_star.gdshader`
- Not used as a full direct photo sprite; the shader still owns glow, activity modulation and focused-star closeup behavior

Regeneration:

```powershell
C:\Users\Sh4man\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe `
  D:\Projekte\Godot\Graviton\src\tools\rendering\scripts\derive_star_reference_map.py `
  --input D:\Downloads\sun.png `
  --output D:\Projekte\Godot\Graviton\src\tools\rendering\assets\star_reference.png `
  --size 512
```

The derivation intentionally:

- detects and centers the solar disc from the original image
- crops the source to a disc-friendly square reference frame
- keeps the rich source colors instead of flattening them to grayscale
- clips the strongest outer corona/protuberance area out of the runtime map
- preserves a soft inner alpha edge so the shader can keep the solar disc clean

## `star_detailmap.png`

Derived reusable grayscale structure map for the focused-star closeup follow-up.

- Source basis: user-provided solar reference image at `D:/Downloads/sun.png`
- Usage: centered secondary structure/luminance source layered on top of `star_reference.png`
- Not used as a direct photo skin for stars

Regeneration:

```powershell
C:\Users\Sh4man\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe `
  D:\Projekte\Godot\Graviton\src\tools\rendering\scripts\derive_star_detailmap.py `
  --input D:\Downloads\sun.png `
  --output D:\Projekte\Godot\Graviton\src\tools\rendering\assets\star_detailmap.png `
  --size 512
```

The derivation intentionally:

- detects the solar disc and centers it on a square canvas
- clips outer protuberances from the source image
- keeps only the inner solar disc structure
- normalizes luminance and contrast
- produces a reusable grayscale detail map for shader modulation

The shader intentionally samples the map statically:

- no `TIME`-based translation
- no rotation
- centered disc-aligned UV sampling only
- refreshed in the current hybrid-follow-up with slightly stronger closeup weighting while the new color-led `star_reference.png` remains the primary visible surface

## `moon_reference.png`

Derived hybrid reference map for the first moon-specific Variant-2 pilot.

- Source basis: user-provided moon reference image at `C:/Users/Sh4man/AppData/Local/Temp/planet25.png`
- Usage: moon surface color/detail source inside the existing `body_sphere.gdshader`
- Not used as a direct beauty-render sprite; the shader still owns lighting, rim and rotation semantics

Regeneration:

```powershell
C:\Users\Sh4man\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe `
  D:\Projekte\Godot\Graviton\src\tools\rendering\scripts\derive_planet_reference_map.py `
  --input C:\Users\Sh4man\AppData\Local\Temp\planet25.png `
  --output D:\Projekte\Godot\Graviton\src\tools\rendering\assets\moon_reference.png `
  --size 512
```

The derivation intentionally:

- centers the opaque moon disc via the source alpha channel
- crops to a square reference frame
- flattens the strongest radial baked-light bias toward a more albedo-like map
- sharpens inner crater/detail signal
- contracts the usable alpha mask inward so the shader does not re-import the original beauty rim

## `temperate_reference.png`, `frozen_reference.png`, `hot_scorched_reference.png`

Derived hybrid reference maps for the first planet-archetype expansion of the moon pilot.

- Source basis:
  - `temperate_reference.png` <- user-provided `D:/Downloads/Terran1.png`
  - `frozen_reference.png` <- user-provided `D:/Downloads/Ice1.png`
  - `hot_scorched_reference.png` <- user-provided `D:/Downloads/Lava1.png`
- Usage: inner surface color/detail sources for `TEMPERATE_OCEAN`, `FROZEN` and `HOT_SCORCHED`
- Not used as direct beauty-render sprites; the shader still owns lighting, rim and rotation semantics

Regeneration:

```powershell
C:\Users\Sh4man\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe `
  D:\Projekte\Godot\Graviton\src\tools\rendering\scripts\derive_planet_reference_map.py `
  --input D:\Downloads\Terran1.png `
  --output D:\Projekte\Godot\Graviton\src\tools\rendering\assets\temperate_reference.png `
  --size 512 `
  --flatten-strength 0.28 `
  --color-preserve 0.92 `
  --saturation-boost 1.06 `
  --contrast 1.02 `
  --sharpness 1.04 `
  --detail-gain-strength 0.22

C:\Users\Sh4man\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe `
  D:\Projekte\Godot\Graviton\src\tools\rendering\scripts\derive_planet_reference_map.py `
  --input D:\Downloads\Ice1.png `
  --output D:\Projekte\Godot\Graviton\src\tools\rendering\assets\frozen_reference.png `
  --size 512 `
  --flatten-strength 0.26 `
  --color-preserve 0.94 `
  --saturation-boost 1.04 `
  --contrast 1.02 `
  --sharpness 1.03 `
  --detail-gain-strength 0.18

C:\Users\Sh4man\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe `
  D:\Projekte\Godot\Graviton\src\tools\rendering\scripts\derive_planet_reference_map.py `
  --input D:\Downloads\Lava1.png `
  --output D:\Projekte\Godot\Graviton\src\tools\rendering\assets\hot_scorched_reference.png `
  --size 512
```

The derivation intentionally:

- reuses the same alpha-centered crop/flatten/detail pipeline as the moon pilot
- now supports per-asset tuning for baked-light flattening and color retention
- now also supports a lighter local-detail gain so closeup planet references can stay closer to the original artwork
- keeps `temperate_reference.png` and `frozen_reference.png` intentionally more color-faithful to their source art than the moon pilot
- keeps the usable alpha mask inside the original beauty rim
- leaves the final lighting, terminator and rotational motion to the runtime shader
