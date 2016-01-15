#!/bin/bash
#%
#% ${PROGNAME} - read and parse yaml files
#%
#% usage: ${PROGNAME}.sh <-c|-p|-f> -f <files>
#%
#% where:
#%
#%  -h|--help       :  show this help
#%  -v|--verbose    :  verbose mode
#%  -d|--debug      :  debug mode, set -x
#%  -c|--check      :  check the file is yaml
#%  -p|--parse      :  parse the content and store it in memory
#%  -f|--file       :  file or files. Unix wilcards allowed. Must be last option
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
# . $SCRIPTDIR/parser/functions.sh

setx=usage
function usage ()
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
# function _exit ()
# {
#   rm -fr ${tmpDir}
#   exit $1
# } # _exit



setx=main
function main ()
{
  # local ...=...
  usage $ARGS
  # readCmdLineParameters $ARGS
} # main

#==============================
# MAIN SHELL BODY
#==============================
main
# _exit
