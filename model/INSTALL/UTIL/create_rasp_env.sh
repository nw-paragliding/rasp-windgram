#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

RASPENV=$BASEDIR/rasp.env

if [ -f "$RASPENV" ]
  then
    rm "$RASPENV"
fi

echo "Creating $RASPENV file"
echo "#!/bin/bash" >> $RASPENV
echo "" >> $RASPENV
echo "export BASEDIR=$BASEDIR" >> $RASPENV
echo "" >> $RASPENV
echo "export NETCDF=$BASEDIR/UTIL/NETCDF" >> $RASPENV
echo "export NCARG_ROOT=$BASEDIR/UTIL/NCARG" >> $RASPENV
echo "export NCL_COMMAND=$NCARG_ROOT/bin/ncl" >> $RASPENV
echo "export PATH="'$PATH'":$BASEDIR/UTIL" >> $RASPENV
echo "" >> $RASPENV
echo "export EXT_DATAROOT=$BASEDIR/WRF/wrfsi/extdata" >> $RASPENV
echo "export SOURCE_ROOT=$BASEDIR/WRF/wrfsi" >> $RASPENV
echo "export INSTALLROOT=$BASEDIR/WRF/wrfsi" >> $RASPENV
echo "export GEOG_DATAROOT=$BASEDIR/WRF/wrfsi/extdata/GEOG" >> $RASPENV
echo "export DATAROOT=$BASEDIR/WRF/wrfsi/domains" >> $RASPENV
echo "" >> $RASPENV
echo 'if [ $(basename $0) == "rasp.env" ]; then' >> $RASPENV
echo '	ORIG_DIR=$(pwd)' >> $RASPENV
echo '	cd $BASEDIR/RASP/RUN' >> $RASPENV
echo '	bash $@' >> $RASPENV
echo '	cd "$ORIG_DIR"' >> $RASPENV
echo 'fi' >> $RASPENV
chmod +x $RASPENV

chmod +x $BASEDIR/RASP/RUN/run.rasp