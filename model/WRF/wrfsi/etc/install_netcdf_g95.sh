#------------------------------------
# How to acquire AND install g95:

# 1) Unpack the downloaded tarball (e.g. g95-x86-linux.tgz) in a directory
# of your choice:

   wget -O - http://g95.sourceforge.net/g95-x86-linux.tgz | tar xvfz -

# Or, goto http://g95.sourceforge.net
#  download the linux binary g95-x86-linux.tgz
#  tar -zxvf g95-x86-linux.tgz

# 2) For your convenience, you can create another symbolic link from a
# directory in your $PATH (e.g. ~/bin) to the executable

   ln -s $PWD/g95-install/bin/*g95* ~/bin/g95


#------------------------------------

# This is how to compile the Netcdf library, in c-shell:
# Acquire netcdf from unidata
   wget -O - ftp://ftp.unidata.ucar.edu/pub/netcdf/netcdf.tar.gz | tar xvfz -

# Make name generic
   mv netcd* netcdf

# Set env vars
   setenv FC g95
   setenv F90 g95
   setenv CFLAGS "-Df2cFortran"

# Build and install netCDF
   cd netcdf/src/
   ./configure
   make
   make test
   make install
   
# Set env var NETCDF
   cd ..
   pwd
   setenv NETCDF $PWD
