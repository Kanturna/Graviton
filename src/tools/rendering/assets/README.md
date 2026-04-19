# Rendering Assets

## `star_detailmap.png`

Derived reusable structure map for the P14.6/P14.6b focused-star closeup shader.

- Source basis: user-provided solar reference image at `D:/Downloads/sun.png`
- Usage: centered structure/luminance source for focused-star closeups
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
