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
