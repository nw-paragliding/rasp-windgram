# NCL → Python Rewrite Plan

## Background

RASP's post-processing pipeline uses NCL (NCAR Command Language) with two
compiled Fortran shared libraries:

- `wrf_user_fortran_util_0-64bit.so` — standard WRF diagnostic utilities
- `ncl_jack_fortran.so` — DrJack's soaring-specific calculations + WRF diagnostics

Both are pre-compiled x86_64 binaries. No source is available in this repo.

This blocks native arm64 post-processing. NCL itself is available on arm64 via
conda-forge, but the `.so` files cannot be loaded on arm64. Additionally, NCAR
has deprecated NCL in favor of Python-based tooling (PyNGL/wrf-python).

The goal of this rewrite is to eliminate both `.so` dependencies and NCL itself,
replacing them with a Python pipeline using wrf-python and matplotlib.

---

## What Each Library Contains

### `wrf_user_fortran_util_0-64bit.so`

Standard WRF diagnostic functions — a complete subset of what ncl_jack_fortran.so
also provides:

```
compute_tk_       temperature from potential temperature
compute_td_       dewpoint temperature
compute_rh_       relative humidity
compute_seaprs_   sea-level pressure reduction
compute_uvmet_    wind rotation to earth-relative coordinates
compute_iclw_     in-cloud liquid water
compute_pi_       Exner function
interp_1d_        1D vertical interpolation
interp_2d_xy_     2D horizontal interpolation
interp_3dz_       3D interpolation to pressure levels
filter2d_         2D spatial filter
get_ij_lat_long_  lat/lon to grid index
z_stag_           staggered grid height
```

**All of these are already implemented in wrf-python.** This library can be
dropped with zero custom work.

### `ncl_jack_fortran.so`

A superset of the above, plus DrJack's unique soaring calculations:

#### Soaring index calculations (unique to DrJack)
```
calc_wstar_                      convective velocity scale (w*)
calc_wblmaxmin_                  max/min thermal updraft velocity
calc_bltop_pottemp_variability_  BL top potential temperature variability
calc_bltopwind_                  wind at BL top
calc_blwinddiff_                 wind shear across BL
calc_blmax_                      BL maximum quantity
calc_blavg_                      BL average quantity
calc_blclheight_                 BL cloud layer height
calc_blcloudbase_                BL cloud base height
calc_blinteg_mixratio_           BL integrated mixing ratio
calc_aboveblinteg_mixratio_      above-BL integrated mixing ratio
calc_subgrid_blcloudpct_*        sub-grid BL cloud fraction
calc_hcrit_                      critical soaring height
calc_hlift_                      thermal lift height
calc_qcblhf_                     cloud base height factor
calc_sfclclheight_               surface LCL height
calc_sfcsunpct_                  surface sunshine percentage
calc_cape2d_                     2D CAPE calculation
calc_latlon_                     lat/lon grid calculations
```

#### Skew-T diagram rendering
```
dskewtx_  dskewty_  dptlclskewt_  dpwskewt_  dsatlftskewt_
dshowalskewt_  dtdaskewt_  dtmrskewt_  DCAPETHERMOS_W  etc.
```
Only needed if rendering Skew-T diagrams. Separate concern from windgrams.

#### BLIP file I/O
```
read_blip_data_info_  read_blip_data_size_  read_blip_datafile_
output_mapdatafile_   datafile_unzip_
```
DrJack's proprietary BLIP data format. Not relevant for a WRF-based pipeline —
we read wrfout directly.

#### GRIB coordinate utility
```
arrayw3fb12_   W3FB12: Lambert/polar stereographic ↔ lat/lon transform
```
Replaceable with pyproj or cartopy.

---

## Actual Call Inventory

Inventory of every active (non-commented) call across the codebase.

### `rasp.bparam_calc.ncl` — soaring parameter calculations (critical file)

Loaded by `rasp.ncl`. This is where all boundary layer soaring indices are computed
from WRF output fields. Every call writes its result into `bparam` (2D output array)
or a named variable.

| Function | Call Signature | Count | Purpose |
|---|---|---|---|
| `calc_wstar` | `(vhf, pblh, isize, jsize, ksize, wstar)` | 3 | Convective velocity scale |
| `calc_blavg` | `(field, z, ter, pblh, isize, jsize, ksize, out)` | 5 | BL-averaged quantity (u, v, qvapor) |
| `calc_hcrit` | `(wstar, ter, pblh, isize, jsize, bparam)` | 2 | Critical height for soaring |
| `calc_wblmaxmin` | `(mode, wa, z, ter, pblh, isize, jsize, ksize, bparam)` | 4 | BL max/min vertical velocity (mode 0-3) |
| `minlimit2d` | `(field, limit, isize, jsize)` | 4 | Clamp 2D array to minimum value |
| `maxlimit2d` | `(field, limit, isize, jsize)` | 2 | Clamp 2D array to maximum value |
| `calc_blinteg_mixratio` | `(qcloud, ptot, psfc, z, ter, pblh, isize, jsize, ksize, bparam)` | 1 | BL-integrated cloud water |
| `calc_aboveblinteg_mixratio` | `(qcloud, ptot, z, ter, pblh, isize, jsize, ksize, bparam)` | 1 | Above-BL integrated cloud water |
| `calc_cloudbase` | `(qcloud, z, ter, crit, maxht, lag, isize, jsize, ksize, bparam)` | 1 | Cloud base height |
| `calc_blcloudbase` | `(qcloud, z, ter, pblh, crit, maxht, lag, isize, jsize, ksize, bparam)` | 1 | BL cloud base height |
| `calc_blmax` | `(field, z, ter, pblh, isize, jsize, ksize, bparam)` | 2 | BL maximum of a field (rh, cldfra) |
| `calc_subgrid_blcloudpct_grads` | `(qvapor, qcloud, tc, pmb, z, ter, pblh, crit, isize, jsize, ksize, bparam)` | 2 | Sub-grid BL cloud fraction |
| `calc_sfclclheight` | `(pmb, tc, td, z, ter, pblh, isize, jsize, ksize, bparam)` | 1 | Surface LCL height |
| `calc_blclheight` | `(pmb, tc, qvaporblavg, z, ter, pblh, isize, jsize, ksize, bparam)` | 1 | BL cloud layer height |
| `calc_sfcsunpct` | `(jday, gmthr, alat, alon, ter, z, pmb, tc, qvapor, isize, jsize, ksize, bparam)` | 1 | Surface sunshine percentage |
| `calc_hlift` | `(threshold, wstar, ter, pblh, isize, jsize, bparam)` | 1 | Thermal lift height |
| `calc_blwinddiff` | `(ua, va, z, ter, pblh, isize, jsize, ksize, bparam)` | 1 | Wind shear across BL |
| `calc_bltop_pottemp_variability` | `(thetac, z, ter, pblh, isize, jsize, ksize, critdegc, bparam)` | 1 | BL top potential temperature variability |
| `calc_qcblhf` | `(rqcblten, mu, z, ter, pblh, isize, jsize, ksize, bparam)` | 2 | Cloud base height factor |
| `min_2darrays` | `(a, b, out, flag, isize, jsize)` | 2 | Element-wise min of two 2D arrays |
| `count_2darray` | `(field, value, tol, isize, jsize, ncount)` | 3 | Count cells matching a value |

### `windgrams.ncl` — windgram point forecasts

| Function | Call Signature | Count | Purpose |
|---|---|---|---|
| `minlimit2d` | `(vhf(i,:,:), 0.0, numx, numy)` | 1 | Clamp heat flux ≥ 0 |
| `calc_wstar` | `(vhf(i,:,:), pblh(i,:,:), numx, numy, numlevels, wstar_1)` | 1 | w* at each time step |
| `calc_hcrit` | `(wstar_1, ter(i,:,:), pblh(i,:,:), numx, numy, hcrit_1)` | 1 | Critical height at each time step |
| `calc_sfclclheight` | `(press, tc, td, zmeter, ter, pblh, numx, numy, numlevels, sfclclheight_1)` | 1 | Surface LCL at each time step |

### `wrf_user_mass.ncl` — WRF data utilities (all replaceable by wrf-python)

| Function | wrf-python equivalent | Calls |
|---|---|---|
| `compute_tk` | `wrf.getvar(ncfile, 'tk')` | 3 |
| `compute_tk_2d` | `wrf.getvar(ncfile, 'tk')` | 1 |
| `compute_td` | `wrf.getvar(ncfile, 'td')` | 1 |
| `compute_td_2d` | `wrf.getvar(ncfile, 'td')` | 1 |
| `compute_rh` | `wrf.getvar(ncfile, 'rh')` | 1 |
| `compute_seaprs` | `wrf.getvar(ncfile, 'slp')` | 1 |
| `compute_uvmet` | `wrf.getvar(ncfile, 'uvmet')` | 1 |
| `compute_iclw` | `wrf.getvar(ncfile, 'QCLOUD')` + integration | 1 |
| `interp_3dz` | `wrf.interplevel()` | 2 |
| `interp_2d_xy` | `wrf.interpline()` / `wrf.vertcross()` | 8 |
| `interp_1d` | `scipy.interpolate.interp1d` | 1 |
| `z_stag` | `wrf.getvar(ncfile, 'z')` | 4 |
| `filter2d` | `scipy.ndimage.uniform_filter` | 1 |
| `get_ij_lat_long` | `wrf.ll_to_xy()` | 1 |

### `blipmap.ncl` — BLIP data rendering (not needed for WRF pipeline)

Uses `read_blip_datafile` (14 calls), `output_mapdatafile` (3),
`read_blip_data_info` (2), `calc_latlon` (1), and various utility functions.
All related to DrJack's proprietary BLIP data format. **Not relevant for the
WRF-based pipeline** — we read wrfout directly via wrf-python.

### Unused functions (exported from .so but never called)

- `calc_cape2d` — 0 calls (CAPE available via `wrf.getvar(ncfile, 'cape_2d')`)
- `arrayw3fb12` — 0 calls (coordinate transform, replaceable by pyproj)
- `compute_pi` — 0 calls (Exner function)
- `calc_bltopwind` — 0 calls

---

## Rewrite Scope

| Component | Status | Approach |
|---|---|---|
| `wrf_user_fortran_util_0-64bit.so` | Drop entirely | wrf-python covers all |
| Standard WRF diagnostics from ncl_jack | Drop | wrf-python |
| Soaring index calculations | **Reimplement** | ~300 lines Python, published equations |
| Skew-T rendering | Skip (not in windgrams) | Future work if needed |
| BLIP file I/O | Skip | Not used in WRF pipeline |
| NCL rendering (windgrams.ncl, rasp.ncl) | **Reimplement** | matplotlib + cartopy |

---

## Soaring Index Physics

The soaring calculations are based on published boundary layer meteorology.
Key references:

- **w\*** (convective velocity scale): Deardorff (1970)
  `w* = (g/T * BL_depth * surface_heat_flux)^(1/3)`

- **BL depth**: diagnosed from WRF's `PBLH` field or computed from
  potential temperature profile (parcel method)

- **Thermal updraft velocity** (`wblmaxmin`): derived from w* with
  vertical profile weighting

- **Cloud base / LCL**: lifted condensation level from surface T and Td
  `LCL_height ≈ 125 * (T_surface - Td_surface)` (empirical approximation)
  or exact from Bolton (1980)

- **Sunshine fraction**: fraction of grid cells with downward shortwave
  radiation above a threshold (proxy for cumulus convection)

All equations are available in DrJack's BLIPMAP documentation at drjack.info
and in standard atmospheric science texts (e.g. Stull, "Meteorology for
Scientists and Engineers").

---

## Implementation Plan

### Phase 1: Drop `wrf_user_fortran_util_0-64bit.so`

Replace all calls in NCL scripts with wrf-python equivalents. Verify output
matches the existing NCL pipeline numerically before proceeding.

### Phase 2: Reimplement soaring indices in Python

Write a `rasp/soaring.py` module with the ~12 core calculation functions.
Each function takes NumPy arrays matching the wrf-python output shapes.

```python
# Example interface
import wrf
import numpy as np

def calc_wstar(hfx, pblh, t2):
    """Convective velocity scale (Deardorff 1970).
    hfx:  surface upward heat flux (W/m^2)
    pblh: PBL height (m)
    t2:   2m temperature (K)
    returns: w* (m/s)
    """
    g = 9.81
    rho_cp = 1200.0  # approximate rho * Cp (J/m^3/K)
    buoyancy_flux = (g / t2) * (hfx / rho_cp)
    wstar = np.where(buoyancy_flux > 0,
                     (buoyancy_flux * pblh) ** (1/3),
                     0.0)
    return wstar
```

### Phase 3: Replace NCL rendering

Rewrite `windgrams.ncl` and `rasp.ncl` using matplotlib + cartopy. The
windgram layout (vertical profiles at a point, plan-view maps) is
straightforward in matplotlib.

Output format: PNG files with the same naming convention as the current
NCL output so downstream scripts (upload, web display) require no changes.

### Phase 4: Remove NCL from the image

Drop NCL from `Dockerfile.windgram`. The image shrinks significantly.
Arm64 and amd64 images are now identical in capability.

---

## Testing Strategy

For each phase, validate against the existing x86_64 NCL pipeline:

1. Run the existing pipeline on a known date, save all intermediate and
   final outputs
2. Run the new Python pipeline on the same wrfout files
3. Compare windgram PNGs visually and key field values numerically
   (BL top within 50m, w* within 0.1 m/s, cloud base within 100m)
4. Compare against actual pilot reports / OLC flights for that day

The third validation (against actual flying) is the ground truth — numerical
agreement with the old pipeline is necessary but not sufficient.

---

## Dependencies

```
wrf-python       # WRF diagnostic calculations
numpy            # array math
matplotlib       # windgram and map rendering
cartopy          # map projections
scipy            # interpolation utilities
netCDF4          # reading wrfout files directly if needed
```

All available on arm64 via conda-forge or pip.

---

## Status

- [x] Inventory all NCL script calls to ncl_jack_fortran.so functions
- [x] Verify wrf-python coverage of wrf_user_fortran_util functions
- [ ] Implement `rasp/soaring.py` with core soaring indices
- [ ] Validate soaring.py numerically against existing pipeline
- [ ] Rewrite windgrams.ncl in Python
- [ ] Rewrite rasp.ncl in Python
- [ ] Remove NCL from Dockerfile
- [ ] Validate windgram output against pilot reports
