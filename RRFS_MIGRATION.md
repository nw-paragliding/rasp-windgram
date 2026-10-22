# RRFS migration plan — add RRFS alongside NAM before 2026-11-03

Status: phase 1 IN PROGRESS on branch `feat/rrfs-model` (2026-10-21, 13 days before NAM
retirement). Built so far: `MODELS["rrfs"]` registry entry, `vtables/Vtable.RRFS`, the `.idx`
byte-range downloader (`_fetch_grib_subset`, keep-alive `http.client`), `RASP_RRFS_ROOT` override,
`utc_offset:` YAML key, `ab/phoenix.yaml` + `phoenix-sites.csv`, `scripts/ab_compare.py`,
`.github/workflows/test-ab.yml` (push to `feat/**` with `[ab phoenix 2026-10-21 18 2026-10-22]`
in the commit message; `workflow_dispatch` only after merge to main).

**Daily pairs run on the arm runners through Nov 2 and publish to an unlisted page on the site** (`forecast.nwparagliding.com/lab/ab/`, noindex) via
`pnw-soaring/.github/workflows/ab-pairs.yml` (builds the image from this branch; Phoenix from `ab/`; schedule needs it on
pnw-soaring main — PR opened). Until then, pairs start from a tagged push there. `test-ab.yml` here stays the dev harness. **Phoenix is a test-only
fixture** (`ab/phoenix.yaml`, not shipped in the image, not a site product); it appears only on the unlisted lab page. Dev pairs here run on
demand with `[ab phoenix ...]`.

**First pair (2026-10-21, Phoenix, 18z → soaring day Oct 22): reviewed by James, "looks right".**
Both arms completed on the arm runners in ~25 min (vs ~45 min per arm in the local 5 GiB VM);
the local NAM arm reproduces the runner NAM arm exactly (zero difference in every metric). RRFS
arm: ungrib/metgrid/real all clean with `Vtable.RRFS`, 46 metgrid levels, 9 soil levels, 13
hours, 7/7 windgrams, no NaNs. Pooled afternoon RRFS − NAM: BL top median |Δ| 698 ft (bias
+562), w* 47 fpm (+17), ceiling 495 ft (+357), BL wind 3 kt / 9°, 2 m T +2 °F, sfc LCL +1280 ft
(RRFS warmer and drier at the surface). Largest site divergence at McDowell Mtn (RRFS ceiling
~5,000 ft vs NAM pinned at terrain mid-afternoon), traceable to the parents disagreeing on
afternoon cloud cover on a moist day. Results: `~/rasp-data/ab/pairs/phoenix-20261021-18z-runner/`
(compare.md, diffmap_tol.png, montage_<site>.png). Not yet done: more pairs (plan: ≥ 4 incl.
Cascades), direct-reader generalization (option B), legacy script cleanup, version bump / image
release, any pnw-soaring change.

Decisions locked 2026-10-21:

1. **No cutover.** RRFS is added as a **third model** (toggle order NAM | RRFS | HRRR; NAM stays
   the default). Removing NAM is a separate step after NCEP kills it.
2. **Option A**: RRFS CONUS 3 km feeds the *unchanged* DrJack WRF chain (4 km → 1.33 km,
   `e_vert 52`, DrJack physics). The RRFS direct reader is built as a fallback.
3. **Acceptance gate before any site work:** an A/B of NAM-driven vs RRFS-driven generation on a
   Phoenix test domain (real late-October thermals) and on the Cascades production domain.
4. Boundary interval stays **3 h** like NAM (hourly becomes a yaml knob later).
5. **Two RRFS runs a day** (00z/12z), no new Cloudflare crons.
6. The **`.idx` byte-range downloader** is part of phase 1.

Defaults unless overridden: toggle label "RRFS 1.3 km", slug `rrfs`.

## TL;DR

- **NCEP deletes NAM from NOMADS on Monday 2026-11-03 at 12 UTC** (SCN 26-47 / 26-48, latest
  revision 2026-10-02). The `nam.YYYYMMDD/` directories, `awip3d` files and the NAM grib filter go
  away the same day RRFS v1 goes operational. HRRR and RAP are **not** retired (they stay until
  RRFS v2, ~2027-28).
- **What survives is the chain, not the model.** The product that "works better" today is
  `cascades.yaml`: WRF 4 km → 1.33 km, DrJack physics (YSU / Ferrier / RRTM+Dudhia / MM5
  sfclay), 52 levels, 3-hourly boundaries. None of that is NAM-specific. RRFS 3 km supplies
  initial/boundary conditions instead of NAM 12 km; a 3 km parent is a *better* source for the 4 km
  outer domain than 12 km was. The geo_em files are unchanged, so the existing release asset is
  reused.
- **Not the template:** the HRRR 3 km → 1 km nest (unstable, worse forecasts).
- **A/B first.** Because NAM disappears on Nov 3, NAM-vs-RRFS comparisons are only possible
  until then. The Phoenix A/B has to run in the window Oct 23 – Nov 2.
- **RRFS parallel data is live now** at `…/com/rrfs/v1.0/` (also `/rrfs/para/`) with the exact
  post-cutover layout. The documented production path from Nov 3 is `…/com/rrfs/prod/`; the
  `v1.0` versioned alias should persist.
- **Nov 3 itself is low-stakes under this plan**: RRFS is already on the site; the only same-day
  action is to stop dispatching the NAM workflow (which will otherwise fail every run) and check
  the RRFS URL root.

---

## 1. What NCEP is changing (verified against live NOMADS, 2026-10-21)

| Item | NAM (today) | RRFS v1 (replacement) |
|---|---|---|
| Retire / go-live | removed 2026-11-03 12Z | operational 2026-11-03 12Z |
| Dynamics | NMMB, 12 km NA | FV3-LAM, 3 km NA; CONUS/AK subsets at 3 km |
| Cycles | 00/06/12/18, all to 84 h | **hourly**; 00/06/12/18 to **84 h**, other cycles to 18 h |
| Output interval | 3 h (awip3d) | **1 h** |
| Para/pre-cutover path | — | `https://nomads.ncep.noaa.gov/pub/data/nccf/com/rrfs/v1.0/` (also `/rrfs/para/`) |
| Post-cutover path | `…/com/nam/prod/nam.YYYYMMDD/` (gone) | `https://nomads.ncep.noaa.gov/pub/data/nccf/com/rrfs/prod/rrfs.YYYYMMDD/CC/` |
| 3-D file | `nam.tCCz.awip3dFF.tm00.grib2` (~11 MB; 3-D + sfc + soil in one file) | `rrfs.tCCz.prslev.3km.fFFF.conus.grib2` (**~535 MB**; pressure levels ONLY) |
| 2-D file | (same file) | `rrfs.tCCz.2dfld.3km.fFFF.conus.grib2` (**~320 MB**; surface, soil, fluxes, 2 m / 10 m) |
| Index | — | every file has a `.grib2.idx` (byte offsets → range-request subsetting works) |
| Grid (CONUS) | 12 km Lambert, grid 218 | **identical to the HRRR CONUS grid**: Lambert 1799×1059, 3000 m, lat1 21.138 lon1 237.280, LoV 262.5, LatD 38.5 (verified with `grib_ls` on a live file) |
| Pressure levels | 1000→50 mb at 25 mb + a few upper | 45 levels: 1000→100 mb at 25 mb, then 70,50,30,20,10,7,5,2 (no 1013 mb level; HRRR has one) |
| Soil | 4 Noah layers (0-10/10-40/40-100/100-200 cm) | 9 RUC levels (0,1,4,10,30,60,100,160,300 cm) — same encoding as HRRR |
| Hydrometeors on p-levels | CLMR/CICE | CLMR, RWMR, **ICMR** (0/1/23, not CICE), SNMR, GRLE |
| Sea-level pressure | PRMSL + MSLET | **MSLET only** (GRIB2 0/3/192 — same code `Vtable.NAM` already uses) |
| Grib filter | `gribfilter.php?ds=nam` | **none for RRFS** → subset via `.idx` byte ranges instead |
| Publish time, 00z cycle | f06 01:43Z · f24 01:59Z · f48 02:20Z · f84 02:41Z | f00 01:47Z · f06 02:00Z · f12 02:09Z · f24 02:18Z · f30 02:23Z · f48 02:44Z · f60 02:57Z · f84 03:22Z |
| Publish time, 12z cycle | ~cycle+1:45 to +2:40 | f00 13:47Z · f12 14:08Z · f24 14:17Z · f36 14:31Z · f48 14:43Z · f84 15:23Z |

Also new, for later (not part of this plan):

- `rrfsens.YYYYMMDD/CC/m001..m005/…prslevnomads.3km.fFFF.conus.grib2` — five perturbed
  members to 60 h, 14 pressure levels (too coarse for a windgram; fine for a spread indicator).
- `refs/v1.0/refs.YYYYMMDD/CC/ensprod/refs.tCCz.{mean,sprd,prob,pmmn,…}.fFF.conus.grib2` —
  REFS ensemble products (HREF replacement), 2-D only, 3-hourly to f48 then 6-hourly to f60.

Dropped NAM fields that we use: none (`www.emc.ncep.noaa.gov/rrfs_info/nam_retirements.txt`;
only the 4 → 9 soil-level change and VVEL → DZDT are relevant).

## 2. Where NAM is wired in today

**rasp-windgram** (the image / Python package)

| File | NAM dependency |
|---|---|
| `rasp/namelist_generator.py` `MODELS["nam"]` | `dx 12000`, `Vtable.NAM`, 3 h interval, fhr 6-84, 4 cycles, NOMADS `url_pattern` with 2-digit fhr |
| `rasp/pipeline.py` | `_download_grib` (one `url_pattern` + optional `sfc_url_pattern`), `_detect_latest_cycle`, best-cycle probe (HEAD on first/last fhr), `--target-cycle` polling, direct-reader globs `*wrfprs*`/`*wrfsfc*`, Vtable symlink + optional second soil pass, `_utc_offset_from_lon` |
| `scripts/get_nam_grib.sh`, `scripts/run_wps.sh` | legacy shell path; `run_wps.sh` hard-links `Vtable.NAM` |
| `docker/Dockerfile.windgram` | copies `scripts/get_nam_grib.sh`; copies `vtables/` into `Variable_Tables/` |
| `examples/cascades.yaml` | `model: nam`, `outer_dx_km: 4.0`, DrJack physics |
| `README.md`, `ARCHITECTURE.md`, `CLAUDE.md` | NAM wording, `--http1.1` note |

**pnw-soaring** (the production site)

| File | NAM dependency |
|---|---|
| `domains/cascades.yaml` | `model: nam` (same geometry as the example) |
| `.github/workflows/forecast-nam.yml` | `repository_dispatch: run-nam`, 2-day matrix, geo_em cache key `geo-em-cascades-nam-v2` + release asset `geo_em_nam-v2.tar.gz`, deploy slug `nam`, R2 prefix `nam/` |
| `cloudflare-trigger/wrangler.toml` + `src/worker.js` | crons `5 2 * * *` and `0 14 * * *` → `run-nam`; `CRON_MAP` is one dispatch per cron; free tier caps the Worker at 5 crons (3 are HRRR) |
| `.github/actions/deploy-forecast/action.yml` | generic `model` slug → `forecasts/<date>/<slug>/` |
| `.github/workflows/r2-prune.yml` | `for MODEL in nam hrrr` |
| `.github/workflows/bootstrap-geoem.yml` | `nam` default domain |
| `site/index.html`, `site/v2/index.html` | two-state segmented toggle (`value="nam"` / "NAM 1.3 km", indicator slides left/right), default model `nam`, `['nam','hrrr']` lists, `loadModel("nam")` |
| `README.md` | schedule table |

## 3. Options considered

**A. RRFS → existing DrJack WRF chain (decided).** Same `cascades.yaml` geometry and physics,
`model: rrfs`. WRF interpolates RRFS 3 km onto the 4 km outer domain, then nests to 1.33 km.
Changes are confined to: a model-registry entry, a Vtable, downloading two files per forecast hour
instead of one, and URL/timing plumbing.

Why this preserves what works: the forecast skill the community is calibrated to comes from WRF's
own boundary-layer development under DrJack's physics, not from NAM. RRFS only supplies
initial/lateral boundary conditions, terrain-consistent surface pressure, soil state and snow.
Expect some drift (RRFS soil moisture and cloud state are RUC-LSM/Thompson-derived; NAM's were
Noah/Ferrier). The A/B in §5 measures that drift.

**B. RRFS direct reader (fallback).** `hrrr_reader.py` already reads pressure-level profiles +
`SHTFL/LHTFL/HPBL` from NCEP GRIB on this exact grid. Generalize it to take 3-D fields from
`prslev` and surface fields from `2dfld`, filter flux fields to `stepType == instant` (2dfld carries
both instantaneous and 1 h-average SHTFL/LHTFL), and it renders a 3 km windgram in minutes with
no WRF. Loses the 1.33 km terrain and the DrJack physics, so it is the "never dark" net.

**C. RRFS → 1 km nest cloned from `cascades-hrrr.yaml` (rejected).** Unstable, worse forecasts;
copying it would carry those problems into the new slot.

**D. GFS → WRF (emergency only).** `MODELS["gfs"]` exists but has never run through this
pipeline. Keep as the last resort; do not invest in it now.

## 4. Field mapping: `Vtable.NAM` → RRFS

Both are NCEP GRIB2, so discipline/category/parameter codes match; the differences are *which file*
a field lives in and the soil encoding.

| metgrid field | NAM awip3d (Vtable.NAM) | RRFS file | RRFS record | Note |
|---|---|---|---|---|
| TT, UU, VV, RH, HGT on p-levels | 0/0/0, 0/2/2, 0/2/3, 0/1/1, 0/3/5 @ level 100 | **prslev** | TMP/UGRD/VGRD/RH/HGT `<N> mb` (45 levels) | unchanged codes |
| TT, RH at 2 m; UU, VV at 10 m | level 103 | **2dfld** | `TMP:2 m`, `RH:2 m`, `UGRD/VGRD:10 m above ground` | unchanged codes |
| PSFC | 0/3/0 @ sfc | 2dfld | `PRES:surface` | |
| PMSL | 0/3/192 @ 101 | 2dfld | `MSLET:mean sea level` | Vtable.NAM already uses 192 (HRRR Vtables use 198 = MSLMA, which RRFS lacks) |
| SOILHGT | 0/3/5 @ sfc | 2dfld | `HGT:surface` | |
| SKINTEMP | 0/0/0 @ sfc | 2dfld | `TMP:surface` | |
| SNOW / SNOWH | 0/1/13, 0/1/11 @ sfc | 2dfld | `WEASD:surface`, `SNOD:surface` | |
| CANWAT | 2/0/196 @ sfc | 2dfld | `CNWAT:surface` | |
| LANDSEA / SEAICE | 2/0/0, 10/2/0 @ sfc | 2dfld | `LAND:surface`, `ICEC:surface` | |
| SM000010…SM100200, ST000010…ST100200 | 4 **layers** (GRIB1 type 112 pairs) | 2dfld | `SOILW`/`TSOIL` at 9 **single depths** `0-0, 0.01-0.01, … 3-3 m below ground` | use the `Vtable.raphrrr` soil block (GRIB1 type 111, SOILM000…SOILM300 / SOILT000…SOILT300); `real.exe` interpolates to Noah's 4 layers — exactly how the HRRR nest already runs |
| QC/QR/QI/QS/QG (optional) | not used for NAM | prslev | CLMR 0/1/22, RWMR 0/1/24, **ICMR 0/1/23**, SNMR 0/1/25, GRLE 0/1/32 | `Vtable.HRRR.full` encodes QI as 0/6/0 (CICE) — wrong for RRFS. Hydrometeor init stays **off** to match the NAM-like setup; it was also a suspect in the HRRR-nest crashes |

Direct-reader needs (option B): `t, gh, r, dpt, u, v` on `isobaricInhPa` from prslev;
`sp`/`orog`/`t2m` and `shtfl`/`lhtfl`/`hpbl` from 2dfld. All present.

Byte-range subset sizes measured from the live `.idx` (per forecast hour): prslev 558 MB total →
WPS subset (TT/UU/VV/RH/HGT) ~255 MB, direct-reader subset ~333 MB; 2dfld 334 MB → needed
records ~52 MB. A range-request downloader cuts ~850 MB → ~310 MB per hour.

Domain coverage: the WRF forum thread on RRFS Vtables shows metgrid failing when a domain leaves
the CONUS grid. Cascades 4 km outer domain: 230 km centered at 47.6 N → north edge ≈ 48.6 N; the
CONUS grid's north edge at 121.4 W is 50.67 N, its west edge ~134 W. Phoenix is deep inside. Use
the **CONUS Lambert** files only — ungrib does not read the North-America rotated lat-lon (`.na.`)
files.

## 5. A/B acceptance test (before any pnw-soaring change)

**Purpose.** Show that swapping NAM for RRFS as the boundary source keeps the generated
windgrams in the same forecast family, in a region that is actually thermic in late October. This
is acceptance testing of the *generation*, not of the site. It must finish before NAM disappears
on Nov 3.

**Domains.** Two, both run in A (NAM) and B (RRFS) arms with everything else identical:

- `ab/phoenix.yaml` — a copy of `cascades.yaml` (outer 4 km, target 1.33 km,
  inner 150 km, `e_vert 52`, DrJack physics) with `name: phoenix`, `center_lat: 33.5`,
  `center_lon: -112.0`. Sonoran desert in late October: highs 85–90 °F, deep dry BL, strong
  thermals, little cloud. Inner 1.33 km domain spans ~32.8–34.2 N, ~112.8–111.2 W.
- `domains/cascades.yaml` — the production domain, for stability on the grid we actually ship.
  Thermals will be weak; this arm is about completing cleanly and tracking winds/BL top.

**Test points.** `ab/phoenix-sites.csv`: 6–8 points spanning desert floor and ridge
terrain, not necessarily launches. Candidates (approximate, confirm at implementation): Phoenix
metro floor (~33.45, −112.07), South Mountain ridge (~33.34, −112.06), Superstition foothills
(~33.40, −111.45), Estrella Mountains (~33.30, −112.35), Wickenburg desert (~33.97, −112.73),
Casa Grande flats (~32.88, −111.76). Real AZ launches (e.g. Shaw Butte, Mingus Mountain near
Jerome) can be added if we want pilot-recognizable windgrams; Mingus is outside this inner domain.

**Protocol.** For each cycle (target: 2 × 00z and 2 × 12z, more if time allows, Oct 24 – Nov 2):

1. Same `--target-date`, same auto-cycle selection, same flags, same sites; only `model:` differs.
   Pass `--utc-offset -7` for Phoenix — `_utc_offset_from_lon` always adds a DST hour and Arizona
   has none (it would compute −6).
2. Run both arms as a GitHub Actions matrix (`test-ab.yml`, `model: [nam, rrfs]`,
   `domain: [phoenix, cascades]`), uploading PNGs, `soaring.zarr`, `rsl.error.0000` and the
   namelists as artifacts. A local docker run works too (~16 min WRF per arm on 4 cores plus
   download).
3. A compare job (`scripts/ab_compare.py`) reads the two cubes (same grid → direct differencing)
   and the site list and emits a markdown table plus a side-by-side PNG montage per site.

**Metrics** per site per hour, 8 am – 8 pm local, and summarized over the afternoon peak
(12 – 5 pm): BL top (ft AGL), w* (fpm), soaring ceiling / TOL (ft), BL-average wind speed and
direction, surface temperature, LCL / cloud base, hatching (RH > 94 %) coverage. Report median
and 90th-percentile |Δ| and the signed bias, RRFS-arm minus NAM-arm.

**Proposed acceptance criteria** (thresholds to adjust once we see the first pair):

- Both arms complete for every attempted cycle: no WRF crash, no NaN at any site, no missing
  hours, `num_metgrid_soil_levels` detected as 9 for the RRFS arm.
- Self-calibrating consistency: the RRFS–NAM median |Δ| in afternoon BL top, w* and TOL is no
  larger than the NAM 00z-vs-12z median |Δ| for the same day (i.e. switching the parent model
  changes the forecast less than a six-hour cycle update does).
- No systematic afternoon bias beyond ~15 % in w*, ~500 ft in BL top, ~5 kt / 30° in BL wind.
- Optional truth check: compare both arms' 2 m T and 10 m wind at KPHX / KIWA with ASOS obs for
  the day. Phoenix has no radiosonde; Tucson's 00Z raob is outside the inner domain.

**Who decides.** The criteria above are an aid, not the gate. Claude's job is to produce the
pairs, the comparison tables and the montages and to flag anything that looks off; **James
reviews the Phoenix (and Cascades) output and accepts or rejects it.** Nothing in phase 2 starts,
and no image tag is promoted to `latest`, without that explicit acceptance.

**Accepted →** proceed to §6 phase 2. **Rejected →** diagnose (soil init, boundary mismatch,
Vtable) and re-run for review; if still rejected by Nov 2, propose the direct reader (option B) as
the third model instead, again subject to acceptance, and revisit option A against HRRR-driven
runs in the spring.

## 6. Work breakdown

### Phase 1 — rasp-windgram (image + package); no site changes

1. **Model registry** — add to `MODELS` in `rasp/namelist_generator.py`:
   ```python
   "rrfs": {
       "name": "RRFS (Rapid Refresh Forecast System)",
       "dx": 3000.0,
       "vtable": "Vtable.RRFS",            # atmosphere + surface + 9-level soil, single pass
       "interval_seconds": 10800,          # decided: 3 h boundaries like NAM (hourly exists; knob later)
       "forecast_hours": list(range(0, 85)),
       "cycles": [0, 6, 12, 18],           # only these reach 84 h
       "coverage": "CONUS subset of the NA 3 km domain",
       "source": "nomads",
       # {root} switches para (v1.0) → prod on 2026-11-03; env override RASP_RRFS_ROOT
       "url_pattern": "{root}/rrfs.{date}/{cycle}/rrfs.t{cycle}z.prslev.3km.f{fhr:03d}.conus.grib2",
       "sfc_url_pattern": "{root}/rrfs.{date}/{cycle}/rrfs.t{cycle}z.2dfld.3km.f{fhr:03d}.conus.grib2",
       "idx_subset": [...],                # VAR:LEVEL whitelist for the byte-range downloader
   }
   ```
   `_download_grib` already downloads `sfc_url_pattern` files alongside; the pipeline already links
   every `*.grib2` in the grib dir, so prslev + 2dfld for the same valid time merge in one ungrib
   pass. Make the readiness probes check **both** files for the last fhr.
2. **`vtables/Vtable.RRFS`** — Vtable.NAM's atmosphere/near-surface/surface rows + the 9-level
   soil block from Vtable.raphrrr (§4). The Dockerfile already copies `vtables/` into
   `Variable_Tables/`.
3. **`.idx` byte-range downloader** — fetch the `.idx`, keep records matching `idx_subset`,
   coalesce adjacent byte ranges, `curl -r` each block, concatenate; fall back to the full file if
   the `.idx` is missing or a range request fails. ~850 MB → ~310 MB per forecast hour; a 2-day run
   drops from ~17 GB to ~6 GB of GRIB.
4. **Pipeline plumbing** — model-driven direct-reader globs (`prs_glob`/`sfc_glob`) instead of
   `*wrfprs*`/`*wrfsfc*`; `{root}` substitution; 3-digit fhr is already handled by the format spec.
5. **Phoenix A/B assets** — `ab/phoenix.yaml`, `ab/phoenix-sites.csv`,
   `scripts/ab_compare.py`, `.github/workflows/test-ab.yml` (matrix over model × domain + compare
   job). Add a `utc_offset` key to the domain yaml so Phoenix doesn't depend on a CLI flag.
6. **Direct reader generalization** (option B) — `hrrr_reader.py` → `grib_reader.py`, 3-D from the
   prs file, 2-D from the sfc file for both models, `stepType == "instant"` filtering; HRRR
   behaviour byte-identical.
7. **Legacy scripts / docs / release** — parametrize the Vtable in `scripts/run_wps.sh`; drop or
   generalize `get_nam_grib.sh`; README/ARCHITECTURE/CLAUDE.md; bump version; tag → multi-arch
   image to GHCR (the site pins `windgram:latest`, so the tag is what makes phase 2 possible).

### Phase 2 — pnw-soaring: add RRFS as the third model (after the A/B passes)

1. `domains/cascades-rrfs.yaml` = `domains/cascades.yaml` with `model: rrfs`
   (identical geometry → reuse `geo_em_nam-v2.tar.gz` / cache key; no `bootstrap-geoem` run).
2. `.github/workflows/forecast-rrfs.yml` = copy of `forecast-nam.yml` with
   `types: [run-rrfs]`, deploy slug `rrfs`, R2 `MODEL: rrfs`, artifact names, plus a cheap
   readiness wait before the pipeline: poll the `.idx` URL of the last needed fhr (f27 for day 0,
   f51 for day 1) with `curl -sfI` every 5 min, up to 60 min. RRFS publishes ~40 min after NAM for
   the same fhr, and this keeps the pipeline in the same auto `--target-date` mode NAM uses
   (`--target-cycle` would force a fhr-0 start and a ~50 h WRF run on the day-1 leg).
3. **Cloudflare trigger** — no new crons (5-cron cap: 3 HRRR + 2 NAM). Change `CRON_MAP` values
   to lists so the two NAM crons dispatch both `run-nam` and `run-rrfs`.
4. `r2-prune.yml`: `for MODEL in nam rrfs hrrr`.
5. Site v1 + v2: three-state segmented toggle **NAM | RRFS | HRRR** (indicator width 1/3,
   three positions), RRFS labelled "RRFS 1.3 km", NAM remains default; metadata/`loadModel`
   lists become `['nam','rrfs','hrrr']`; v2 `goodModel` logic handles three.
6. README schedule table (RRFS rows); `bootstrap-geoem.yml` accepts `rrfs`.

### Phase 3 — remove NAM (separate PRs, after 2026-11-03)

1. Nov 3: remove `run-nam` from `CRON_MAP` (the NAM workflow will otherwise fail every run);
   confirm `RASP_RRFS_ROOT` (`v1.0` or `prod`).
2. Delete `forecast-nam.yml`, `domains/cascades.yaml`, `get_nam_grib.sh`; drop `nam` from
   `r2-prune.yml`, the toggles (back to two states, RRFS | HRRR, RRFS default), README; retire
   `MODELS["nam"]` or mark it `retired: "2026-11-03"`. Old `forecasts/<date>/nam/` pages age out
   after 7 days on their own.

## 7. Timeline (today is Tue 2026-10-21; NAM retirement Mon 2026-11-03 12Z)

| When | Milestone | Done means |
|---|---|---|
| Oct 21–23 | Phase 1 items 1–5: registry, Vtable.RRFS, root override, `.idx` downloader, Phoenix domain + sites + compare script; first local A/B pair (one cycle, both domains) | ungrib/metgrid/real/wrf complete for the RRFS arm; windgrams render; soil levels detected as 9; no NaNs; subset download ≈ 310 MB/fhr |
| Oct 24–Nov 1 | A/B on GitHub Actions each 00z and 12z (Phoenix + Cascades, NAM + RRFS); compare tables accumulate; direct-reader fallback built in parallel | ≥ 4 clean cycle pairs; criteria in §5 met or thresholds consciously revised |
| Oct 30–Nov 2 | James reviews the A/B pairs and accepts or rejects; on acceptance: image tagged, **phase 2** PR in pnw-soaring (third model, toggle order NAM/RRFS/HRRR) | RRFS forecasts publishing alongside NAM and HRRR; NAM still default |
| Mon Nov 3 12Z | NAM disappears | drop `run-nam` dispatch; verify RRFS URL root; nothing else changes |
| Nov 4–14 | **Phase 3** removal PRs | no `nam` left in workflows, site, prune list; RRFS default |
| Spring 2027 | Soaring-skill calibration of RRFS-driven Cascades windgrams against pilot experience | late Oct / Nov in the PNW has almost no thermal activity, which is why the A/B runs in Phoenix |

## 8. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| ungrib/metgrid choke on FV3 GRIB2 (no official RRFS Vtable; forum reports are about domain overrun and the rotated `.na.` grid, not CONUS LCC) | low–medium | CONUS files only; first local run in week 1; option B fallback |
| `real.exe` soil interpolation 9 RUC levels → 4 Noah layers | low | already exercised daily by the HRRR nest |
| A/B window closes: NAM gone Nov 3, no more pairs | certain | start pairs by Oct 24; every clean cycle pair counts; criteria are relative, not absolute |
| Phoenix domain says "pass" but Cascades behaves differently (terrain, moisture, snow) | medium | run both domains in every pair; Cascades arm gates stability even if thermals are weak |
| Para feed differs from prod after Nov 3 (path, content order, scaling) | low | root is an env override; `.idx`-driven downloader is robust to record reordering |
| RRFS later than NAM by ~40 min; shared cron fires before the needed fhr exists | high if unhandled | readiness wait in `forecast-rrfs.yml` (poll the `.idx`); NAM's auto-cycle logic unchanged |
| Download volume 11 MB → ~850 MB per fhr exhausting runner disk | medium | `.idx` subsetting in phase 1 → ~310 MB/fhr; existing mid-pipeline cleanup as backstop |
| Range requests rejected or `.idx` out of sync with the file | low | downloader falls back to the full file; NOMADS already serves HRRR this way (Herbie relies on it) |
| Forecast character drifts from "NAM" (IC soil moisture, cloud state, FV3 dynamics) | certain, magnitude unknown | that is what the A/B measures; WRF physics unchanged; recalibrate in spring |
| Three-state toggle breaks the v1/v2 segmented-control CSS | low | indicator width/positions are the only change; v2 `goodModel` fallback needs a third case |
| NAM workflow fails daily after Nov 3 until removed | certain | phase 3 step 1 on Nov 3 |
| `_utc_offset_from_lon` always adds a DST hour: wrong for Arizona year-round and for the Cascades after Nov 1 | certain | `--utc-offset -7` / yaml `utc_offset` for Phoenix; the Cascades DST bug is pre-existing and deserves its own fix (not part of this plan) |
| Cloudflare 5-cron cap | none | decided: two RRFS runs ride the NAM crons via multi-dispatch |

## 9. Decisions

Locked 2026-10-21:

1. RRFS is added as a third model, listed second (NAM | RRFS | HRRR); NAM stays default until
   removed separately after Nov 3. No cutover.
2. Option A (RRFS into the unchanged DrJack chain); option B (direct reader) built as fallback.
3. A/B acceptance of the generation on Phoenix + Cascades precedes any site change. **James is
   the acceptance gate**: Claude previews and reports, James accepts or rejects; promotion to
   phase 2 and to the `latest` image happens only on his explicit OK.
4. Boundary interval stays 3 h; interval becomes a yaml knob later.
5. Two RRFS runs a day on the existing NAM crons (multi-dispatch), no new crons.
6. `.idx` byte-range downloader in phase 1.

Defaults taken unless you say otherwise:

7. Toggle label "RRFS 1.3 km"; slug `rrfs` in gh-pages paths and R2.
8. A/B thresholds in §5 are starting points, to be tuned after the first pair.
9. Phoenix test points are terrain samples, not launches.

## 10. Later options (out of scope)

- **Route HRRR through the same DrJack 4 km → 1.33 km chain** (HRRR 3 km as the parent) instead
  of the unstable 3 km → 1 km nest. Same Vtable approach (`Vtable.HRRR.full` minus
  hydrometeors), same geo_em. The A/B tooling from §5 is reusable for that comparison.
- **Hourly boundaries** (RRFS native) once 3 h is validated.
- **Uncertainty overlay** from `rrfsens` members (5 × 14 levels, to 60 h) or REFS `sprd`
  products: BL wind / 2 m T spread as a confidence band on the windgram.
- **Hydrometeor initialization** from RRFS p-level CLMR/ICMR/RWMR/SNMR/GRLE (with the corrected
  ICMR code) as an experiment on overcast days.
- **06z/18z RRFS runs** (both reach 84 h) if a cron slot is freed.
- **Fix `_utc_offset_from_lon`** to use a real timezone lookup; the Cascades product is an hour
  off after DST ends on Nov 1.

## Sources

- SCN 26-48 (updated 2026-10-02): implementation of RRFS and REFS, effective 2026-11-03 —
  https://www.weather.gov/media/notification/pdf_2026/scn26-048_Updated_RRFS_and_REFS_Implementation_aae.pdf
- SCN 26-47 (2026-05-12): termination of NAM, SREF, HREF, HiresW, NAM MOS —
  https://www.weather.gov/media/notification/pdf_2026/scn26-47_Retirement_of_NAM_SREF_HREF_HiresW_NAM_MOS.pdf
- NCO RRFS product page (file list, inventories) — https://www.nco.ncep.noaa.gov/pmb/products/rrfs/
- EMC: NAM fields not produced by RRFS — https://www.emc.ncep.noaa.gov/rrfs_info/nam_retirements.txt
- GSL RRFS overview (HRRR remains; v2 on MPAS 2027-28) — https://gsl.noaa.gov/rrfs
- NWS RRFS webinar Q&A (RAP/HRRR not retired at this time) —
  https://www.weather.gov/media/wrn/calendar/RRFS_REF-Webinar%26RegistrationFormQANotes.pdf
- WRF forum: no WPS Vtable for RRFS; domain-overrun and rotated-grid failures —
  https://forum.mmm.ucar.edu/threads/couldnt-find-a-suitable-vtable-for-rrfs-prslev-conus-3-km-data.23171/
- Live NOMADS listings and `.idx` inventories for `rrfs/v1.0/rrfs.20261021/{00,12}/` and
  `nam/prod/nam.20261021/`, read 2026-10-21 (sizes, forecast hours, publish timestamps, grid).
