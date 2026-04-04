# syntax=docker/dockerfile:1

# =============================================================================
# RASP / WXTOFLY Windgram Environment
# =============================================================================
#
# Base: ubuntu:18.04
#
# Why not a newer Ubuntu?
#   The pre-compiled ncl_jack_fortran.so and wrf_user_fortran_util_0-64bit.so
#   both link against libgfortran.so.3 (gcc 4.x ABI). Ubuntu 18.04 is the
#   newest Ubuntu LTS that ships libgfortran3 in its repos. Ubuntu 20.04+
#   dropped the package. This image runs on any modern 64-bit Ubuntu host.
#
# The bundled NCL 6.3.0 binary (ncl_ncarg-6.3.0.Linux_Debian7.8_x86_64_nodap_gcc472)
# was built against glibc 2.13 (Debian 7) and runs fine on Ubuntu 18.04
# (glibc 2.27) due to glibc backward compatibility.
#
# Pipeline coverage (see windgram_pipeline.md):
#   Stages 5-7  : windgram generation, PNG optimization, upload    ✓ included
#   UWPNW path  : fetch UW wrfout → windgrams (no WRF needed)      ✓ included
#   Stages 1-4  : GRIB fetch, grib_prep, WRF model, RASP post-proc ∗ partial
#
#   * The 32-bit wrfsi binaries (grib_prep.exe etc.) are present.
#     WRF executables (wrf.exe, real.exe, ndown.exe) must be compiled
#     separately and mounted at $BASEDIR/WRF/WRFV2/main/ at runtime.
# =============================================================================

FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV BASEDIR=/opt/rasp

# -----------------------------------------------------------------------------
# System packages
# -----------------------------------------------------------------------------
# i386 arch is added for the pre-compiled 32-bit wrfsi binaries:
#   grib_prep.exe  gridgen_model.exe  hinterp.exe  staticpost.exe  vinterp.exe
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y \
        # Scripting runtime
        perl \
        perl-tk \
        libproc-background-perl \
        curl \
        zip \
        gzip \
        rsync \
        # PNG optimization (Stage 6)
        imagemagick \
        # NetCDF tools — wrfout inspection / ncdump
        netcdf-bin \
        # Scheduled runs
        cron \
        # Suppresses "Setting locale failed" Perl warnings
        locales \
        # X11 display libs required by the NCL renderer
        libxaw7 \
        libxmu6 \
        libxt6 \
        libsm6 \
        libice6 \
        # OpenMP runtime (linked by NCL)
        libiomp-dev \
        # gcc 4.x Fortran ABI — required by the pre-compiled .so files
        # (ncl_jack_fortran.so and wrf_user_fortran_util_0-64bit.so both
        #  have NEEDED libgfortran.so.3)
        libgfortran3 \
        # 32-bit compat layer for wrfsi binaries
        libc6:i386 \
        libncurses5:i386 \
        libstdc++6:i386 \
        zlib1g:i386 \
        multiarch-support \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

# -----------------------------------------------------------------------------
# Install repo contents into BASEDIR
# -----------------------------------------------------------------------------
# model/ maps directly to BASEDIR:
#   model/WXTOFLY/  →  /opt/rasp/WXTOFLY/
#   model/WRF/      →  /opt/rasp/WRF/
#   model/RASP/     →  /opt/rasp/RASP/
#   model/UTIL/     →  /opt/rasp/UTIL/
#   model/INSTALL/  →  /opt/rasp/INSTALL/
COPY model/ $BASEDIR/
COPY docker-run.sh $BASEDIR/docker-run.sh
RUN chmod +x $BASEDIR/docker-run.sh

# Restore symlinks that git cannot track (archived separately)
RUN tar xzf $BASEDIR/all_links.tgz -C $BASEDIR

# -----------------------------------------------------------------------------
# NCL 6.3.0 — NCAR Command Language
# -----------------------------------------------------------------------------
# Debian 7 / x86_64 binary; compatible with Ubuntu 18.04 glibc.
# Extracts to $BASEDIR/UTIL/NCARG/{bin,lib,...}
RUN mkdir -p $BASEDIR/UTIL/NCARG && \
    tar xzf \
        $BASEDIR/INSTALL/DOWNLOAD/NCL/ncl_ncarg-6.3.0.Linux_Debian7.8_x86_64_nodap_gcc472.tar.gz \
        -C $BASEDIR/UTIL/NCARG

# -----------------------------------------------------------------------------
# Fortran shared libraries for NCL
# -----------------------------------------------------------------------------
# ncl_jack_fortran.so        — DrJack's atmosphere calculation library
# wrf_user_fortran_util_0-64bit.so — WRF NCL utility library
# Both are 64-bit ELF, require libgfortran.so.3 (installed above).
RUN mkdir -p $BASEDIR/WRF/NCL/LIB && \
    cp $BASEDIR/INSTALL/LIB/NCL/ncl_jack_fortran.so \
       $BASEDIR/INSTALL/LIB/NCL/wrf_user_fortran_util_0-64bit.so \
       $BASEDIR/WRF/NCL/LIB/

# select_ncl_lib: create the symlinks that windgrams.ncl and rasp.ncl expect
RUN ln -sf LIB/ncl_jack_fortran.so              $BASEDIR/WRF/NCL/ncl_jack_fortran.so && \
    ln -sf LIB/wrf_user_fortran_util_0-64bit.so $BASEDIR/WRF/NCL/wrf_user_fortran_util_0.so

# -----------------------------------------------------------------------------
# 32-bit runtime and PGI libs (for wrfsi pre-compiled binaries)
# -----------------------------------------------------------------------------
RUN mkdir -p $BASEDIR/UTIL/LIB && \
    cp $BASEDIR/UTIL/PGI/libpgc.so \
       $BASEDIR/UTIL/PGI/libguide.so \
       $BASEDIR/INSTALL/LIB/i386/libpng12.so.0 \
       $BASEDIR/UTIL/LIB/

# Register custom lib directories with the dynamic linker
RUN echo "$BASEDIR/UTIL/LIB"     >  /etc/ld.so.conf.d/wxtofly.conf && \
    echo "$BASEDIR/WRF/NCL/LIB"  >> /etc/ld.so.conf.d/wxtofly.conf && \
    ldconfig

# -----------------------------------------------------------------------------
# Symlinks — UTIL
# -----------------------------------------------------------------------------
RUN ln -sf $BASEDIR/UTIL/NCARG/bin/ctrans  $BASEDIR/UTIL/ctrans  && \
    ln -sf $BASEDIR/UTIL/NCARG/bin/idt     $BASEDIR/UTIL/idt     && \
    ln -sf $BASEDIR/UTIL/NCARG/bin/ncl     $BASEDIR/UTIL/ncl     && \
    ln -sf $BASEDIR/UTIL/NCARG/bin/ncl     $BASEDIR/WRF/NCL/ncl  && \
    ln -sf "$(which zip)"     $BASEDIR/UTIL/zip     && \
    ln -sf "$(which gzip)"    $BASEDIR/UTIL/gzip    && \
    # curl wrapper: always follow redirects (-L) so http:// → https:// works
    printf '#!/bin/sh\nexec /usr/bin/curl -L "$@"\n' > $BASEDIR/UTIL/curl && chmod +x $BASEDIR/UTIL/curl && \
    ln -sf "$(which convert)" $BASEDIR/UTIL/convert

RUN ln -sf "$(dirname "$(which ncdump)")" /usr/local/netcdf

# -----------------------------------------------------------------------------
# Symlinks — RASP/RUN/UTIL
# -----------------------------------------------------------------------------
RUN mkdir -p $BASEDIR/RASP/RUN/UTIL && \
    ln -sf $BASEDIR/UTIL/convert $BASEDIR/RASP/RUN/UTIL/convert && \
    ln -sf $BASEDIR/UTIL/ctrans  $BASEDIR/RASP/RUN/UTIL/ctrans  && \
    ln -sf $BASEDIR/UTIL/curl    $BASEDIR/RASP/RUN/UTIL/curl    && \
    ln -sf $BASEDIR/UTIL/zip     $BASEDIR/RASP/RUN/UTIL/zip     && \
    ln -sf $BASEDIR/UTIL/gzip    $BASEDIR/RASP/RUN/UTIL/gzip

# -----------------------------------------------------------------------------
# Symlinks — WRF structural
# -----------------------------------------------------------------------------
RUN ln -sf $BASEDIR/WRF/wrfsi         $BASEDIR/WRF/WRFSI && \
    ln -sf $BASEDIR/WRF/wrfsi/domains $BASEDIR/WRF/wrfsi/DOMAINS

# siprd and log runtime working directories needed by wrfprep.pl for each domain
# (wrfprep.pl does opendir/chdir into siprd and writes logs to log/ but never creates them)
RUN find $BASEDIR/WRF/wrfsi/domains -mindepth 1 -maxdepth 1 -type d \
         -exec mkdir -p {}/siprd {}/log \;

# GRIB working directories, RASP output dir, and wrfsi symlinks
RUN mkdir -p $BASEDIR/RASP/RUN/AVN/GRIB  \
             $BASEDIR/RASP/RUN/ETA/GRIB  \
             $BASEDIR/RASP/RUN/GFS/GRIB  \
             $BASEDIR/RASP/RUN/RUCH/GRIB \
             $BASEDIR/RASP/RUN/OUT       \
             $BASEDIR/RASP/HTML          && \
    ln -sf $BASEDIR/RASP/RUN/AVN/GRIB  $BASEDIR/WRF/wrfsi/GRIB/AVN  && \
    ln -sf $BASEDIR/RASP/RUN/ETA/GRIB  $BASEDIR/WRF/wrfsi/GRIB/ETA  && \
    ln -sf $BASEDIR/RASP/RUN/GFS/GRIB  $BASEDIR/WRF/wrfsi/GRIB/GFS  && \
    ln -sf $BASEDIR/RASP/RUN/RUCH/GRIB $BASEDIR/WRF/wrfsi/GRIB/RUCH

# -----------------------------------------------------------------------------
# rasp.env — environment bootstrap sourced by all RASP/WXTOFLY scripts
# -----------------------------------------------------------------------------
RUN { echo '#!/bin/bash';                                          \
      echo '';                                                     \
      echo "export BASEDIR=$BASEDIR";                             \
      echo '';                                                     \
      echo "export NETCDF=$BASEDIR/UTIL/NETCDF";                  \
      echo "export NCARG_ROOT=$BASEDIR/UTIL/NCARG";               \
      echo "export NCL_COMMAND=$BASEDIR/UTIL/NCARG/bin/ncl";      \
      echo 'export PATH=$PATH:'"$BASEDIR/UTIL";                   \
      echo '';                                                     \
      echo "export EXT_DATAROOT=$BASEDIR/WRF/wrfsi/extdata";      \
      echo "export SOURCE_ROOT=$BASEDIR/WRF/wrfsi";               \
      echo "export INSTALLROOT=$BASEDIR/WRF/wrfsi";               \
      echo "export GEOG_DATAROOT=$BASEDIR/WRF/wrfsi/extdata/GEOG";\
      echo "export DATAROOT=$BASEDIR/WRF/wrfsi/domains";          \
    } > $BASEDIR/rasp.env && \
    chmod +x $BASEDIR/rasp.env $BASEDIR/RASP/RUN/run.rasp

# -----------------------------------------------------------------------------
# Fix [BASEDIR] placeholder in config files
# -----------------------------------------------------------------------------
# install_wxtofly.sh calls fix_basedir.sh which replaces the [BASEDIR] token
# in wxtofly.env, wrfsi config files, etc. with the actual install path.
RUN find $BASEDIR/WXTOFLY -type f | xargs grep -rl '\[BASEDIR\]' 2>/dev/null | \
        xargs -r sed -i "s|\[BASEDIR\]|$BASEDIR|g" ; \
    find $BASEDIR/WRF/wrfsi -type f | xargs grep -rl '\[BASEDIR\]' 2>/dev/null | \
        xargs -r sed -i "s|\[BASEDIR\]|$BASEDIR|g"

# -----------------------------------------------------------------------------
# Permissions
# -----------------------------------------------------------------------------
RUN find $BASEDIR/WXTOFLY -type f -name "*.sh" -exec chmod +x {} \; && \
    find $BASEDIR           -type f -name "*.pl"  -exec chmod +x {} \; && \
    find $BASEDIR           -type f -name "*.PL"  -exec chmod +x {} \; && \
    # Compiled executables: wrfsi binaries, WRF executables, UTIL binaries
    find $BASEDIR/WRF/wrfsi/bin  -type f              -exec chmod +x {} \; && \
    # WRF main executables (wrf.exe, real.exe, ndown.exe) live in WRFV2/main/;
    # the per-domain *.exe entries are symlinks — chmod the real files
    find $BASEDIR/WRF/WRFV2/main -type f              -exec chmod +x {} \; && \
    find $BASEDIR/WRF/WRFV2/RASP -type f -name "*.exe" -exec chmod +x {} \; && \
    find $BASEDIR/UTIL            -maxdepth 1 -type f  -exec chmod +x {} \; && \
    # RASP/RUN scripts and UTIL (many have no file extension)
    chmod +x $BASEDIR/RASP/RUN/run.rasp \
             $BASEDIR/RASP/RUN/run.rasp2 \
             $BASEDIR/RASP/RUN/LOCAL/results_output.hook && \
    find $BASEDIR/RASP/RUN/UTIL -type f -exec chmod +x {} \;

# -----------------------------------------------------------------------------
# Runtime environment
# -----------------------------------------------------------------------------
# PERL5LIB includes RASP/RUN so that rasp.pl/rasp2.pl can require
# rasp.run.parameters.<REGION> from the run directory (Perl 5.26+ removed
# '.' from @INC by default).
ENV PERL5LIB=/opt/rasp/RASP/RUN
ENV NCARG_ROOT=$BASEDIR/UTIL/NCARG
ENV PATH=$BASEDIR/UTIL:$PATH

WORKDIR $BASEDIR
CMD ["/bin/bash"]
