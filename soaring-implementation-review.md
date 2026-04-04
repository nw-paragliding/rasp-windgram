# soaring.py Implementation Review

Comparison of `rasp/soaring.py` against reference implementations — primarily
the reverse-engineered pure-Python reimplementation in `simonbesters/icon-d2-pipeline`
and the original NCL/Fortran calling conventions in `wargoth/rasp-gm`.

## Reference Implementations

### Pure Python (best for comparison)

| Repo | Description |
|------|-------------|
| [simonbesters/icon-d2-pipeline](https://github.com/simonbesters/icon-d2-pipeline) | **Best reference.** Complete pure-Python reimplementation of all DrJack Fortran routines, reverse-engineered from the compiled `.so` binary with constants decoded from `.rodata`. Includes unit tests. Files in `icon_d2_pipeline/calc/`. |
| [B4dWo1f/RUNplots](https://github.com/B4dWo1f/RUNplots) | Python wrappers calling compiled Fortran via f2py. `drjack_interface.py` shows the calling conventions and some post-processing logic (e.g. hcrit w_crit conversion to fpm). |

### Python wrappers around Fortran `.so` (shows calling conventions)

| Repo | Description |
|------|-------------|
| [oriolcervello/raspuri](https://github.com/oriolcervello/raspuri) | Python/Bash RASP rewrite for WRF v4. `functions.py` shows the full call sequence including vhf computation and array transposition for Fortran column-major order. |

### Original NCL/Fortran (canonical but opaque)

| Repo | Description |
|------|-------------|
| [wargoth/rasp-gm](https://github.com/wargoth/rasp-gm) | DrJack's GM subsystem. `GM/calc_funcs.ncl` is the NCL wrapper layer; real math is in `ncl_jack_fortran.so` (no source available). |
| [CazYokoyama/wrfv3](https://github.com/CazYokoyama/wrfv3) | Most complete mirror of DrJack's full RASP installation. Same NCL code plus WRF, WPS, domain wizard. |

### Windgram-specific

| Repo | Description |
|------|-------------|
| [ToninoTarsi/windgramtt](https://github.com/ToninoTarsi/windgramtt) | Best available NCL windgram script (TJ Olney's `windgramtj.ncl` customized by Tonino Tarsi). |
| Original script | `http://wxtofly.net/rasp_scripts/windgramtj.ncl` |

### Reverse Engineering Documentation

The `icon-d2-pipeline` repo contains two critical documents:
- `tasks/original_jack.md` — Analysis of the older `ncl_jack_fortran.so`, all 50 registered NCL functions, reconstructed core algorithms
- `tasks/libncl_drjack_reverse_engineered.md` — Deep disassembly of the newer `libncl_drjack.avx512.nocuda.so` with all `.rodata` constants decoded

Local copies saved to `reference/icon-d2/` and `reference/ncl/`.

---

## Function-by-Function Comparison

### 1. `calc_wstar` — Moderate differences

**Ours:**
```python
vhf = np.maximum(hfx + 0.000245268 * t2 * np.maximum(lh, 0.0), 0.0)
buoyancy_flux = (G / t2) * (vhf / RHO_CP)
wstar = (buoyancy_flux * pblh) ** (1/3)
```

**Reference (icon-d2):**
```python
arg = (GRAVITY / t_avg) * pblh * (vhf / RHO_CP)
wstar = np.cbrt(np.maximum(arg, 0.0))
```

**NCL getvars.ncl (how vhf is computed upstream):**
```ncl
vhf = LH                            ; start with latent heat
minlimit2d(vhf, 0.0, ...)           ; clamp LH >= 0
vhf = hfx + 0.000245268 * (tc(0,:,:) + 273.16) * vhf
```

**Issues:**
- **Temperature in denominator**: We use `t2` (2m temperature in K). The NCL code uses `tc(0,:,:) + 273.16` (lowest model level temperature converted to K with 273.16, not 273.15). The icon-d2 reference uses `t_avg` defaulting to 300K. For correctness matching DrJack, the vhf formula should use the lowest model-level T in K, and the w* formula should too.
- **The magic constant 0.000245268**: This is `0.61 * Cp/Lv = 0.61 * 1004 / 2.501e6 ≈ 0.000245268`. Our code has this right.
- **Overall**: Functionally close. The temperature difference (T2 vs tc[0]+273.16 vs 300K) will produce small differences, on the order of a few percent.

### 2. `calc_hcrit` / `calc_hlift` — MAJOR difference

**Ours (simple linear):**
```python
ratio = 1.0 - sink_rate / wstar
hcrit = ter + pblh * ratio
```

**Reference (DrJack's empirical nonlinear model from binary):**
```python
# Constants decoded from .rodata of libncl_drjack.so:
_ALPHA1 = 0.463    _ALPHA2 = 0.4549    _ALPHA3 = 1.3674
_ALPHA4 = 0.01267  _ALPHA5 = 0.1126    _HCRIT_THRESHOLD = 225.0  # fpm

wstar_fpm = wstar * 196.85
ratio = threshold_fpm / wstar_fpm
height_frac = sqrt(1.3674 * (0.4549 - 0.463 * ratio) + 0.01267) + 0.1126
hcrit = ter + height_frac * pblh
```

**This is the largest discrepancy.** DrJack uses a nonlinear sqrt-based thermal penetration model with 5 empirical constants, not a simple linear depletion. The linear model overestimates hcrit for moderate thermals and underestimates it for strong ones. For example, with wstar=2.5 m/s and pblh=1500m:
- Our linear model: `ratio = 1 - 1.14/2.5 = 0.544`, so `hcrit = ter + 816m`
- DrJack model: `wstar_fpm=492, ratio=225/492=0.457`, `inner = 1.3674*(0.4549-0.463*0.457)+0.01267 = 0.343`, `height_frac = sqrt(0.343)+0.1126 = 0.698`, so `hcrit = ter + 1047m`

That's a ~230m difference — significant for soaring decisions.

Also note: DrJack works in fpm internally. The sink rate threshold for hcrit is 225 fpm (≈1.143 m/s), and `calc_hlift` takes its criterion in fpm, not m/s.

### 3. `calc_blavg` — Minor differences

Both use trapezoidal integration. Differences:
- **Below-terrain check**: Ours checks `z_lo >= ter`, reference only checks `z_lo < bl_top`. If model levels are always above terrain (which they should be in WRF), this is equivalent.
- **Fallback**: Ours clamps `total_dz >= 1.0` as divide-by-zero guard. Reference falls back to `field_3d[0]` (surface value). The reference approach is slightly more physical.

### 4. `calc_blmax` — Minor differences

Nearly identical. Reference doesn't check `z[k] >= ter` (assumes bottom-up from surface). Falls back to surface value instead of 0.0 when no data found.

### 5. `calc_blwinddiff` — SIGNIFICANT semantic difference

**Ours (vector difference):**
```python
du = u_bltop - u_sfc
dv = v_bltop - v_sfc
return sqrt(du**2 + dv**2)    # magnitude of VECTOR difference
```

**Reference (scalar speed difference):**
```python
spd_sfc = sqrt(u_sfc**2 + v_sfc**2)
spd_top = sqrt(u_top**2 + v_top**2)
return abs(spd_top - spd_sfc)  # difference of SCALAR speeds
```

These are different quantities. Vector wind difference (ours) captures directional shear; scalar speed difference (reference) only captures speed change. For wind veering with BL height (common), our value will be larger. **Need to check which matches DrJack's intent.** The NCL calc_funcs.ncl just calls `calc_blwinddiff(ua,va,z,ter,pblh,...)` into Fortran so we can't tell from that alone. The reverse-engineering docs may clarify.

### 6. `calc_sfclclheight` — Different approach

**Ours (Bolton approximation only):**
```python
spread = T_sfc - Td_sfc
lcl_agl = 125.0 * spread
```

**Reference (parcel lifting with Espy fallback):**
```python
# Lift surface parcel dry-adiabatically: T_parcel = T_sfc * (p/p_sfc)^0.286
# Conserve surface mixing ratio, compute dewpoint at each level
# Find first level where T_parcel <= Td_parcel
# Fall back to Espy (125 * spread) only if no condensation found in profile
```

The reference approach is more physical — it accounts for the actual temperature and moisture profile rather than assuming a constant lapse rate. The 125 m/K approximation can be off by hundreds of meters in non-standard atmospheric profiles (e.g., inversions, dry layers aloft). The reference uses it only as a fallback.

### 7. `calc_blclheight` — Similar approach, different saturation formula

Both scan upward looking for where BL-averaged qvapor reaches saturation. Differences:
- **Ours**: Computes `qsat = EPS * es / (p - es)` using standard Magnus.
- **Reference**: Converts BL-average qvapor to dewpoint at each level's pressure, then compares `tc <= td_bl`.
- These should converge to similar results, but the reference formulation is closer to what DrJack's Fortran does.

### 8. `calc_blcloudpct` — SIGNIFICANT difference

**Ours (RH threshold counting):**
```python
has_cloud = (qcloud > crit) | (rh > 0.95)
cloud_pct = 100 * cloud_count / total_count   # fraction of BL levels with cloud
```

**Reference (DrJack's GrADS method from binary):**
```python
# Linear RH mapping decoded from .rodata:
cf_layer = clamp(400 * RH - 300, 0, 95)       # per-level cloud fraction
cloud_max = max(cf_layer over all BL levels)   # take MAX, not average
```

Two problems:
1. **RH mapping**: Ours uses a binary threshold at RH=0.95. DrJack uses a linear ramp: 0% at RH=75%, linearly increasing, capped at 95%. This produces graduated cloud fractions rather than all-or-nothing.
2. **Aggregation**: Ours averages (count/total). Reference takes the maximum over BL levels. Max is correct per DrJack.
3. **Saturation formula**: Reference uses `qs = 0.622 * es / (p - 0.378*es)` (includes virtual correction), ours uses `qs = EPS * es / (p - es)`.

### 9. `calc_sfcsunpct` — Fundamentally different approach

**Ours**: Computes solar geometry + Beer-Lambert transmittance from column water vapor. Returns an estimated sunshine percentage from first principles.

**Reference**: Uses WRF's `SWDOWN` (actual downward shortwave radiation from the model physics, which accounts for clouds, aerosols, etc.) normalized by computed clear-sky radiation. Returns `100 * SWDOWN / clear_sky`.

The reference approach is much better because it leverages WRF's radiation physics (which already models cloud absorption, scattering, etc.) rather than reinventing a simplified radiation model. Our approach doesn't use SWDOWN at all, meaning it ignores the model's own cloud/radiation solution.

**However**: Our function signature doesn't take SWDOWN as input, so this would require a pipeline change.

### 10. `calc_bltop_pottemp_variability` — Different output quantity

**Ours**: Returns temperature difference (K) between BL top and 2 levels above. A measure of inversion strength.

**Reference**: Finds the height range (meters) around BL top where theta stays within ±criterion K. A measure of inversion depth/sharpness.

These are different physical quantities with different units. The reference also interpolates theta to the exact BL top height rather than using the nearest model level.

### 11. `calc_wblmaxmin` — Different mode semantics

**Ours**: mode 0=max updraft, 1=max downdraft, 2=max absolute, 3=BL average. Returns m/s.

**Reference**: mode 0=max |W| in **cm/s** (note unit!), mode 1=height of max |W| in m. The Fortran returns cm/s for mode 0, not m/s.

The modes don't match. Our mode 0 returns the maximum upward velocity; the reference mode 0 returns the maximum absolute velocity (and converts to cm/s). The NCL wrapper `wblmaxmin` calls with mode=0 for the standard output, `zwblmaxmin` calls with mode=1.

---

## Recommended Changes (priority order)

### P0 — Likely causing visible bugs

1. **`calc_hcrit` / `calc_hlift`**: Replace the linear model with DrJack's nonlinear sqrt model. The 5 constants are known from the binary reverse-engineering. This will produce materially different (and more correct) soaring height predictions. The `calc_hlift` function should take its criterion in fpm, not m/s.

2. **`calc_blcloudpct`**: Switch from binary RH threshold (0.95) to the linear ramp `clamp(400*RH - 300, 0, 95)`. Change aggregation from level-average to level-maximum. Fix saturation formula to include virtual correction term.

### P1 — Meaningful accuracy improvements

3. **`calc_sfclclheight`**: Implement parcel-lifting approach (dry adiabat + conserved mixing ratio) with the 125 m/K Bolton formula as fallback only. The current approach is a common simplification but can be off by hundreds of meters.

4. **`calc_sfcsunpct`**: Refactor to take `SWDOWN` as input and normalize against computed clear-sky radiation, matching the reference. The current first-principles approach ignores WRF's own cloud/radiation solution.

5. **`calc_wblmaxmin`**: Align mode semantics with DrJack's Fortran. Mode 0 should return max |W| in cm/s, mode 1 should return height of max |W|.

### P2 — Minor corrections

6. **`calc_blwinddiff`**: Determine whether DrJack computes vector wind difference or scalar speed difference and match it. The reference uses scalar speed difference.

7. **`calc_bltop_pottemp_variability`**: Should return a height range (m), not a temperature difference (K). Should interpolate theta to exact BL top.

8. **`calc_blavg` / `calc_blmax`**: Use surface value as fallback instead of 0.0 or -inf.

9. **vhf temperature**: Use lowest model-level temperature (`tc[0] + 273.15`) instead of T2 for the virtual heat flux calculation, matching `getvars.ncl`.
