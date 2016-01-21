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
  #  integer, float, string o boolean
  declare -p "$1" 2> /dev/null | grep -qE '^declare \-[^aA]* '
}

is_array?() {
  declare -p "$1" 2> /dev/null | grep -qE '^declare \-[^ ]*a[^ ]*'
}

is_hash?() {
  declare -p "$1" 2> /dev/null | grep -qE '^declare \-[^ ]*A[^ ]*'
}

setx='execcomand'
#==============================
# Executes a commad for 100 files at a time, and securely avoid the
# too long argument list restriction.
# -c string    : command
# -a string    : arguments, programs, ...
# -- <strings> : files to use. Wilcards allowed.
#==============================
execcomand() {
  local kommand arguments
  local -a files
  local -i OPTIND=1

  while getopts c:a: opt ; do
    case "$opt" in
    c)   kommand="$OPTARG" ;;
    a) arguments="$OPTARG" ;;
    esac
  done
  shift $(($OPTIND - 1))
  if [ "$1" = '--' ]; then
    shift
  fi

  files=( "${@}" )
  for ((i=0; i<${#files[*]}; i+=100)); do
    ${command} ${arguments} "${files[@]:i:100}"
  done
}

setx='trim'
#==============================
# This function returns a string with whitespace stripped from the beginning 
# and end of ${str}. Without the -c parameter, trim() will strip these 
# characters: ' \t\n[:space:]'
# -s <string>  : string to process
# -c <string>  : alternative chars to trim
#==============================
trim() {
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
}

