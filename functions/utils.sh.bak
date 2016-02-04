#==============================================================================
# INDEX OF AVAILABLE METHODS:

# NOTIFICATIONS:
# ==============
# pass
# warn
# warn_wait
# ask
# verbose
# fail
# highlight
# dothis
# error

# BOOLEANS:
# =========
# is_valid_string
# is_integer
# is_function
# is_alias
# is_scalar
# is_array
# is_hash

# STRINGS:
# ========
# print_if_non_blank
# strip (alias: trim)
# lstrip (alias: ltrim)
# rstrip (alias: rtrim)
# index (alias: strpos)

# ARRAYS:
# =======
# pop

# MISCELANEA:
# ===========
# Tricky redirection

#==============================================================================
# NOTIFICATIONS:
#==============================================================================

RED="\e[0;31m"
GREEN="\e[0;32m"
YELLOW="\e[0;33m"
BLUE="\e[0;34m"
BACK="\e[0m"

pass() {
  [[ -n $NO_PASS ]] || echo -e "${GREEN}PASS${BACK}: $*"
}
warn() {
  local OPT
  if [[ $1 == -* ]] ; then
    OPT=$1; shift
  fi
  if [[ -n $OPT || -z $NO_WARN ]] ; then
    echo $OPT -e "${YELLOW}WARN${BACK}: $*"
  fi
}
warn_wait() {
  warn -n "$*\n    Continue? [Yn] " >&2
  read ANS
  case $ANS in
    Y*|y*|1*) return 0 ;;
    *) [[ -z $ANS ]] || return 1 ;;
  esac
  return 0
}
ask() {
  echo -ne "${YELLOW}WARN${BACK}: $* "
}
verbose() {
  [[ -z "$VERBOSE" ]] || echo -e "INFO: $*"
}
fail() {
  echo -e "${RED}FAIL${BACK}: $*"
}
highlight() {
  echo -e "${YELLOW}$*${BACK}"
}
dothis() {
  echo -e "${BLUE}$*${BACK}"
}

# The minimum version of bash required to run this library is bash v4
if bash --version | egrep -q 'GNU bash, version [1-3]' ; then
  fail "This library requires at least version 4 of bash"
  fail "You are running: $(bash --version | head -1)"
  exit 1
fi
export MYPID=$$
error() {
  echo E: $* >&2
  set -e
  kill -TERM $MYPID 2>/dev/null
}

#==============================================================================
# BOOLEANS:
#==============================================================================

is_valid_string() {
  [[ "${@:?}" =~ ^[A-Za-z0-9_[:space:]]*$ ]]
}

is_integer() {
  [ ${@:?} -eq ${@:?} ] > /dev/null 2>&1
}

is_function() {
  local s=${1:?}
  [[ $(type -t $s) == 'function' ]]
}

is_alias() {
  local s=${1:?}
  [[ $(type -t $s) == 'alias' ]]
}

is_scalar() {
  declare -p "${1:?}" 2> /dev/null | grep -qE '^declare \-[^aA]* '
}

is_array() {
  declare -p "${1:?}" 2> /dev/null | grep -qE '^declare \-[^ ]*a[^ ]*'
}

is_hash() {
  declare -p "${1:?}" 2> /dev/null | grep -qE '^declare \-[^ ]*A[^ ]*'
}

#==============================================================================
# VERBS:
#==============================================================================

setx='printf_if_non_blank'
#==============================
# This method returns 1 if the value passed is empty
# or contains just spaces.
#==============================
printf_if_non_blank() {
  local s="$@"
  [[ "${s}" =~ ^[[:space:]]*$ ]] || printf '%s' "${s}"
} # printf_in_non_blank

setx='strip'
#==============================
# This method returns a string with whitespace stripped from the beginning 
# and end of ${str}. Without the -c parameter, strip() will strip these 
# characters: ' \t\n[:space:]'
# -s <string>  : string to process
# -c <string>  : alternative chars to strip
#==============================
strip() {
  local str chars="[:space:]"
  local -i OPTIND=1

  while getopts :s:c: opt ; do
    case "$opt" in
      s)   str="$OPTARG" ;;
      c) chars="$OPTARG" ;;
    esac
  done
  shift $(($OPTIND - 1))

  if [[ "${str}" =~ ^[${chars}]*([^${chars}].*[^${chars}])[${chars}]*$ ]]
  then 
    printf_if_non_blank "${BASH_REMATCH[1]}"
  else
    printf_if_non_blank "${str}"
  fi
} # strip
alias trim='strip'

setx='lstrip'
#==============================
# strip just from the left
# -s <string>  : string to process
# -c <string>  : alternative chars to strip
#==============================
lstrip() {
  local str chars="[:space:]"
  local -i OPTIND=1

  while getopts :s:c: opt ; do
    case "$opt" in
      s)   str="$OPTARG" ;;
      c) chars="$OPTARG" ;;
    esac
  done
  shift $(($OPTIND - 1))

  if [[ "${str}" =~ ^[${chars}]*([^${chars}].*[^${chars}][${chars}]*$) ]]
  then
    printf_if_non_blank "${BASH_REMATCH[1]}"
  else
    printf_if_non_blank "${str}"
  fi
} # strip
alias ltrim='lstrip'

setx='rstrip'
#==============================
# strip just from the right
# -s <string>  : string to process
# -c <string>  : alternative chars to strip
#==============================
rstrip() {
  local str chars="[:space:]"
  local -i OPTIND=1

  while getopts :s:c: opt ; do
    case "$opt" in
      s)   str="$OPTARG" ;;
      c) chars="$OPTARG" ;;
    esac
  done
  shift $(($OPTIND - 1))

  if [[ "${str}" =~ (^[${chars}]*[^${chars}].*[^${chars}])[${chars}]*$ ]]
  then 
    printf_if_non_blank "${BASH_REMATCH[1]}"
  else
    printf_if_non_blank "${str}"
  fi
} # strip
alias rtrim='rstrip'

setx='index'
#==============================
# -s <string> : input string
# -c <string> : character to find
# -o <int>    : the offset, if needed
#==============================
index() {
  local str char string
  local -i OPTIND=1 offset=0

  while getopts :s:c: opt ; do
    case "$opt" in
      s) string="$OPTARG"; str="${string}" ;;
      c) char="$OPTARG" ;;
      o) is_integer? "$OPTARG" && offset="$OPTARG" || : ;;
    esac
  done
  shift $(($OPTIND - 1))

  if [ ${offset} -gt 0 ]; then
    str="${str:${offset}}"
  else
    offset=0
  fi

  str=${str/${char}*/}

  if [ "${#str}" -eq "${#string}" ]; then
    return 1
  fi

  printf '%d' $((${#str}+${offset}))
} # index
alias strpos='index'

#==============================================================================
# ARRAYS:
#==============================================================================
setx='pop'
#==============================
# Removes last element in an array and fills the var with that value.
# -a <array>   : input array
# -v <varname> : var to fill with popped value (default 'var')
# returns false if array is empty
#==============================
pop() {
  local array arrayname varname='var'
  local -i OPTIND=1 n

  while getopts :a:v: opt ; do
    case "$opt" in
      a) arrayname="${OPTARG:?ArgumentError}" ;;
      v) varname="${OPTARG:-var}" ;;
    esac
  done
  shift $(($OPTIND - 1))

  # Copy the array, $arrayname, to local array
  eval "array=( \"\${$arrayname[@]}\" )"
  n=${#array[@]}
  (( n )) || return 1

  # Store last element in $varname
  printf -v "$varname" "${array[n-1]}"
  unset array[n-1]

  # Copy array back to $arrayname
  eval "$arrayname=( \"\${array[@]}\" )"
} # pop


#==============================================================================
# MISCELANEA:
#==============================================================================

# {
#   {
#     cm1 3>&- | cmd2 2>&3 3>&-
#   } 2>&1 >&4 4>&- | cmd3 3>&- 4>&-
# } 3>&2 4>&1
