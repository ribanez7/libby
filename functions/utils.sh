function is_valid_string? ()
{
  [[ $@ =~ ^[A-Za-z0-9]*$ ]]
}

function is_integer? ()
{
  #[[ $@ =~ ^-?[0-9]+$ ]]
  [ $@ -eq $@ ] > /dev/null
}

function is_function? ()
{
  type -t $1
}

function is_alias? ()
{
  type -t $1
}

setx=execcomand
#==============================
# Executes a commad for 100 files at a time, and securely avoid the
# too long argument list restriction.
# -c string    : command
# -a string    : arguments, programs, ...
# -- <strings> : files to use. Wilcards allowed.
#==============================
function execcomand ()
#==============================
{
  local kommand arguments
  local -a files
  local -i OPTIND=1

  while getopts c:a: opt ; do
    case "$opt" in
    c)  kommand="$OPTARG"  ;;
    a)  arguments="$OPTARG";;
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
