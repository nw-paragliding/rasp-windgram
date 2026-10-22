# HRRR through the DrJack chain — A/B against the NAM product

Status (2026-10-22): pair 1 complete, pair 2 pending. Branch `feat/hrrr-drjack-ab` → PR #17
(0.6.1). These pairs are the evidence attached to that PR and to the pnw-soaring PR
`feat/hrrr-drjack-site`, which converts the site's HRRR product to this chain under the label
"HRRR (beta)"; `examples/cascades-hrrr-drjack.yaml` is the reference config in this repo.
**James reviews the tables and montages and decides what goes live; they are an aid, not a
verdict.**

## 1. Question

The site runs two products. The NAM-driven chain (`examples/cascades.yaml`: parent → WRF 4 km →
1.33 km, DrJack physics, `e_vert 52`, 3 h boundaries) is the good one. The HRRR product is a
different chain (HRRR 3 km → WRF 1 km nest, default MYNN/Thompson/Noah physics, hydrometeor
initialisation, `w_damping`) and is unstable and forecasts worse. `RRFS_MIGRATION.md` §10 lists
the obvious candidate fix: route HRRR through the *same* DrJack chain the NAM product uses, with
HRRR 3 km only supplying initial/boundary conditions, exactly as RRFS does from Nov 3.

This A/B asks one thing: **for the same pinned cycle and soaring day, how far is the
HRRR-driven DrJack chain from the NAM-driven DrJack chain on the production Cascades grid?**
It does not compare against the current HRRR 1 km nest (that product is on a different grid and
physics; a three-way comparison is a follow-up if James wants it).

## 2. The two arms

Everything is identical except the parent model and the ungrib Vtables:

| | A: NAM (production) | B: HRRR-DrJack (candidate) |
|---|---|---|
| config | `examples/cascades.yaml` | `examples/cascades-hrrr-drjack.yaml` |
| parent | NAM 12 km, `awip3d`, 3 h | HRRR 3 km, `wrfprs` (+ `wrfsfc`), every 3rd hour |
| WRF chain | 4 km (59²) → 1.33 km (115²), `e_vert 52`, Ferrier / RRTM / Dudhia / MM5 sfclay / YSU, `radt 10`, 3 h boundaries | same — `namelist.wps` and `namelist.input` are byte-identical (checked by generating both) |
| geo_em | same grid (same `center`, `outer_dx_km 4.0`, `target_dx_km 1.33`, `inner_extent_km 150`) → cubes difference directly | same |
| ungrib atmosphere | `Vtable.NAM` | `Vtable.RAP.pressure.ncep`: T/U/V/RH/HGT on 40 isobaric levels (50–1013 mb), 2 m T/RH/q, 10 m wind, PSFC, PMSL, terrain, snow, skin T. **No hydrometeors** (the nest's `Vtable.HRRR.full` adds QC/QR/QI/QS/QG; not used here, so WRF spins up its own clouds, as from NAM) |
| ungrib soil | NAM 4 layers (in `Vtable.NAM`) | second pass `Vtable.raphrrr`: 9 RUC levels from `wrfprs`; `real.exe` interpolates to Noah's 4 layers (`num_metgrid_soil_levels = 9`, like RRFS) |
| download | full `awip3d` files | `.idx` byte ranges: wrfprs 420 → ~215 MB (38 ranges), wrfsfc 148 → ~20 MB; full file is the fallback |
| direct reader | n/a | off (`direct_reader: false`) |

Plumbing added for arm B (`rasp/pipeline.py` `DOMAIN_MODEL_OVERRIDES`): a domain YAML may
override `direct_reader` (already possible), `vtable`, `sfc_vtable`, `idx_subset`,
`sfc_idx_subset`, `idx_max_gap_mb`. An absent key leaves the registry entry untouched, so
`MODELS["hrrr"]` and every existing config (production nest, NAM, RRFS) behave exactly as before.

## 3. Protocol

Same as `RRFS_MIGRATION.md` §5: one pinned cycle, same `--target-date`, same sites
(`examples/issaquah-sites.csv`, 15 points around Issaquah / North Bend), same flags; only the
config differs. Both arms run as a matrix on `ubuntu-24.04-arm` from an image built from this
branch (`.github/workflows/test-ab.yml`, tag
`[ab cascades <cycle_date> <cycle> <target_date> nam hrrr=cascades-hrrr-drjack]`), and the
compare job (`scripts/ab_compare.py --labels NAM HRRR`) differences the two `soaring.zarr`
cubes and builds a side-by-side windgram montage per site. Metrics per site per hour, summarised
over the afternoon (12:00–17:59 local): BL top (ft AGL), w* (fpm), soaring ceiling, BL wind,
2 m T, surface LCL, sensible heat flux. Δ = HRRR − NAM; |Δ| median / p90 and the signed bias.

Cycles (HRRR major cycles reach 48 h, so same-day or next-day soaring windows are reachable;
the 12z → same-day pair is the production "12z product" configuration, fhr 3–15; the 00z →
same-day pair is fhr 15–27):

| pair | cycle | soaring day | WRF window | run | status |
|---|---|---|---|---|---|
| 1 | 2026-10-21 12z | Wed 2026-10-21 | fhr 3–15 (15z → 03z) | [actions/runs/39705498207](https://github.com/nw-paragliding/rasp-windgram/actions/runs/39705498207) (artifacts `ab-cascades-nam`, `ab-cascades-hrrr`, `ab-compare-cascades-nam-vs-hrrr`, `ab-debug-cascades-*`; local copy `~/rasp-data/ab/pairs/cascades-hrrr-drjack-20261021-12z/`) | both arms complete, §4 |
| 2 | 2026-10-22 00z | Thu 2026-10-22 | fhr 15–27 (15z → 03z) | starts from the tagged commit on the branch (`[ab cascades 2026-10-22 00 2026-10-22 nam hrrr=cascades-hrrr-drjack]`) at the next push | pending |

## 4. Results

### Pair 1 — 2026-10-21 12z → Wed 2026-10-21 (run 39705498207)

**Completion.** Both arms ran to the end on `ubuntu-24.04-arm`: 13 hourly steps 8 am – 8 pm
PDT, 114 × 114 cube on the same grid, 15/15 windgrams, zero NaNs anywhere in either cube. HRRR
arm: `.idx` subsets 5 × 211–219 MB (wrfprs, 38–40 ranges) + 5 × 19–20 MB (wrfsfc, 4 ranges), no
fallback to a full file; ungrib `Vtable.RAP.pressure.ncep` 5 intermediates, `Vtable.raphrrr` 5;
metgrid 10 files; `num_metgrid_levels 41`, `num_metgrid_soil_levels 9` (NAM arm: 40 / 4);
real.exe and wrf.exe clean (`SUCCESS COMPLETE WRF` in both arms). Wall time 45 min (HRRR, incl.
a 6 min GEOG download on a cache miss) vs 41 min (NAM) — the same chain costs the same.

**Pooled over the 15 sites, afternoon (12:00–17:59 local), Δ = HRRR − NAM:**

| Metric | n | median \|Δ\| | p90 \|Δ\| | bias |
|---|---|---|---|---|
| BL top (AGL) (ft) | 90 | 277 | 721 | +68 |
| w* (fpm) | 90 | 32 | 87 | −33 |
| Soaring ceiling (ft) | 90 | 0 | 1 | −0 |
| BL wind speed (kt) | 90 | 3 | 8 | +3 |
| BL wind dir (deg) | 90 | 40 | 146 | −23 |
| 2 m temperature (F) | 90 | 2 | 4 | +1 |
| Sfc LCL (AGL) (ft) | 90 | 6566 | 8413 | +6548 |
| Sensible heat flux (W/m²) | 90 | 32 | 63 | −33 |

Whole inner grid at 14:00 local: soaring ceiling median |Δ| 1 ft (bias −49 ft), w* median |Δ|
36 fpm (bias −30 fpm); `diffmap_tol.png` shows the ceiling differences confined to patches in
the north-east and south of the domain (±600 ft), the rest identical (terrain-pinned).

**Per site (afternoon medians; full hourly tables in `compare.md`):**

- *Tiger / Poo Poo Point / West Tiger 3* — BL top within 250 ft (HRRR +150…+250 at the
  launches, −170 at West Tiger 3), w* 30–55 fpm weaker in the HRRR arm (NAM 140–160 fpm peak at
  1 pm, HRRR 125), ceiling identical (terrain), BL wind +2…+4 kt and within 10°, 2 m T within
  1 °F. The HRRR arm's thermal window is shorter: NAM has w* > 0 from 11 am to 3 pm, HRRR from
  noon to 2 pm.
- *North Bend valley: Rattlesnake, Mailbox, Si Main, Si Haystack, Teneriffe, Cedar Butte* — the
  largest divergence. BL wind +4…+10 kt in the HRRR arm with directions 50–145° apart, and the
  montages show why: the HRRR arm carries a 20–25 kt layer between ~3000 and ~5000 ft all
  afternoon (orange/red band in `montage_MailboxPk.png`), where the NAM arm has 10–15 kt. BL
  top +200…+600 ft (HRRR higher), 2 m T +3 °F, w* within 35 fpm.
- *Western foothills: Squak, Cougar, Grand Ridge* — HRRR arm BL top 200–400 ft lower and w*
  50–75 fpm weaker; winds within 1–5 kt.
- *High terrain: Bandera, McClellan Butte* — closest pair: BL top within 350 ft, w* within
  50 fpm, winds within 1 kt / 10°; HRRR 3–4 °F cooler at 2 m.
- *All sites* — the surface LCL differs by 2,600–8,600 ft: the NAM arm keeps a saturated layer
  (RH > 94 %, grey hatching) at the surface through the afternoon with cumulus symbols at
  5,000–6,000 ft, the HRRR arm dries out by late morning and shows no cloud.

Montages (`compare/montage_<site>.png`): Tiger, PooPooPt, WestTiger3, Rattlesnake, MailboxPk,
SiMain, SiHaystack, Teneriffe, GreenMtn, CedarButte, SquakMtn, CougarMtn, GrandRidge, BanderaMtn,
McClellanButte; plus `diffmap_tol.png`, `compare.md`, `summary.json`.

### Pair 2 — 2026-10-22 00z → Thu 2026-10-22

Pending (starts on the next push of the branch).

## 5. Things to look at / flags

1. **Weak day, ceiling uninformative.** Oct 21 was marginal: the soaring ceiling sits at terrain
   at all 15 sites in both arms, so the ceiling metric says nothing for this pair; BL top and
   w* carry the signal (HRRR arm ~30 fpm weaker, thermal window ~1–2 h shorter). A stronger day
   (pair 2 or later pairs) is needed before reading anything into the w* bias.
2. **Low-level moisture.** Identical physics, so the saturated afternoon surface layer in the NAM
   arm versus the dry HRRR arm (sfc LCL +6,500 ft) comes from the parents' initial moisture and
   soil state (NAM 4-layer Noah soil and its 40 km analysis vs HRRR's 9-level RUC soil and 3 km
   analysis). Which one verified on Oct 21 is checkable against KSEA/KBFI/KRNT 2 m dewpoints and
   ceilings; not done here.
3. **Wind layer over the North Bend valley.** The HRRR arm's 20–25 kt band at 3,000–5,000 ft
   (Mailbox, Si, Rattlesnake, Cedar Butte) versus 10–15 kt in the NAM arm is the difference a
   pilot would notice. HRRR's own analysis usually resolves Cascade gap flow better than NAM at
   40 km, but this is unverified; worth comparing with the live HRRR nest product for the same
   day and with any valley wind observations.
4. **Sensible heat flux −33 W/m² in the HRRR arm** (−50 to −65 at Tiger and Cougar) despite a
   slightly warmer surface, which drives the weaker w*. The likely cause is the soil state the
   RUC 9-level fields hand to Noah (moisture/temperature), the same mechanism RRFS brings; a
   look at `SM000010`/`ST000010` in the two arms' `met_em.d02` would settle it. Not done here.
5. **Surface wind patches late afternoon at Tiger (HRRR arm).** Orange/red cells at ground level
   4–7 pm in `montage_Tiger.png` while w* is 0: a near-surface wind band, not lift. Check the
   10 m wind in the cube for those hours.
6. **Nothing failed and nothing is NaN**: the chain is as stable with HRRR as with NAM, which
   was the point of the conversion (the 1 km nest's instability was the reason for it).

## 6. Who decides, and what follows

James reviews the montages and tables; the conversion goes live as "HRRR (beta)" by his
decision and is judged on the site. Follow-ups, none started: more pairs on stronger days
(the harness runs one per tagged push); a three-way pair (old 1 km nest vs this chain vs NAM) if
a direct comparison with the previous HRRR product is wanted; promoting the `.idx` patterns into
`MODELS["hrrr"]` once the `Vtable.HRRR.full` union is verified; the soil-state check in §5.4.
Rollback of the site is a revert of the pnw-soaring PR (the old nest config and its geo_em asset
stay in git history and on the `geo-em-v1` release).

## 7. Re-running

```bash
# runner pair (push to a feat/** branch with the tag in the commit message)
git commit --allow-empty -m "pair [ab cascades 2026-10-22 00 2026-10-22 nam hrrr=cascades-hrrr-drjack]"

# locally (either arm), e.g. inside the windgram image
python3 -m rasp.pipeline examples/cascades-hrrr-drjack.yaml --sites examples/issaquah-sites.csv \
    --date 2026-10-21 --cycle 12 --target-date 2026-10-21 --output-dir /mnt/output --num-procs 4
uv run --extra cube --with matplotlib python scripts/ab_compare.py \
    --a out/nam --b out/hrrr --labels NAM HRRR --sites examples/issaquah-sites.csv --utc-offset -7 --out compare
```
