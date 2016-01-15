#!/bin/bash
#%
#% ${PROGNAME} - Descripción corta de qué hace el script
#%
#% usage: ${PROGNAME}.sh <-c|-d|-s> [-u <user> -p <password>]
#%
#% where:
#%
#%  -c|--connect    :  blabla blabla blabla
#%  -d|--disconnect :  blabla blabla blabla
#%  -s|--status     :  blabla blabla blabla
#%
#% history:
#% 2016-01-15       :  created by Rubén Ibáñez Carmona
#%

# CONSTANTS::
readonly PROGNAME=$(sed 's/\.sh$//' <<<"${0##*/}")
readonly SCRIPTNAME=$(basename $0)
readonly SCRIPTDIR=$(readlink -m $(dirname $0))
readonly TMPDIR=/tmp/${PROGNAME}.$$
readonly ARGS="$@"

# load parser constants:
. $SCRIPTDIR/parser/constants.sh

# load parser functions:
. $SCRIPTDIR/parser/functions.sh

setx=usage
#==============================
function usage ()
#==============================
{
  if [ $# -lt 1 ]; then
    sed -n '
      /^#%/ {
        s/${PROGNAME}/'${PROGNAME}'/g
        s/^#%//p
      }' $0
    exit 1
  fi
} # usage

# setx=_exit
#==============================
# function _exit ()
#==============================
# {
#   rm -fr ${tmpDir}
#   exit $1
# } # _exit



# setx=main
#==============================
# function main ()
#==============================
# {
#   local ...=...
# } # main

#==============================
# MAIN SHELL BODY
#==============================
usage $ARGS
# readCmdLineParameters $ARGS
# main
# _exit
