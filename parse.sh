#!/bin/bash
#%
#% ${PROGNAME} - Wrapper to read and parse yaml files
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
#%  -f|--file       :  file or files. Wilcards allowed. Must be last option
#%
#% history:
#% 2016-01-15       :  created by Rubén Ibáñez Carmona
#%


# leyenda:
# The placeholder OJO will show you the possible issues.
# We'll have problems with the variable scope. It will be necessary to
# dynamically scope them. Now, the 95% of them are local.
# see: http://mywiki.wooledge.org/BashFAQ/084
# Revisar los workaround del clásico explode.
# 
# La clave de todo va a estar en los siguientes métodos en utils:
# [ x ] array_send
# [ x ]   indexed_send
# [ x ]   associative_send
# [ x ] array_receive
# [ x ]   indexed_receive
# [ x ]   associative_receive
#
#
# Hecho. Ejemplo de uso:

# saluda() { 
#   local a2r="$(array_receive nueva "$1")"
#   eval $a2r
#   for i in "${!nueva[@]}"; do
#     echo key=$i , value="${nueva[$i]}"
#   done
# }
# hola() { 
#   local -A translations=([apple]="manzana" [lemon]="limon" [banana]="platano" )
#   a2send="$(array_send translations)"
#   saluda "${a2send}"
# }


# BASH SETTINGS:
# ==============
set -eu -o pipefail
trap "echo ':: Exitting...'" INT TERM EXIT

# CONSTANTS:
# ==========
readonly PROGNAME=$(sed 's/\.sh$//' <<<"${0##*/}") \
         SCRIPTNAME=$(basename $0) \
         SCRIPTDIR=$(readlink -m $(dirname $0)) \
         TMPDIR=/tmp/${PROGNAME}.$$ \
         REMPTY=$'\0\0\0\0\0' \
         ARGS="$@"

# GLOBALS:
# ========
## Set to 1 to turn on:
typeset -i setting_dump_force_quotes=0 \
           setting_use_syck_is_possible=0 \
           _containsGroupAnchor=0 \
           _containsGroupAlias=0

## Typed:
typeset -i _dumpIndent _dumpWordWrap INDENT=2 WORDWRAP=40
typeset -A SavedGroups delayedPath

## Untyped:
path=
result=
LiteralPlaceHolder='___YAML_Literal_Block___'
_nodeId=

# REQUIREMENTS:
# =============
. $SCRIPTDIR/functions/utils.sh
. $SCRIPTDIR/parser/{constants,methods}.sh

# METHOD DEFINITIONS:
# ===================
# public functions get generic names.
# private functions are prepended by two underscores (RedHat convention).

setx=load
#==============================
# Load valid YAML string to libby:
#==============================
load() {
  local input="$@"
  __loadString $input
} # load

setx=loadFile
#==============================
# Load a valid YAML file to libby:
#==============================
loadFile() {
  local file=$1
  __load $file
} # loadFile

setx=YAMLLoad
#==============================
# Load a valid YAML file to the best bash structure:
#==============================
YAMLLoad() {
  export LIBBY='LIBBY_'
  local file=$1
  __load $file
} # YAMLLoad

setx=YAMLLoad
#==============================
# Load a valid YAML string to the best bash structure.
# It should handle these sort of strings:
# "---\n0: hello world\n"
#==============================
YAMLLoadString() {
  export LIBBY='LIBBY_'
  local input=$1
  __loadString $input
} # YAMLLoadString

setx=YAMLDump
#==============================
# return strings
# Dump YAML from BASH file with var declarations statically.
# Don't pass the parameters you want to use with its default values.
# -f file : array BASH vars
# -i int  : $indent Pass in false to use the default, which is 2
# -w int  : int $wordwrap Pass in 0 for no wordwrap, false for default (40)
# -n      : int $no_opening_dashes Do not start YAML file with "---\n".
#==============================
YAMLDump() {
  local array
  local -i OPTIND=1 \
           indent=${INDENT} \
           wordwrap=${WORDWRAP} \
           no_opening_dashes=1 # use 0 to avoid this header.

  while getopts :f:i:w:n opt ; do
    case "$opt" in
      f) array="$OPTARG";;
      i) is_integer "$OPTARG" && indent="$OPTARG"   || : ;;
      w) is_integer "$OPTARG" && wordwrap="$OPTARG" || : ;;
      n) no_opening_dashes=0 ;;
    esac
  done
  shift $(($OPTIND - 1))
  
  export LIBBY='LIBBY_'
  if [ ${no_opening_dashes} -eq 1 ]; then
    dump -f "${array}" -i "${indent}" -w "${wordwrap}"
  else
    dump -f "${array}" -i "${indent}" -w "${wordwrap}" -n
  fi
} # YAMLDump

setx=dump
#==============================
# return strings: dumps clean YAML.
# Dump YAML from BASH file with var declarations statically.
# Don't pass the parameters you want to use with its default values.
# -f file : array BASH vars
# -i int  : $indent Pass in false to use the default, which is 2
# -w int  : int $wordwrap Pass in 0 for no wordwrap, false for default (40)
# -n      : int $no_opening_dashes Do not start YAML file with "---\n".
#==============================
dump() {
  local array string=
  local -i OPTIND=1 \
           indent=${INDENT}} \
           wordwrap=${WORDWRAP} \
           no_opening_dashes=1 # use 0 to avoid this header.

  while getopts :f:i:w:n opt ; do
    case "$opt" in
      f) array="$OPTARG";;
      i) is_integer "$OPTARG" && indent="$OPTARG"   || : ;;
      w) is_integer "$OPTARG" && wordwrap="$OPTARG" || : ;;
      n) no_opening_dashes=0 ;;
    esac
  done
  shift $(($OPTIND - 1))

  _dumpIndent=${indent}
  _dumpWordWrap=${wordwrap}
  [ ${no_opening_dashes} -eq 0 ] || string="---\n"

  # OJO: no me gusta el if -f.
  # New YAML document
  if [ -f ${array} ]; then
    array=( "${array}" ) # ¿quizás debería mapfile?
    local -i previous_key=-1
    local key value
    for key in "${!array[@]}"; do
      value="${array[${key}]}"
      is_declared first_key || first_key="${key}"
      string+="$(__yamelize -k "${key}"          \
                            -v "${value}"        \
                            -i 0                 \
                            -p "${previous_key}" \
                            -f "${first_key}"    \
                            -- "${array[@]}"     )"
      previous_key="${key}"
    done
  fi
  printf '%s\n' "${string}"
} # dump

setx='__yamelize'
#==============================
# Attempts to convert a key / value array item to YAML
# private
# return string
# -k $key          : The name of the key
# -v $value        : The value of the item
# -i $indent       : The indent of the current node
# -p $previous_key : by default -1
# -f $first_key    : by default 0
# -- $source_array : by default none.
#==============================
__yamelize() {
  local key value
  local -i OPTIND=1 \
           indent \
           previous_key=-1 \
           first_key=0

  while getopts :k:v:i:p:f:s: opt ; do
    case "$opt" in
      k) key="$OPTARG";;
      v) value="$OPTARG";;
      i) is_integer "$OPTARG" && indent="$OPTARG"       || : ;;
      p) is_integer "$OPTARG" && previous_key="$OPTARG" || : ;;
      f) is_integer "$OPTARG" && first_key="$OPTARG"    || : ;;
    esac
  done
  shift $(($OPTIND - 1))

  local -a source_array=( "$@" )
###############################################################################
# OJO!!
  if is_array "${value}"; then
    if [[ -z "${value}" ]]; then
        __dumpNode -k "${key}"          \
                   -v array()           \
                   -i ${indent}         \
                   -p "${previous_key}" \
                   -f "${first_key}"    \
                   -- "${source_array}"
# // It has children.  What to do?
# // Make it the right kind of item
# $string = $this->_dumpNode($key, self::REMPTY, $indent, $previous_key, $first_key, $source_array);
# // Add the indent
# $indent += $this->_dumpIndent;
# // Yamlize the array
# $string .= $this->_yamlizeArray($value,$indent);
  elif ! is_array "${value}"; then
# // It doesn't have children.  Yip.
# $string = $this->_dumpNode($key, $value, $indent, $previous_key, $first_key, $source_array);
  fi
  printf '%s' "${string}"
###############################################################################
} # __yamleize

setx='__yamelizeArray'
#==============================
# Attempts to convert an array to YAML
# @access private
# @return string
# @param $array The array you want to convert
# @param $indent The indent of the current level
#==============================
__yamelizeArray() {
    # OJO: FALTA EL WRAPPER.
#($array,$indent)
# if (is_array($array)) {
  if _IS_ARRAY_($ARRAY); then
    local string= key= value=
    local -i previous_key=-1

    for key in "${!array[@]}"; do
      value="${array[$key]}"
      [[ -n "${first_key}" ]] || first_key="${key}"
      string+="$(__yamelize -k "${key}" \
                            -v "${value}" \
                            -i ${indent} \
                            -p "${previous_key}" \
                            -f "${first_key}" \
                            -- "${array[@]}" )"
      previous_key="${key}"
    done

    printf '%s' "${string}"
  else 
    return 1
  fi
} # __yamleizeArray

setx='__dumpNode'
#==============================
# Returns YAML from a key and a value
# Prints out a string
# -k $key    : The name of the key
# -v $value  : The value of the item
# -i $indent : The indent of the current node
#==============================
__dumpNode() {
  local key value source_array='null' # OJO: cómo definir source_array?
  local -i indent previous_key=-1 first_key=0 OPTIND=1
  # local -a source_array=()
  local regex="(\n|: |- |\*|#|<|>|%|  |\[|]|\{|}|&|'|!)"

  while getopts :k:v:i:p:f:s: opt ; do
    case "$opt" in
      k) key="$OPTARG";;
      v) value="$OPTARG";;
      i) is_integer "$OPTARG" && indent="$OPTARG"       || : ;;
      p) is_integer "$OPTARG" && previous_key="$OPTARG" || : ;;
      f) is_integer "$OPTARG" && first_key="$OPTARG"    || : ;;
      s) source_array="$OPTARG";;
    esac
  done
  shift $(($OPTIND - 1))

  # OJO: función is_string, quizás debería ser un método y no utils
  if is_string "${value}" && \
    ( [[ "${value}" =~ ${regex} ]] || [[ "${value: -1:1}" == ':' ]] )
  then
    value="$(__doLiteralBlock -i "${indent}" -v "${value}")"
  else
    value="$(__doFolding -i "${indent}" -v "${value}")"
  fi

  # OJO: debería preguntar por ${!value} ?
  # OJO: debería ser un pseudo tipo, y no el verdadero tipo?
  # me refiero a @_ o [_] 
  # el if original pregunta si es un array.
  # if ($value === array()) $value = '[ ]';
  if ! is_scalar "${value}" && is_empty_array "${value}"; then
    value='[ ]'
  fi
  
  if [[ -z ${value} ]]; then
    value='""'
  fi

  if __isTranslationWord "${value}"; then
    value="$(__doLiteralBlock -i "${indent}" -v "${value}")"
  fi

  if [[ "$(strip -s "${value}")" != "${value}" ]]; then
    value="$(__doLiteralBlock -i "${indent}" -v "${value}")"
  fi

  # if (is_bool($value)) {
  #    $value = $value ? "true" : "false";
  # } OJO: crear método.
  if __is_bool "${value}"; then
    value=$( [[ ${value} ]] && printf true || printf false )
  fi
  
  if __is_null "${value}"; then value='null'; fi

  if [[ "${value}" == "'$REMPTY'" ]]; then
    value='null'
  fi
  
  spaces="$(printf '%*s' ${indent})"
  
  # OJO:
  if is_array "${source_array}" && \
    array_keys($source_array) === range(0, count($source_array) - 1))
  then
    # It's a sequence
    string="${spaces}- ${value}\n"
  else
    # It's mapped
    local rx=':|#'
    if ! [[ "${key}" =~ ${rx} ]]; then
      key="\"${key}\""
    fi
    string="$(rstrip -s "${spaces}${key}: ${value}\n")"
  fi
    
  printf '%s' "${string}"
} # __dumpNode

setx='__doLiteralBlock'
#==============================
# Creates a literal block for dumping
# Prints out a string
# -i $indent : The value of the indent
# -v $value  : The value
#==============================
__doLiteralBlock() {
  local indent="$1"; shift
  local value="$@"

  if [[ "${value}" == '\n' ]]; then
    printf '%s' '\n'
    return 0
  fi

  if ! [[ "${value}" =~ '\n' ]] && ! [[ "${value}" =~ "'" ]]; then
    printf "'%s'" "${value}"
    return 0
  fi

  if ! [[ "${value}" =~ '\n' ]] && ! [[ "${value}" =~ '"' ]]; then
    printf '"%s"' "${value}"
    return 0
  fi
  # OJO : ojo al explode.
  mapfile -t exploded <<<"$(printf '%b' "${value}")"
  newValue='|'

  if is_declared exploded[0]          && \
    ( [[ "${exploded[0]]}" == '|' ]]  || \
      [[ "${exploded[0]]}" == '|-' ]] || \
      [[ "${exploded[0]]}" == '>' ]] )
  then
    newValue="${exploded[0]]}"
    unset exploded[0]
  fi
  # OJO: check the unset and the for quotes.
  indent="${_dumpIndent}"
  spaces="$(printf '%*s' ${indent})"

  # OJO: los paréntesis del if
  for line in "${exploded[@]}"; do
    line="$(strip -s "${line}")"
    lenLine="${#line}"
    if ( [ $(index -s "${line}" -c '"') -eq 0 ] && \
      [ $(rindex -s "${line}" -c '"') -eq $(( lenLine - 1 )) ] ) || \
      ( [ $(index -s "${line}" -c "'") -eq 0 ]  && \
      [ $(rindex -s "${line}" -c "'") -eq $(( lenLine - 1 )) ] )
    then
      line="${line:1:-1}"
    fi

    # OJO : $newValue .= "\n" . $spaces . ($line);
    newValue+="\n${spaces}${line}"
  done

  printf '%s' "${newValue}"
} # __doLiteralBlock

setx='__doFolding'
#==============================
# Folds a string of text, if necessary
# Prints out a string
# $1 $indent
# $2..n $value : The string you wish to fold
#==============================
__doFolding() {
  local indent="$1"; shift
  local value="$@"

  # Don't do anything if wordwrap is set to 0
  if [ $(__dumpWordWrap) -ne 0 ] &&\
    ! is_integer "${value}"      &&\
    is_scalar "${value}"         &&\
    [ "${#value}" -gt $(__dumpWordWrap) ]
  then
    (( indent += _dumpIndent ))
    indent="$(printf '%*s' ${indent})"
    wrapped="$(word_wrap -w "$(__dumpWordWrap)"-b "\n${indent}" -- "${value}")"
    value=">\n${indent}${wrapped}"
  else
    if [ ${setting_dump_force_quotes} -eq 1 ] &&\
      ! is_integer "${value}"                 &&\
      is_scalar "${value}"                    &&\
      [[ "${value}" != "${REMPTY}" ]]
    then
      value="\"${value}\""
    fi
    local rx='[0-9ex\\ ]+'
    if [[ "${value}" =~ ${rx} ]] && is_scalar "${value}"; then
      value="\"${value}\""
    fi
  fi

  printf '%s' "${value}"
} # __doFolding

setx='isTrueWord'
#==============================
# Detect any word with true value as meaning
#==============================
__isTrueWord() {
  local value=$1 pattern
  local -a words=()

  words=( $(__getTranslations true on yes y) )

  # Check if value is in words
  pattern=$(printf '%s|' "${words[@]}")
  pattern="+(${pattern%|})"

  shopt -s extglob
    case ${value} in
      ${pattern}) rc=0 ;;
      *)          rc=1 ;;
    esac
  shopt -u extglob

  return $rc
} # __isTrueWord

setx='isFalseWord'
#==============================
# Detect any word with false value as meaning
#==============================
__isFalseWord() {
  local value=$1 pattern
  local -a words=()

  words=( $(__getTranslations false off no n) )

  # Check if value is in words
  pattern=$(printf '%s|' "${words[@]}")
  pattern="+(${pattern%|})"

  shopt -s extglob
    case ${value} in
      ${pattern}) rc=0 ;;
      *)          rc=1 ;;
    esac
  shopt -u extglob

  return $rc
} # __isFalseWord

setx='isNullWord'
#==============================
# Detect any word with null value as meaning
#==============================
__isNullWord() {
  local value=$1 pattern
  local -a words=()

  words=( $(__getTranslations null '~') )

  # Check if value is in words
  pattern=$(printf '%s|' "${words[@]}")
  pattern="+(${pattern%|})"

  shopt -s extglob
    case ${value} in
      ${pattern}) rc=0 ;;
      *)          rc=1 ;;
    esac
  shopt -u extglob

  return $rc
} # __isNullWord

setx='isTranslationWord'
#==============================
# Detect any word with translation value as meaning
#==============================
__isTranslationWord() {
  local value="$@"

  __isTrueWord ${value}  || \
  __isFalseWord ${value} || \
  __isNullWord ${value}
} # __isTranslationWord

setx='__coerceValue'
#==============================
# Coerce a string into a native type
# Reference: http://yaml.org/type/bool.html
# TODO: Use only words from the YAML spec.
# USAGE: variable=$(__coerceValue $variable)
# @param $value The value to coerce
#==============================
__coerceValue() {
  local value=$1

  if __isTrueWord "${value}"; then
    value=true
  elif __isFalseWord "${value}"; then
    value=false
  elif __isNullWord "${value}"; then
    value=null
  fi
  printf '%s' "${value}"
} # __coerceValue

setx='getTranslations'
#==============================
# Given a set of words, perform the appropriate translations on them to
# match the YAML 1.1 specification for type coercing.
# $@  : The words to translate
# return a list of words space separated
#==============================
__getTranslations() {
  local words="$@" i
  local -a result=()

  for i in ${words}; do
    result+=(
      ${i^}
      ${i^^}
      ${i,,}
    )
  done

  echo -n ${result[@]}
} # __getTranslations

# LOADING METHODS:
# ================

setx='__load'
#==============================
# Guess the source and execute __loadWithSource with it.
#==============================
__load() {
  local input="$@"
  local Source

  Source="$(__loadFromSource "${input}")"
  __loadWithSource "${Source}"

} # __load

setx='__loadString'
#==============================
# Guess the source from a string and execute __loadWithSource with it.
#==============================
__loadString() {
  local input=$1
  local Source

  Source="$(__loadFromString "${input}")"
  __loadWithSource "${Source}"

} # __loadString

setx='__loadWithSource'
#==============================
# Returns an array
#==============================
__loadWithSource() {
  local -a Source=( "$@" )

  [[ -n "${Source}" ]] || return 0 # return array();

  if [ ${setting_use_syck_is_possible} -ne 0 ] && is_function syck_load; then
    array=( $(syck_load "$(printq "${Source}")") )
    if ! is_scalar array; then
      printb "${array[@]}"
      return 0
    else
      return 1 # OJO
    fi
  fi
  # $array = syck_load (implode ("\n", $Source));
  # return is_array($array) ? $array : array();

  local line              \
        lstripLine        \
        tempPath          \
        path              \
        literalBlockStyle \
        literalBlock      \
        lstripPlusOne
# OJO : revisar el uso de estos arrays. Creo deberían ser globales.
  local -a path   \
           result

  local -i i                    \
           cnt="${#Source[@]}"  \
           indent               \
           lenLine              \
           lstripLenLine        \
           literal_block_indent

  for (( i = 0; i < cnt; i++ )); do
    line="${Source[i]}"
    lenLine="${#line}"

    lstripLine="$(lstrip -s "${line}")"
    lstripLenLine="${#lstripLine}"
    indent=$(( lenLine - lstripLenLine ))
    tempPath="$(__getParentPathByIndent -i "${indent}")"
    line="$(__stripIndent -i "${indent}" -l "${line}")"
    ! __isComment "${line}" || continue
    ! __isEmpty "${line}"   || continue
    path="${tempPath}"

    literalBlockStyle="$(__startsLiteralBlock "${line}")" # OJO : quizás aquí
                                                          # se necesita boolean
                                                          # aunque no lo creo.
    if [[ -z "${literalBlockStyle}" ]]; then
      line="$(rstrip -s "${line}" -c "${literalBlockStyle} \n")"
      literalBlock=''
      line+=" ${LiteralPlaceHolder}"
      lstripPlusOne="$(lstrip -s "${Source[i+1]}")"
      literal_block_indent=$(( ${#Source[i+1]} - ${#lstripPlusOne} ))
      while (( ++i < cnt )) && __literalBlockContinues ${indent} "${Source[i]}"
      do
        literalBlock="$(__addLiteralLine -b "${literalBlock}" \
                                         -l "${Source[i]}" \
                                         -s "${literalBlockStyle}" \
                                         -i "${literal_block_indent}")"
      done
      (( i-- ))
    fi

    # Strip out comments
    local rx="[[:space:]]*#([^\"']+)$"
    if [[ "${line}" =~ '#' ]]; then
      if [[ "${line}" =~ ${rx} ]]; then
        line="${line/${BASH_REMATCH[0]}}"
      fi
    fi

    while (( ++i < cnt )) && __greedilyNeedNextLine "${line}"; do
      line="$(rstrip -s "${line}") $(lstrip -s "${Source[i]}" -c ' \t')"
    done
    (( i-- ))

    # OJO : esto qué
    lineArray="$(__parseLine "${line}" )"

    if [[ -z "${literalBlockStyle}" ]]; then
      lineArray="$(__revertLiteralPlaceHolder -b "${literalBlock}" 
                                              -- "${lineArray[@]}")"
    fi
#       $this->addArray($lineArray, $this->indent);

    local ind delPa
    for ind in ${!delayedPath[@]}; do
      delPa="${delayedPath[${ind}]}"
      path[$ind]="${delPa}"
    done

    delayedPath=()
  done

  # return $this->result;
} # __loadWithSource

setx='__loadFromSource'
#==============================
# OJO
__loadFromSource() {
v  local input="$@"

  if [[ -n "${input}" ]]          && \
    ! index -s "${index}" -c '\n' && \
    [ -f "${input}" ]
  then
    input=$(<"${input}")
  else
    # return $this->loadFromString($input);
    __loadFromString "${input}"
  fi
} # __loadFromSource

setx='__loadFromString'
#==============================
# Explodes the string on the '\n', creates the array lines.
#==============================
__loadFromString() {
  local input="$1" k v
  local -a lines

  mapfile -t lines <<<"${input}"

  for k in "${!lines[@]}"; do
    v="${lines[$k]}"
    lines[$k]=$(rstrip -s "${v}" -c '\r')
  done

  printf '%s\n' "${lines[@]}"
} # __loadFromString

setx='__parseLine'
#==============================
# Parses YAML code and returns an array for a node
# @access private
# @return array
# @param string $line A line from the YAML file
#==============================
__parseLine() {
  local line="$@"
# OJO : quizás debería devolver un error?
  [[ -n $line ]] || return 0
#     if (!$line) return array();
  line=$(strip -s "${line}")
  [[ -n $line ]] || return 0

  local -a array=()

  local group=$(__nodeContainsGroup "${line}")

  if [[ -n "${group}"]]; then
    __addGroup -l "${line}" -g "${group}"
    line=$(__stripGroup -l "${line}" -g "${group}")
  fi

  if __startsMappedSequence "${line}"; then
    __returnMappedSequence "${line}"
  fi

  if __isArrayElement "${line}"; then
    __returnArrayElement "${line}"
  fi

  if __isPlainArray "${line}"; then
    __returnPlainArray "${line}"
  fi

  __returnKeyValuePair "${line}"
} # __parseLine

setx='__toType'
#==============================
# Finds the type of the passed value, returns the value as the new type.
# @access private
# @param string $value
# @return mixed
#==============================
__toType() {
  local value="$1"
  if [[ -z "${value}" ]]; then
    printf '%s' "${value}"
    return 0
  fi

  first_character="${value:0:1}"
  last_character="${value: -1:1}"

  is_quoted=1 # means false
  while : ; do
    [[ -n "${value}" ]] || break
    if [[ "${first_character}" != '"' ]] && [[ "${first_character}" != "'" ]]
    then
      break
    fi
    if [[ "${last_character}" != '"'  ]] && [[ "${last_character}" != "'"  ]]
    then
      break
    fi
    is_quoted=0 # means true
    break
  done

  if [ ${is_quoted} -eq 0 ]; then
    value="$(printf '%b' "${value}")" # substituía literal \n por el autentico.
                                      # quizás aquí no sea necesario. OJO :
                                      # haciendo esto ahora lo estamos quitando
    local strtr="${value:1:-1}"
    local -A patterns=( 
      ["\\\""]=\" 
      [\'\']=\' 
      [\\\']=\' 
    )
    for from in "${!patterns[@]}"; do
      to="${arr[${from}]}"
      strtr="${strtr//${from}/${to}}"
    done
    printf '%s' "${strtr}"
    return 0
  fi

  if [[ "${value}" =~ ' #' ]] && [ ${is_quoted} -ne 0 ]; then
    local rx="[[:space:]]+#(.+)$"
    [[ "${value}" =~ ${rx} ]] && value="${value/${BASH_REMATCH[0]}}" || :
  fi

  if [[ "${first_character}" == '[' ]] && [[ "${last_character}" == ']' ]]
  then
    # Take out strings sequences and mappings
    local innerValue="$(strip -s "${value:1:-1}")"
    if [[ -z "${innerValue}" ]]; then
      # OJO : return array();
      return 0
    fi

    # OJO : raro.
    local explode="$(__inlineEscape "${innerValue}")"
    # Propagate value array
    value=( $(echo) )
    local v
    for v in "${explode[@]}"; do
      # OJO : revisar en el php las asignaciones arr[] = something. son un +=()
      # OJO : RECURSION
      value+=( "$(__toType "${v}")" )
    done
    printf '%s\n' "${value[@]}"
    return 0
  fi

  if [[ "${value}" =~ ': ' ]] && [[ "${first_character}" != '{' ]]; then
    array=( "${value%%: *}" "${value#*: }" )
    key="$(strip -s "${array[0]}")"
    value="${array[1]}"
    # OJO : RECURSION
    value="$(__toType "${value}")"
    # OJO: return array($key => $value);
    printf '%s\n' "${key}" "${value}"
    return 0
  fi

  if [[ "${first_character}" == '{' ]] && [[ "${last_character}" == '}' ]]
  then
    innerValue="$(strip -s "${value:1:-1}")"
    if [[ -z "${innerValue}" ]]; then
      # Inline Mapping
      # Take out strings sequences and mappings
      explode=( "$(__inlineEscape "${innerValue}")" )
      # Propagate value array
      array=()
      for v in "${explode[@]}"; do
        SubArr=( "$(__toType "${v}")" )
        [[ -n ${!SubArr[@]} ]] || continue
        # y ahora viene experimento mío para probar de iterar con puntero sobre
        # un array:
        # enviamos todo el array al file descriptor 3 y, una vez allí, usaremos
        # read para obtener un valor moviendo el puntero linea a linea sin
        # peligro.
        # OJO : if (is_array ($SubArr)) {
        # if ! [ -t 3 ]; then
        #   exec 3< <(printf '%s\n' "${SubArr[@]}")
        # fi
        if ! is_scalar SubArr; then
          local keysubarr="${!SubArr[0]}" # OJO : realmente se necesita solo el
                                          # primer valor??
          array[${keysubarr}]="${SubArr[${keysubarr}]}"
          # $array[key($SubArr)] = $SubArr[key($SubArr)]
          continue
        fi
        # exec 3>&-
      done
      array+=( "${SubArr[@]}" )
    fi
    # return $array;
    printf '%s\n' "${array[@]}"
    return 0
  fi

  rx='null|NULL|Null|~'
  if [[ "${value}" =~ ${rx} ]]; then
    printf 'null' 
    return 0
  fi

  rx='^(-|)[1-9]+[0-9]*$'
  if [[ "${value}" =~ ${rx} ]]; then
    local -i intvalue=${value}
#       if ($intvalue != PHP_INT_MAX)
#         $value = $intvalue;
    printf '%d' "${value}"
    return 0
  fi

  rx='^0[xX][0-9a-fA-F]+$'
  if [[ "${value}" =~ ${rx} ]]; then
    local -i intvalue=${value,,}
    printf '%x' "${value}"
    return 0
  fi

# value="$(__coerceValue "${value}")"
#     if (is_numeric($value)) {
#       if ($value === '0') return 0;
#       if (rtrim ($value, 0) === $value)
#         $value = (float)$value;
#       return $value;
#     }

  printf '%s' "${value}"
  return 0
} # __toType

setx='__inlineEscape'
#==============================
# Used in inlines to check for more inlines or quoted strings
# Prints out an array
#==============================
__inlineEscape() {
  local inline="$@" #($inline)
  # There's gotta be a cleaner way to do this...
  # While pure sequences seem to be nesting just fine,
  # pure mappings and mappings with sequences inside can't go very
  # deep.  This needs to be fixed.

  local -a seqs maps saved_strings saved_empties

  # Check for empty strings
  # OJO : +=() Ó =() ?
  local regex="(\"\")|('')"
  if [[ "${inline}" =~ ${regex} ]]; then
    saved_empties+=( "${BASH_REMATCH[0]}" )
    inline="${inline//${BASH_REMATCH[0]}/YAMLEmpty}"
    # inline=preg_replace($regex,'YAMLEmpty',$inline);
  fi
  unset regex

  # Check for strings
  # local regex="(?:(\")|(?:\'))((?(1)[^\"]+|[^\']+))(?(1)\"|\')"
  # May be the ideal regexes for this would be: (')([^'].*)(')
  local regexSingle="(')([^']+)(')"
  local regexDouble='(")([^"]+)(")'
  if [[ "${inline}" =~ ${regexSingle} ]]; then
    saved_strings+=( "${BASH_REMATCH[0]}" )
    inline="${inline//${BASH_REMATCH[0]}/YAMLString}"
  elif [[ "${inline}" =~ ${regexDouble} ]]; then
    saved_strings+=( "${BASH_REMATCH[0]}" )
    inline="${inline//${BASH_REMATCH[0]//\"/\\\"}/YAMLString}"
  fi
  unset regexSingle regexDouble

  # OJO : si esto diera problemas, pasaremos al extended globbing y abandona
  # ríamos las regular expressions. extglob + case.
  local -i i=0

  while : ; do
    # Check for sequences:
    local regex='\[([^]\[\{}]+)\]' replacement
    while [[ "${inline}" =~ ${regex} ]]; do
      seqs+=( "${BASH_REMATCH[0]}" )
      replacement="YAMLSeq$(( ${#seqs[@]} - 1 ))s"
      inline="${inline/${BASH_REMATCH[0]/\\\]/\\\]}/${replacement}}"
    done
    unset regex replacement

    # Check for mappings
    local regex='\{([^]\[\{}]+)}' replacement
    while [[ "${inline}" =~ ${regex} ]]; do
      maps+=( "${BASH_REMATCH[0]}" )
      replacement="YAMLMap$(( ${#maps[@]} - 1 ))s"
      inline="${inline/${BASH_REMATCH[0]/\\\]/\\\]}/${replacement}}"
    done
    unset regex replacement

    (( i++ < 10 )) || break

    if [[ ! "${inline}" =~ '[' ]] || [[ ! "${inline}" =~ '{' ]] ; then
      break
    fi
  done

  local -a explode
  IFS=, read -r -a explode <<<"${inline[@]}"

  local el
  local -a els
    for el in "${explode[@]}"; do
      els+=( "$(strip -s "${el}")" )
    done
    explode=( "${els[@]}" )
  unset el els

  local -i stringi=0 i=0

  # OJO : es posible que en los seqv haya que hacer el trick de backslashes.
  # lo aplicamos ahora, por si las moscas.
  while : ; do
    # Re-add the sequences
    if [[ -n ${seqs[@]} ]]; then
      for key in "${!explode[@]}"; then
        value="${explode[$key]}"
        if [[ "${value}" =~ 'YAMLSeq' ]]; then
          for seqk in "${!seqs[@]}"; do
            seqv="${seqs[$seqk]}"
            replacement="YAMLSeq${seqk}s"
            explode[$key]="${value//${replacement}/${seqv/\\\]/\\\]}}"
            value="${explode[$key]}"
          done
        fi
      done
    fi

    # Re-add the mappings
    if [[ -n ${maps[@]} ]]; then
      for key in "${!explode[@]}"; then
        value="${explode[$key]}"
        if [[ "${value}" =~ 'YAMLMap' ]]; then
          for mapk in "${!maps[@]}"; do
            mapv="${maps[$mapk]}"
            replacement="YAMLMap${mapk}s"
            explode[$key]="${value//${replacement}/${mapv/\\\]/\\\]}}"
            value="${explode[$key]}"
          done
        fi
      done
    fi

    # Re-add the strings
    if [[ -n ${saved_strings[@]} ]]; then
      for key in "${!explode[@]}"; then
        value="${explode[$key]}"
        while [[ "${value}" =~ 'YAMLString' ]]; do
          replacement="${saved_strings[$stringi]}"
          explode[$key]="${value/YAMLString/${replacement}}"
          unset saved_strings[$stringi]
          (( ++stringi ))
          value="${explode[$key]}"
        done
      done
    fi

    # Re-add the empties
    if [[ -n ${saved_empties[@]} ]]; then
      for key in "${!explode[@]}"; then
        value="${explode[$key]}"
        while [[ "${value}" =~ 'YAMLEmpty' ]]; do
          explode[$key]="${value/YAMLEmpty}"
          value="${explode[$key]}"
        done
      done
    fi

    finished=0 # means true
    for key in "${!explode[@]}"; then
      value="${explode[$key]}"
      if [[ "${value}" =~ 'YAMLSeq' ]]; then
        finished=1
        break
      fi
      if [[ "${value}" =~ 'YAMLMap' ]]; then
        finished=1
        break
      fi
      if [[ "${value}" =~ 'YAMLString' ]]; then
        finished=1
        break
      fi
      if [[ "${value}" =~ 'YAMLEmpty' ]]; then
        finished=1
        break
      fi
    done

    [ ${finished} -ne 0 ] || break

    (( i++ ))
    [ $i -le 10 ] || break
  done

  printf '%s\n' "${explode[@]}"
} # __inlineEscape

setx='__literalBlockContinues'
#==============================
__literalBlockContinues() {
#($line, $lineIndent)
  local -i lineIndent=$1 ; shift
  local line="$@"
  local -i lenLine="${#line}"
  local stripped="$(lstrip -s "${line}")"
  local -i lenStrip=${#stripped}

  if ! strip -s "${line}"; then
    return 0
  elif [ $(( lenLine - lenStrip )) -gt ${lineIndent} ]; then
    return 0
  else
    return 1
  fi
} # __literalBlockContinues

setx='__referenceContentsByAlias'
#==============================
__referenceContentsByAlias() {
  #($alias)
  local alias=$1

  while : ; do
    # if (!isset($this->SavedGroups[$alias])) { 
    #   echo "Bad group name: $alias."; 
    #   break; 
    # }
    # $groupPath = $this->SavedGroups[$alias];
    # $value = $this->result;
    # foreach ($groupPath as $k) {
    #   $value = $value[$k];
    # }
    break
  done

  # return $value;
} # __referenceContentsByAlias

setx='__addArrayInline'
# OJO: los path= deberían ser un path+= ??
#==============================
__addArrayInline(){
#($array, $indent)
  local -i indent OPTIND=1

  while getopts :i: opt ; do
    case "$opt" in
      i) is_integer "$OPTARG" && incoming_indent="$OPTARG" || : ;;
    esac
  done
  shift $(($OPTIND - 1))

  # tenemos que determinar si es array simple o asociativo.
  # podríamos quizás [[ "$*" =~ [^]\[\()=\'\"] ]]
  local array="$(eval printf '%s' "$@")"

  local -A CommonGroupPath=( "${path[@]}" )
  [[ -n ${array[*]} ]] || return 1

  for k in "${!array[@]}"; do
    __="${array[$k]}"
    __addArray -i "${indent}" -- "'([${k}]=\"${__}\")'"
    path="${CommonGroupPath[@]}"
  done
  return 0
} # __addArrayInline

setx='__addArray'
#==============================
# 
# 
# -i <integer>      : the $incoming_indent
# -- $incoming_data : any data is welcome
#==============================
__addArray() {
#($incoming_data, $incoming_indent)
  # OJO : cómo pasar matrices asociativas?
  local -a incoming_data
  local -i incoming_indent OPTIND=1

  while getopts :i: opt ; do
    case "$opt" in
      i) is_integer "$OPTARG" && incoming_indent="$OPTARG" || : ;;
    esac
  done
  shift $(($OPTIND - 1))

  incoming_data=( "$@" )

  if [ "${#incoming_data}" -gt 1 ]; then
    __addArrayInline -i ${incoming_indent} -- "${incoming_data[@]}"
    # º #  # OJO CON LAS GUARRADAS DE LOS ARRAYS INDEXADOS Y ASOCIATIVOS.
    # º #  Incoming_Data="$(declare -p incoming_data)"
    # º #  Incoming_Data="${Incoming_Data#*=}"
    # º #  __addArrayInline -i ${incoming_indent} -- "${Incoming_Data}"
  fi

  read -r key _ <<<"${!incoming_data[@]}"
  if [[ -n ${incoming_data[$key]} ]]; then
    value="${incoming_data[$key]}"
  else
    value=null
  fi

  [[ "${key}" != '__!YAMLZero' ]] || key='0'

  if [ ${incoming_indent} -eq 0 ]    && \
    [[ -z ${_containsGroupAlias} ]]  && \
    [[ -z ${_containsGroupAnchor} ]] && \
  then
    if [[ -n ${key} ]] || [[ ${key} == "''" ]] || [ ${key} -eq 0 ]; then
      result[$key]="${value}"
    else
      result+=( "${value}" )
      local indices="${!result[@]}"
      key="${indices##* }"
    fi
    path[$incoming_indent]="${key}"
    return 0
  fi

  local -a history
  # Unfolding inner array tree.

  # OJO : CHUNGUERÍO
  history+=( "${@result[@]}" )
  # $history[] = $_arr = $this->result;
  # foreach ($this->path as $k) {
  #   $history[] = $_arr = $_arr[$k];
  # }

  if ($this->_containsGroupAlias); then
    value="$(__referenceContentsByAlias "${_containsGroupAlias}")"
    _containsGroupAlias=false
  fi

###############################################################################
  # Adding string or numeric key to the innermost level or $this->arr.
  if ! is_integer $key && [[ "${key}" == '<<' ]]; then
#       if (!is_array ($_arr)) { $_arr = array (); }

#       $_arr = array_merge ($_arr, $value);
  elif [[ -n ${key} ]] || [[ ${key} == "''" ]] || [ ${key} -eq 0 ]; then
#       if (!is_array ($_arr))
#         $_arr = array ($key=>$value);
#       else
#         $_arr[$key] = $value;
  else
#       if (!is_array ($_arr)) { $_arr = array ($value); $key = 0; }
#       else { $_arr[] = $value; end ($_arr); $key = key ($_arr); }
  fi

#     $reverse_path = array_reverse($this->path);
#     $reverse_history = array_reverse ($history);
#     $reverse_history[0] = $_arr;
#     $cnt = count($reverse_history) - 1;
#     for ($i = 0; $i < $cnt; $i++) {
#       $reverse_history[$i+1][$reverse_path[$i]] = $reverse_history[$i];
#     }
#     $this->result = $reverse_history[$cnt];

#     $this->path[$incoming_indent] = $key;
###############################################################################
#     if ($this->_containsGroupAnchor) {
#       $this->SavedGroups[$this->_containsGroupAnchor] = $this->path;
#       if (is_array ($value)) {
#         $k = key ($value);
#         if (!is_int ($k)) {
#           $this->SavedGroups[$this->_containsGroupAnchor][$incoming_indent + 2] = $k;
#         }
#       }
#       $this->_containsGroupAnchor = false;
#     }
} # __addArray

setx='__startsLiteralBlock'
#==============================
__startsLiteralBlock() {
  local line="$@" \
        strip_line= \
        lastChar= \
        html_pattern='<[^>]*>$'

  strip_line=$(strip -s "${line}")
  lastChar="${strip_line: -1}"

  if [[ ${lastChar} != '>' ]] && [[ ${lastChar} != '|' ]]; then
    return 1
  elif [[ ${lastChar} == '|' ]]; then
    printf '%s' ${lastChar}
    return 0
  elif [[ "${line}" =~ ${html_pattern} ]]; then
    return 1
  else
    printf '%s' ${lastChar}
  fi
} # __startsLiteralBlock

setx='__greedilyNeedNextLine'
#==============================
__greedilyNeedNextLine() {
#($line)
  local line=$(strip -s "$@")
  local regex='^[^:]+:[[:space:]]*\['

  [[ -n "${line}" ]]            || return 1
  [[ "${line: -1:1}" != ']' ]]  || return 1
  [[ "${line:0:1}" != '[' ]]    || return 0
  [[ ! "${line}" =~ ${regex} ]] || return 0
  return 1
} # __greedilyNeedNextLine

setx='__addLiteralLine'
#==============================
__addLiteralLine() {
#($literalBlock, $line, $literalBlockStyle, $indent = -1)
  local line literalBlock literalBlockStyle
  local -i indent=-1 OPTIND=1

  while getopts :b:l:s:i: opt ; do
    case "$opt" in
      b) literalBlock="$OPTARG"
      l) line="$OPTARG" ;;
      s) literalBlockStyle="$OPTARG" ;;
      i) is_integer "$OPTARG" && indent="$OPTARG" || : ;;
    esac
  done
  shift $(($OPTIND - 1))

  line="$(__stripIndent -i ${indent} -l "${line}")"
  if [[ "${literalBlockStyle}" != '|' ]]; then
    line="$(__stripIndent -l "${line}")"
  fi
  
  # OJO : printb?
  line="$(rstrip -s "${line}")\n"
  if [[ "${literalBlockStyle}" == '|' ]]; then
    printf '%s%s' "${literalBlock}" "${line}"
    return 0
  fi

  if [ "${#line}" -eq 0 ]; then
    local tmp="$(rstrip -s "${literalBlock}" -c ' ')"
    echo -n "${tmp}\n"
    return 0
  fi

  if [[ "${line}" == '\n' ]] && [[ "${literalBlockStyle}" == '>' ]]; then
    echo -n "$(rstrip -s "${literalBlock}" -c ' \t')" "\n"
  fi

  if [[ "${line}" != '\n' ]]; then
    line="$(strip -s "${line}" -c '\r\n') "
  fi

  printf '%s%s' "${literalBlock}" "${line}"
} # __addLiteralLine

setx='__revertLiteralPlaceHolder'
#==============================
__revertLiteralPlaceHolder() {
  local -i OPTIND=1
  local lineArray literalBlock

  while getopts :a:b: opt ; do
    case "$opt" in
      a)    lineArray="$OPTARG" ;;
      b) literalBlock="$OPTARG" ;;
    esac
  done
  shift $(($OPTIND - 1))
  
  local -a lineArray=( "${@}" )
  
  local -i lenLiteralPlaceholder="${#LiteralPlaceHolder}"

  for k in "${!lineArray[@]}"; do
    __="${lineArray[$k]}"
    if ! is_scalar "$__"; then
      lineArray[$k]="$(__revertLiteralPlaceholder -a "${__}" \
                                                  -b "${literalBlock}")"
    elif [[ "${__: -1 * ${#LiteralPlaceHolder}}" == "${LiteralPlaceHolder}" ]]
    then
      lineArray[$k]="$(rstrip -s "${literalBlock}")"
    fi
  done
  # return $lineArray;
} # __revertLiteralPlaceHolder

setx='__stripIndent'
#==============================
# -l <string> : input line
# -i <int>    : by default -1 (indent value)
# prints a string.
#==============================
__stripIndent() {
#($line, $indent = -1)
  local line lstripped
  local -i indent=-1 OPTIND=1 lenLine lenStrip

  while getopts :l:i: opt ; do
    case "$opt" in
      i) is_integer "$OPTARG" && indent="$OPTARG" || : ;;
      l) line="$OPTARG" ;;
    esac
  done
  shift $(($OPTIND - 1))

  if [ ${indent} -eq -1 ]; then
    lenLine="${#line}"
    lstripped=$(lstrip -s "${line}")
    lenStrip="${#lstripped}"
    indent=$(( lenLine - lenStrip ))
  fi

  printf '%s' "${line:${indent}}"
} # __stripIndent

setx='__getParentPathByIndent'
#==============================
# it prints out the parent path by the given indent.
# -i <integer> : indent
# -p <string>  : current path of the object.
#==============================
__getParentPathByIndent() {
  local path linePath
  local -i indent OPTIND=1

  while getopts :p:i: opt ; do
    case "$opt" in
      p) path="$OPTARG" ;;
      i) is_integer "$OPTARG" && indent="$OPTARG" || : ;;
    esac
  done
  shift $(($OPTIND - 1))

  # OJO (¿cómo tratar el this? -- ¿Y el return array?):
  [ ${indent} -ne 0 ] || return 1 # return array();

  linePath="${path}"
  #     $linePath = $this->path;
  
  while : ; do
#       end($linePath); $lastIndentInParentPath = key($linePath);
    
    [ ${indent} -gt ${lastIndentInParentPath} ] || pop -a 'linePath'
    [ ${indent} -le ${lastIndentInParentPath} ] || break
  done
  
  printf '%s' "$linePath"
} # __getParentPathByIndent

setx='__clearBiggerPathValues'
#==============================
__clearBiggerPathValues() {
    # OJO : ¿es necesario pasar el path aquí?
    # originalmente no se pasaba.
  local path linePath
  local -i indent OPTIND=1

  while getopts :p:i: opt ; do
    case "$opt" in
      p) path="$OPTARG" ;;
      i) is_integer "$OPTARG" && indent="$OPTARG" || : ;;
    esac
  done
  shift $(($OPTIND - 1))

  [ ${indent} -ne 0 ] || path=( ) # if ($indent == 0) $this->path = array();
  [[ -n ${path} ]]    || return 0

#     foreach ($this->path as $k => $_) {
#       if ($k > $indent) unset ($this->path[$k]);
#     }

  return 0
} # __clearBiggerPathValues

setx='__isComment'
#==============================
__isComment() {
  local line="$@"

  [[ -n "${line}" ]]                 || return 1
  [[ ${line:0:1} != '#' ]]           || return 0
  [[ $(strip -s "$line") != '---' ]] || return 0

  return 1
} # __isComment

setx='__isEmpty'
#==============================
__isEmpty() {
  local line="$@"
  strip -s "$line" >/dev/null 2>&1 || :
} # __isEmpty

setx='__isArrayElement'
#==============================
__isArrayElement() {
  local line="$@"
  if [[ -z "${line}" ]] || ! is_scalar "${line}"; then
    return 1
  elif [[ "${line:0:2}" != '- ' ]]; then
    return 1
  elif [ "${#line}" -gt 3 ]; then
    if [[ "${line:0:3}" == '---' ]]; then
      return 1
    fi
  else
    return 0
  fi
} # __isArrayElement

setx='__isHashElement'
#==============================
# retrurns the strpos via the index method
#==============================
__isHashElement() {
  local line="$@"
  index -s "${line}" -c ':'
} # __isHashElement

setx='__isLiteral'
#==============================
__isLiteral() {
  local line="$@"

  if __isArrayElement "${line}"; then
    return 1
  elif __isHashElement "${line}"; then
    return 1
  else
    return 0
  fi
} # __isLiteral

setx='__unquote'
#==============================
# for the moment, it exits if it's not a string.
# returns the value passed, but unquotted.
# OJO
#==============================
__unquote() {
  local value="$@"

  if ! [[ -n "${value}" ]]; then
  #   printf '%s' "${value}"
  #   return 0
    return 1
  elif is_integer "$value" || is_array "$value" || is_hash "$value"; then
  #   printf '%s' "${value[@]}"
  #   return 0
    return 1
  elif [[ "${value:0:1}" == "'" ]]; then
    strip -s "${value}" -c "'"
    return 0
  elif [[ "${value:0:1}" == '"' ]]; then
    strip -s "${value}" -c '"'
    return 0
  else
  #   printf '%s' "${value[@]}"
  #   return 0
    return 1
  fi
} # __unquote

setx='__startsMappedSequence'
#==============================
# Check whether a line starts a mapped sequence
#==============================
__startsMappedSequence() {
  local line="$@"
  [[ "${line:0:2}" == '- ' ]] && [[ "${line: -1:1}" == ':' ]]
} # __startsMappedSequence

setx='__returnMappedSequence'
#==============================
# Returns an array and modifies the global associative array delayedPath
#==============================
__returnMappedSequence() {
  local line="$@" key= clave
  local -a array=()
  local -i pos indent
  
  key="$(__unquote "$(strip -s "${line:1:-1}")")"
  array[${key}]='@_' # si el valor de una key en un array es un array vacío
                     # lo podremos detectar con '@_'

  # OJO : postpuesto el tratamiento del this.
  # $this->delayedPath = array(strpos ($line, $key) + $this->indent => $key);
  pos=$(index -s "${line}" -c "${key}")
  indent= # OJO!! necesitamos recuperar el indent!!
  clave=$(( pos + indent ))
  delayedPath=(
    ["${clave}"]="${key}"
  )

  printf '%s ' "${array[@]}"
} # __returnMappedSequence

setx='__checkKeysInValue'
#==============================
__checkKeysInValue() {
  local -a value=( "$@" )

  if ! true ; then
#     if (strchr('[{"\'', $value[0]) === false) {
    if false; then
#       if (strchr($value, ': ') !== false) {
      echo 'Too many keys: ' "${value[@]}" 1>&2
      return 1
    fi
  fi
} # __checkKeysInValue

setx='__returnMappedValue'
#==============================
# Prints out an array
#==============================
__returnMappedValue() {
  local line="$@" key=
  local -a array=()

  # OJO : postpuesto el tratamiento del this.
  #     $this->checkKeysInValue($line);
  this=$(__checkKeysInValue "${line}" )

  key="$(__unquote "$(strip -s "${line:0:-1}")")"
  array[${key}]=''

  printf '%s ' "${array[@]}"
} # __returnMappedValue

setx='__startsMappedValue'
#==============================
__startsMappedValue() {
  local line="$@"
  [[ "${line: -1:1}" == ':' ]]
} # __startsMappedValue

setx='__isPlainArray'
#==============================
__isPlainArray() {
  local line="$@"
  [[ "${line:0:1}" == '[' ]] && [[ "${line: -1:1}" == ']' ]]
} # __isPlainArray

setx='__returnPlainArray'
#==============================
__returnPlainArray() {
  local line="$@"
#     return $this->_toType($line);
} # __returnPlainArray

setx='__returnKeyValuePair'
#==============================
__returnKeyValuePair() {
  local line="$@" key value explode
  local -a array=()
  local pattern="^([\"'](.*)[\"']([[:space:]])*:)"

  if [[ "${line}" =~ ': ' ]]; then
    # It's a key/value pair most likely
    # If the key is in double quotes pull it out
    if ( [[ "${line:0:1}" == '"' ]] || [[ "${line:0:1}" == "'" ]] ) && \
      [[ "${line}" =~ ${pattern} ]]
    then
# OJO : escoja por favor:
#      value="$(strip -s "${BASH_REMATCH[1]//${line}}")"
      value="$(strip -s "${line//${BASH_REMATCH[1]}}")"
      key="${BASH_REMATCH[2]}"
    else
      key=$(strip -s "${line%%: *}")
      value=$(strip -s "${line#*: }")
#         $this->checkKeysInValue($value);
      __checkKeysInValue -v "${value}"
    fi

#       // Set the type of the value.  Int, string, etc
#       $value = $this->_toType($value);
#       if ($key === '0') $key = '__!YAMLZero';
#       $array[$key] = $value;
#     } else {
#       $array = array ($line);
  fi
#     return $array;
} # __returnKeyValuePair

setx='__returnArrayElement'
#==============================
# Prints out an array?
#==============================
__returnArrayElement() {
  local line="$@"

  # OJO: primer return
  [ "${#line}" -gt 1 ] || return 1 # return array(array()); // Weird %)

  local -a array=()
  local value="$(strip -s "${line:1}")"
  value="$(__toType "${value}")" #      $value   = $this->_toType($value);

  if __isArrayElement "${value}"; then
    value="$(__returnArrayElement "${value}")"
  fi

  array=( "${value}" )

  printf '%s ' "${array[@]}"

#      if ($this->isArrayElement($value)) {
#        $value = $this->returnArrayElement($value);
#      }
#      $array[] = $value;
#      return $array;
} # __returnArrayElement

setx='__nodeContainsGroup'
#==============================
__nodeContainsGroup() {
  local line="$@"
  local Regex1='^(&[A-z0-9_\-]+)'
  local Regex2='^(\*[A-z0-9_\-]+)'
  local Regex3='(&[A-z0-9_\-]+)$'
  local Regex4='(\*[A-z0-9_\-]+$)'
  local Regex5='^[[:space:]]*<<[[:space:]]*:[[:space:]]*(\*[^[:space:]]+).*$'

  if ! index -s "${line}" -c '&' && ! index -s "${line}" -c '*'; then
    return 1
  elif [[ "${line:0:1}" == '&' ]] && [[ "${line}" =~ $Regex1 ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  elif [[ "${line:0:1}" == '*' ]] && [[ "${line}" =~ $Regex2 ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  elif [[ "${line}" =~ $Regex3 ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  elif [[ "${line}" =~ $Regex4 ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  elif [[ "${line}" =~ $Regex5 ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
} # __nodeContainsGroup

setx='__addGroup'
#==============================
# Modifies if necessary the env vars:
# _containsGroupAnchor
# _containsGroupAlias
#==============================
__addGroup() {
  local line="$1"; shift
  local group="$@"

  if [[ "${group:0:1}" == '&' ]]; then
    _containsGroupAnchor="${group:1}"
  fi

  if [[ "${group:0:1}" == '*' ]]; then
    _containsGroupAlias="${group:1}"
  fi 
} # __addGroup

setx='__stripGroup'
#==============================
# Prints out the stripped group
#==============================
__stripGroup() {
  local line="$1"; shift
  local group="$@"
  line="$(strip -s "${group//${line}}")"
  printf '%s' "${line}"

# OJO : devuelve la línea correctamente?
#  local line group 
#  local -i OPTIND=1

#  while getopts :g: opt ; do
#    case "$opt" in
#      g) group="$OPTARG" ;;
#      # l)  line="$OPTARG" ;;
#    esac
#  done
#  shift $(($OPTIND - 1))

#  line="${@}"
#  line="${line//${group}}"
#  line="$(strip -s "${line}")"

#  printf '%s' "${line}"
} # __stripGroup

## FIN DE LA CLASE.

setx=usage
#==============================
usage() {
  if [ $# -lt 1 ]; then
    sed -n "
      /^#%/ {
        s/\${PROGNAME}/${PROGNAME}/g
        s/^#%//p
      }" $0
    exit 1
  fi
} # usage


# setx=_exit
# #==============================
# _exit() {
#   rm -fr ${tmpDir}
#   exit $1
# } # _exit


#==============================
# MAIN SHELL BODY
#==============================
setx=main
main() {
  # local ...=...
  usage $ARGS
  # readCmdLineParameters $ARGS
} # main
main
# _exit
# --------------------------------------------------------------------------- #
