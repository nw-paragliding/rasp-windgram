# DrJack's RASP Source Code

## Original Distribution

- **Official tarballs**: `http://www.drjack.info/RASP/DOWNLOAD/` — contains `rasp_scripts.tar.gz`, `rasp_ncl.tar.gz`, `drjack_utils.tar.gz`, etc.
- **DrJack's site**: `http://www.drjack.info/`

## Most Complete GitHub Mirrors

**[CazYokoyama/wrfv3](https://github.com/CazYokoyama/wrfv3)** — the most complete repository (18 forks)

- Full RASP installation: WRF v3, WPS, GM (BLIPMAP/NCL plotting), NCL scripts, domain wizard
- `GM/` contains the core NCL calculation scripts: `calc_funcs.ncl` (wstar, CAPE, BL height, cloud base, wind shear, soaring indices)
- Contains the compiled `ncl_jack_fortran.so` — **the Fortran source was never publicly released**, only the `.so` binaries

**[wargoth/rasp-gm](https://github.com/wargoth/rasp-gm)** — DrJack's GM (Graphical Model) subsystem

- NCL scripts (49.9%), Perl (39.4%), Shell (2.3%)
- `GM/` has the same calc scripts; `bin/GM-master.pl` is the main orchestrator

## Windgram-Specific Code

The windgrams were written by **TJ Olney** (not DrJack):

- **[ToninoTarsi/windgramtt](https://github.com/ToninoTarsi/windgramtt)** — best available NCL windgram script (`windgramtt.ncl`), a customization of TJ Olney's original
- **Original script**: `http://wxtofly.net/rasp_scripts/windgramtj.ncl`
- **Documentation**: `http://wxtofly.net/windgramexplain.html`

## Key Architectural Note

DrJack's core soaring calculation routines (`ncl_jack_fortran.so`) were distributed only as **compiled Fortran shared objects** — no source. This project's `rasp/soaring.py` rewrites all 21 of those functions in NumPy.

## Other Notable Forks/Rewrites

| Repo | Description |
|------|-------------|
| [wargoth/rasp-docker-script](https://github.com/wargoth/rasp-docker-script) | Docker packaging of DrJack's WRF v2/v3 code |
| [oriolcervello/raspuri](https://github.com/oriolcervello/raspuri) | Python/Bash rewrite for WRF v4 (still uses Fortran `.so`) |
| [sfalmo/rasp-from-scratch](https://github.com/sfalmo/rasp-from-scratch) | Clean-room Docker WRF build with NCL plotting |
| [ajberkley/canadarasp](https://github.com/ajberkley/canadarasp) | Canada RASP infra with windgram generation |
| [RASPWeather/rasp-meteogram](https://github.com/RASPWeather/rasp-meteogram) | NCL meteogram for spot locations |
