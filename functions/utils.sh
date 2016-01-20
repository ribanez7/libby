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




# string trim ( string $str [, string $character_mask = " \t\n\r\0\x0B" ] )


trim() {
  local str character_mask="${IFS}[:space:]"
  local -i OPTIND=1

  while getopts :s:c: opt ; do
    case "$opt" in
      s)            str="$OPTARG" ;;
      c) character_mask="$OPTARG" ;;
    esac
  done
  shift $(($OPTIND - 1))

  if [[ "$str" =~ ^[[:space:]]*([^[:space:]].*[^[:space:]])[[:space:]]*$ ]]
  then 
      printf '%s' "${BASH_REMATCH[1]}"
  fi
}


# BASH_REMATCH
#     An  array  variable whose members are assigned by the =~ binary operator to the [[ conditional command.  The element with index 0 is the portion of the
#     string matching the entire regular expression.  The element with index n is the portion of the string matching  the  nth  parenthesized  subexpression.
#     This variable is read-only.

#     An  additional  binary  operator, =~, is available, with the same precedence as == and !=.  When it is used, the string to the right of the operator is
#     considered an extended regular expression and matched accordingly (as in regex(3)).  The return value is 0 if the string matches  the  pattern,  and  1
#     otherwise.   If  the regular expression is syntactically incorrect, the conditional expression's return value is 2.  If the shell option nocasematch is
#     enabled, the match is performed without regard to the case of alphabetic characters.  Any part of the pattern may be quoted to force the quoted portion
#     to  be  matched as a string.  Bracket expressions in regular expressions must be treated carefully, since normal quoting characters lose their meanings
#     between brackets.  If the pattern is stored in a shell variable, quoting the variable expansion forces the entire pattern to be matched  as  a  string.
#     Substrings  matched  by  parenthesized  subexpressions  within  the  regular  expression  are saved in the array variable BASH_REMATCH.  The element of
#     BASH_REMATCH with index 0 is the portion of the string matching the entire regular expression.  The element of BASH_REMATCH with index n is the portion
#     of the string matching the nth parenthesized subexpression.