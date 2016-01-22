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
# is_valid_string?
# is_integer?
# is_function?
# is_alias?
# is_scalar?
# is_array?
# is_hash?

# VERBS:
# ======
# strip (alias: trim)
# index (alias: strpos)

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

is_valid_string?() {
  [[ $@ =~ ^[A-Za-z0-9]*$ ]]
}

is_integer?() {
  [ $@ -eq $@ ] > /dev/null
}

is_function?() {
  local s=$1
  [[ $(type -t $s) == 'function' ]]
}

is_alias?() {
  local s=$1
  [[ $(type -t $s) == 'alias' ]]
}

is_scalar?() {
  declare -p "$1" 2> /dev/null | grep -qE '^declare \-[^aA]* '
}

is_array?() {
  declare -p "$1" 2> /dev/null | grep -qE '^declare \-[^ ]*a[^ ]*'
}

is_hash?() {
  declare -p "$1" 2> /dev/null | grep -qE '^declare \-[^ ]*A[^ ]*'
}

#==============================================================================
# VERBS:
#==============================================================================

setx='strip'
#==============================
# This method returns a string with whitespace stripped from the beginning 
# and end of ${str}. Without the -c parameter, strip() will strip these 
# characters: ' \t\n[:space:]'
# -s <string>  : string to process
# -c <string>  : alternative chars to strip
#==============================
strip() {
  local str chars="${IFS}[:space:]"
  local -i OPTIND=1

  while getopts :s:c: opt ; do
    case "$opt" in
      s)   str="$OPTARG" ;;
      c) chars="$OPTARG" ;;
    esac
  done
  shift $(($OPTIND - 1))

  if [[ "${str}" =~ ^[[:space:]]*([^[:space:]].*[^[:space:]])[[:space:]]*$ ]]
  then 
    printf '%s' "${BASH_REMATCH[1]}"
  else
    printf '%s' "${str}"
  fi
} # strip
alias trim='strip'

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
# MISCELANEA:
#==============================================================================

# > I've found name pipes (fifos) but I am confused on using them
# > properly. What I want to do is to take the stdout of a process and
# > send it to another process to be filtered. I also want to take the
# > stderr of the first process and send it to another process to
# > also be filtered. Any examples?
# [...]
# No need for named pipes here.
# >> {
# >>   {
# >>     cm1 3>&- |
# >>       cmd2 2>&3 3>&-
# >>   } 2>&1 >&4 4>&- |
# >>     cmd3 3>&- 4>&-
# >> } 3>&2 4>&1
# >
# > Thanks.
# >
# > OK now I see why I didn't get it to work. I didn't try that far.
# > But I have to say I'm not quite sure what I'm reading just yet.
# > I'll have to hit the man pages as I'm not used to the >&-
# > syntax.
# 3>&- is for closing fd 3. It's not necessary, but it's for tidy
# up. None of the commands will ever try (not should they) to
# access the fd 3 and 4, so it's best to close them before
# executing those commands so that they can use those fds for
# something else.

# {
#   {
#     cm1 |
#       cmd2 2>&3
#   } 2>&1 >&4 |
#     cmd3
# } 3>&2 4>&1

# is functionnaly equivalent.

# if cmd2 doesn't output anything on its stdout nor stderr, it can
# even be simplified to:
# { cm1 | cmd2; } 2>&1 | cmd3

# Or if you want to be sure:

# { cm1 | cmd2 > /dev/null 2>&1; } 2>&1 | cmd3

# -- 
# Stéphane

