

found=0
if [  x$PBS_NODEFILE != x ]; then
    GMPICONF=$MOAD_DATAROOT/siprd/gmpiconf.$$
    export GMPICONF
    $INSTALLROOT/etc/setup_mpiconf.pl -f $GMPICONF $PBS_NODEFILE
    found=1
fi    

if [ x$PE_HOSTFILE != x ]; then
# The TMPDIR variable comes from SGE
    SGE_HOSTFILE=$TMPDIR/machines
    GMPICONF=$MOAD_DATAROOT/siprd/gmpiconf.$$
    export GMPICONF
    $INSTALLROOT/etc/setup_mpiconf.pl -f $GMPICONF $SGE_HOSTFILE
    found=1
fi    

if [ $found = 0 ]; then
    echo "This script must be run inside a batch job. Did you forget to qsub?"
fi
