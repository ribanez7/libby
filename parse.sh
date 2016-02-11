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
path=''
result=''
LiteralPlaceHolder='___YAML_Literal_Block___'
_nodeId=''

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
  echo __loadString $input
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
  local array string=''
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

  # New YAML document
  if [ -f ${array} ]; then
#       $array = (array)$array;
#       $previous_key = -1;
#       foreach ($array as $key => $value) {
#         if (!isset($first_key)) $first_key = $key;
#         $string .= $this->_yamlize($key,$value,0,$previous_key, $first_key, $array);
#         $previous_key = $key;
#       }
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
# -s $source_array : by default none.
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
      s) source_array="$OPTARG";;
    esac
  done
  shift $(($OPTIND - 1))



  #   if (is_array($value)) {
  #   if (empty ($value))
  #     return $this->_dumpNode($key, array(), $indent, $previous_key, $first_key, $source_array);
  #   // It has children.  What to do?
  #   // Make it the right kind of item
  #   $string = $this->_dumpNode($key, self::REMPTY, $indent, $previous_key, $first_key, $source_array);
  #   // Add the indent
  #   $indent += $this->_dumpIndent;
  #   // Yamlize the array
  #   $string .= $this->_yamlizeArray($value,$indent);
  # } elseif (!is_array($value)) {
  #   // It doesn't have children.  Yip.
  #   $string = $this->_dumpNode($key, $value, $indent, $previous_key, $first_key, $source_array);
  # }
  # return $string;
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
#($array,$indent)
  # if (is_array($array)) {
  #   $string = '';
  #   $previous_key = -1;
  #   foreach ($array as $key => $value) {
  #     if (!isset($first_key)) $first_key = $key;
  #     $string .= $this->_yamlize($key, $value, $indent, $previous_key, $first_key, $array);
  #     $previous_key = $key;
  #   }
  #   return $string;
  # } else {
  #   return false;
  # }
} # __yamleizeArray

setx='__dumpNode'
#==============================
# Returns YAML from a key and a value
# @access private
# @return string
# @param $key The name of the key
# @param $value The value of the item
# @param $indent The indent of the current node
#==============================
__dumpNode() {
#($key, $value, $indent, $previous_key = -1, $first_key = 0, $source_array = null)
  local key value
  local -i indent previous_key=-1 first_key=0 OPTIND=1
  local -a source_array=()
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

  # OJO: función is_string, quizás debería ser un método y no una función en utils
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
  
  # if ($value === "") $value = '""';
  if [[ -z ${value} ]]; then
    value='""'
  fi

  # if (self::isTranslationWord($value)) {
  #   $value = $this->_doLiteralBlock($value, $indent);
  # }
  if __isTranslationWord "${value}"; then
    value="$(__doLiteralBlock -i "${indent}" -v "${value}")"
  fi

  # if (trim ($value) != $value)
  #   $value = $this->_doLiteralBlock($value, $indent);
  if [[ "$(strip -s "${value}")" != "${value}" ]]; then
    value="$(__doLiteralBlock -i "${indent}" -v "${value}")"
  fi

  # if (is_bool($value)) {
  #    $value = $value ? "true" : "false";
  # } OJO: crear método.
  if __is_bool "${value}"; then
    value=$( [[ ${value} ]] && printf true || printf false )
  fi
  
  # if ($value === null) $value = 'null';
  if __is_null "${value}"; then value='null'; fi

  # if ($value === "'" . self::REMPTY . "'") $value = null;
  if [[ "${value}" == "'$REMPTY'" ]]; then
    value='null'
  fi
  
  # $spaces = str_repeat(' ',$indent);
  spaces="$(printf '%*s' ${indent})"
  
  # //if (is_int($key) && $key - 1 == $previous_key && $first_key===0) {
  # if (is_array ($source_array) && array_keys($source_array) === range(0, count($source_array) - 1)) {
  #   // It's a sequence
  #   $string = $spaces.'- '.$value."\n";
  # } else {
  #   // if ($first_key===0)  throw new Exception('Keys are all screwy.  The first one was zero, now it\'s "'. $key .'"');
  #   // It's mapped
  #   if (strpos($key, ":") !== false || strpos($key, "#") !== false) { $key = '"' . $key . '"'; }
  #   $string = rtrim ($spaces.$key.': '.$value)."\n";
  # }
  # return $string;
} # __dumpNode

setx='__doLiteralBlock'
#==============================
# Creates a literal block for dumping
# @access private
# @return string
# @param $value
# @param $indent int The value of the indent
#==============================
__doLiteralBlock() {
#($value,$indent)
  # if ($value === "\n") return '\n';
  # if (strpos($value, "\n") === false && strpos($value, "'") === false) {
  #   return sprintf ("'%s'", $value);
  # }
  # if (strpos($value, "\n") === false && strpos($value, '"') === false) {
  #   return sprintf ('"%s"', $value);
  # }
  # $exploded = explode("\n",$value);
  # $newValue = '|';
  # if (isset($exploded[0]) && ($exploded[0] == "|" || $exploded[0] == "|-" || $exploded[0] == ">")) {
  #     $newValue = $exploded[0];
  #     unset($exploded[0]);
  # }
  # $indent += $this->_dumpIndent;
  # $spaces   = str_repeat(' ',$indent);
  # foreach ($exploded as $line) {
  #   $line = trim($line);
  #   if (strpos($line, '"') === 0 && strrpos($line, '"') == (strlen($line)-1) || strpos($line, "'") === 0 && strrpos($line, "'") == (strlen($line)-1)) {
  #     $line = substr($line, 1, -1);
  #   }
  #   $newValue .= "\n" . $spaces . ($line);
  # }
  # return $newValue;
} # __doLiteralBlock

setx='__doFolding'
#==============================
# Folds a string of text, if necessary
# @access private
# @return string
# @param $value The string you wish to fold
#==============================
__doFolding() {
#($value,$indent)
  # // Don't do anything if wordwrap is set to 0
  # if ($this->_dumpWordWrap !== 0 && is_string ($value) && strlen($value) > $this->_dumpWordWrap) {
  #   $indent += $this->_dumpIndent;
  #   $indent = str_repeat(' ',$indent);
  #   $wrapped = wordwrap($value,$this->_dumpWordWrap,"\n$indent");
  #   $value   = ">\n".$indent.$wrapped;
  # } else {
  #   if ($this->setting_dump_force_quotes && is_string ($value) && $value !== self::REMPTY)
  #     $value = '"' . $value . '"';
  #   if (is_numeric($value) && is_string($value))
  #     $value = '"' . $value . '"';
  # }
  # return $value;
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
__load() {
  local input=$1
#     $Source = $this->loadFromSource($input);
#     return $this->loadWithSource($Source);
} # __load

setx='__loadString'
#==============================
__loadString() {
  local input=$1
#     $Source = $this->loadFromString($input);
#     return $this->loadWithSource($Source);
} # __loadString

setx='__loadWithSource'
#==============================
__loadWithSource() {
#($Source)
#     if (empty ($Source)) return array();
#     if ($this->setting_use_syck_is_possible && function_exists ('syck_load')) {
#       $array = syck_load (implode ("\n", $Source));
#       return is_array($array) ? $array : array();
#     }

#     $this->path = array();
#     $this->result = array();

#     $cnt = count($Source);
#     for ($i = 0; $i < $cnt; $i++) {
#       $line = $Source[$i];

#       $this->indent = strlen($line) - strlen(ltrim($line));
#       $tempPath = $this->getParentPathByIndent($this->indent);
#       $line = self::stripIndent($line, $this->indent);
#       if (self::isComment($line)) continue;
#       if (self::isEmpty($line)) continue;
#       $this->path = $tempPath;

#       $literalBlockStyle = self::startsLiteralBlock($line);
#       if ($literalBlockStyle) {
#         $line = rtrim ($line, $literalBlockStyle . " \n");
#         $literalBlock = '';
#         $line .= ' '.$this->LiteralPlaceHolder;
#         $literal_block_indent = strlen($Source[$i+1]) - strlen(ltrim($Source[$i+1]));
#         while (++$i < $cnt && $this->literalBlockContinues($Source[$i], $this->indent)) {
#           $literalBlock = $this->addLiteralLine($literalBlock, $Source[$i], $literalBlockStyle, $literal_block_indent);
#         }
#         $i--;
#       }

#       // Strip out comments
#       if (strpos ($line, '#')) {
#           $line = preg_replace('/\s*#([^"\']+)$/','',$line);
#       }

#       while (++$i < $cnt && self::greedilyNeedNextLine($line)) {
#         $line = rtrim ($line, " \n\t\r") . ' ' . ltrim ($Source[$i], " \t");
#       }
#       $i--;

#       $lineArray = $this->_parseLine($line);

#       if ($literalBlockStyle)
#         $lineArray = $this->revertLiteralPlaceHolder ($lineArray, $literalBlock);

#       $this->addArray($lineArray, $this->indent);

#       foreach ($this->delayedPath as $indent => $delayedPath)
#         $this->path[$indent] = $delayedPath;

#       $this->delayedPath = array();

#     }
#     return $this->result;
} # __loadWithSource

setx='__loadFromSource'
#==============================
# OJO
__loadFromSource() {
  local input="$@"

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
#     $line = trim($line);
#     if (!$line) return array();

  local -a array=()
#     $array = array();
  local group=$(__nodeContainsGroup "${line}")
  if [[ -n "${group}"]]; then
    __addGroup -l "${line}" -g "${group}"
    line=$(__stripGroup -l "${line}" -g "${group}")
  fi
#     $group = $this->nodeContainsGroup($line);
#     if ($group) {
#       $this->addGroup($line, $group);
#       $line = $this->stripGroup ($line, $group);
#     }

#     if ($this->startsMappedSequence($line))
#       return $this->returnMappedSequence($line);

#     if ($this->startsMappedValue($line))
#       return $this->returnMappedValue($line);

#     if ($this->isArrayElement($line))
#      return $this->returnArrayElement($line);

#     if ($this->isPlainArray($line))
#      return $this->returnPlainArray($line);


#     return $this->returnKeyValuePair($line);
} # __parseLine

setx='__toType'
#==============================
# Finds the type of the passed value, returns the value as the new type.
# @access private
# @param string $value
# @return mixed
#==============================
__toType() {
  local value=$1
#     if ($value === '') return "";
#     $first_character = $value[0];
#     $last_character = substr($value, -1, 1);

#     $is_quoted = false;
#     do {
#       if (!$value) break;
#       if ($first_character != '"' && $first_character != "'") break;
#       if ($last_character != '"' && $last_character != "'") break;
#       $is_quoted = true;
#     } while (0);

#     if ($is_quoted) {
#       $value = str_replace('\n', "\n", $value);
#       return strtr(substr ($value, 1, -1), array ('\\"' => '"', '\'\'' => '\'', '\\\'' => '\''));
#     }

#     if (strpos($value, ' #') !== false && !$is_quoted)
#       $value = preg_replace('/\s+#(.+)$/','',$value);

#     if ($first_character == '[' && $last_character == ']') {
#       // Take out strings sequences and mappings
#       $innerValue = trim(substr ($value, 1, -1));
#       if ($innerValue === '') return array();
#       $explode = $this->_inlineEscape($innerValue);
#       // Propagate value array
#       $value  = array();
#       foreach ($explode as $v) {
#         $value[] = $this->_toType($v);
#       }
#       return $value;
#     }

#     if (strpos($value,': ')!==false && $first_character != '{') {
#       $array = explode(': ',$value);
#       $key   = trim($array[0]);
#       array_shift($array);
#       $value = trim(implode(': ',$array));
#       $value = $this->_toType($value);
#       return array($key => $value);
#     }

#     if ($first_character == '{' && $last_character == '}') {
#       $innerValue = trim(substr ($value, 1, -1));
#       if ($innerValue === '') return array();
#       // Inline Mapping
#       // Take out strings sequences and mappings
#       $explode = $this->_inlineEscape($innerValue);
#       // Propagate value array
#       $array = array();
#       foreach ($explode as $v) {
#         $SubArr = $this->_toType($v);
#         if (empty($SubArr)) continue;
#         if (is_array ($SubArr)) {
#           $array[key($SubArr)] = $SubArr[key($SubArr)]; continue;
#         }
#         $array[] = $SubArr;
#       }
#       return $array;
#     }

#     if ($value == 'null' || $value == 'NULL' || $value == 'Null' || $value == '' || $value == '~') {
#       return null;
#     }

#     if ( is_numeric($value) && preg_match ('/^(-|)[1-9]+[0-9]*$/', $value) ){
#       $intvalue = (int)$value;
#       if ($intvalue != PHP_INT_MAX)
#         $value = $intvalue;
#       return $value;
#     }

#     if (is_numeric($value) && preg_match('/^0[xX][0-9a-fA-F]+$/', $value)) {
#       // Hexadecimal value.
#       return hexdec($value);
#     }

#NOTAS: value=$(coerceValue $value)
#     $this->coerceValue($value);

#     if (is_numeric($value)) {
#       if ($value === '0') return 0;
#       if (rtrim ($value, 0) === $value)
#         $value = (float)$value;
#       return $value;
#     }

#     return $value;
} # __toType

setx='__inlineEscape'
#==============================
# Used in inlines to check for more inlines or quoted strings
# @access private
# @return array
#==============================
__inlineEscape() {
  local inline=$1 #($inline)
#     // There's gotta be a cleaner way to do this...
#     // While pure sequences seem to be nesting just fine,
#     // pure mappings and mappings with sequences inside can't go very
#     // deep.  This needs to be fixed.

#     $seqs = array();
#     $maps = array();
#     $saved_strings = array();
#     $saved_empties = array();

#     // Check for empty strings
#     $regex = '/("")|(\'\')/';
#     if (preg_match_all($regex,$inline,$strings)) {
#       $saved_empties = $strings[0];
#       $inline  = preg_replace($regex,'YAMLEmpty',$inline);
#     }
#     unset($regex);

#     // Check for strings
#     $regex = '/(?:(")|(?:\'))((?(1)[^"]+|[^\']+))(?(1)"|\')/';
#     if (preg_match_all($regex,$inline,$strings)) {
#       $saved_strings = $strings[0];
#       $inline  = preg_replace($regex,'YAMLString',$inline);
#     }
#     unset($regex);

#     // echo $inline;

#     $i = 0;
#     do {

#     // Check for sequences
#     while (preg_match('/\[([^{}\[\]]+)\]/U',$inline,$matchseqs)) {
#       $seqs[] = $matchseqs[0];
#       $inline = preg_replace('/\[([^{}\[\]]+)\]/U', ('YAMLSeq' . (count($seqs) - 1) . 's'), $inline, 1);
#     }

#     // Check for mappings
#     while (preg_match('/{([^\[\]{}]+)}/U',$inline,$matchmaps)) {
#       $maps[] = $matchmaps[0];
#       $inline = preg_replace('/{([^\[\]{}]+)}/U', ('YAMLMap' . (count($maps) - 1) . 's'), $inline, 1);
#     }

#     if ($i++ >= 10) break;

#     } while (strpos ($inline, '[') !== false || strpos ($inline, '{') !== false);

#     $explode = explode(',',$inline);
#     $explode = array_map('trim', $explode);
#     $stringi = 0; $i = 0;

#     while (1) {

#     // Re-add the sequences
#     if (!empty($seqs)) {
#       foreach ($explode as $key => $value) {
#         if (strpos($value,'YAMLSeq') !== false) {
#           foreach ($seqs as $seqk => $seq) {
#             $explode[$key] = str_replace(('YAMLSeq'.$seqk.'s'),$seq,$value);
#             $value = $explode[$key];
#           }
#         }
#       }
#     }

#     // Re-add the mappings
#     if (!empty($maps)) {
#       foreach ($explode as $key => $value) {
#         if (strpos($value,'YAMLMap') !== false) {
#           foreach ($maps as $mapk => $map) {
#             $explode[$key] = str_replace(('YAMLMap'.$mapk.'s'), $map, $value);
#             $value = $explode[$key];
#           }
#         }
#       }
#     }


#     // Re-add the strings
#     if (!empty($saved_strings)) {
#       foreach ($explode as $key => $value) {
#         while (strpos($value,'YAMLString') !== false) {
#           $explode[$key] = preg_replace('/YAMLString/',$saved_strings[$stringi],$value, 1);
#           unset($saved_strings[$stringi]);
#           ++$stringi;
#           $value = $explode[$key];
#         }
#       }
#     }


#     // Re-add the empties
#     if (!empty($saved_empties)) {
#       foreach ($explode as $key => $value) {
#         while (strpos($value,'YAMLEmpty') !== false) {
#           $explode[$key] = preg_replace('/YAMLEmpty/', '', $value, 1);
#           $value = $explode[$key];
#         }
#       }
#     }

#     $finished = true;
#     foreach ($explode as $key => $value) {
#       if (strpos($value,'YAMLSeq') !== false) {
#         $finished = false; break;
#       }
#       if (strpos($value,'YAMLMap') !== false) {
#         $finished = false; break;
#       }
#       if (strpos($value,'YAMLString') !== false) {
#         $finished = false; break;
#       }
#       if (strpos($value,'YAMLEmpty') !== false) {
#         $finished = false; break;
#       }
#     }
#     if ($finished) break;

#     $i++;
#     if ($i > 10)
#       break; // Prevent infinite loops.
#     }


#     return $explode;
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
      echo
    if ! : ; then
      break
    fi
  done
  
#     do {
#       if (!isset($this->SavedGroups[$alias])) { echo "Bad group name: $alias."; break; }
#       $groupPath = $this->SavedGroups[$alias];
#       $value = $this->result;
#       foreach ($groupPath as $k) {
#         $value = $value[$k];
#       }
#     } while (false);
#     return $value;
} # __referenceContentsByAlias

setx='__addArrayInline'
#==============================
__addArrayInline(){
#($array, $indent)
#       $CommonGroupPath = $this->path;
#       if (empty ($array)) return false;

#       foreach ($array as $k => $_) {
#         $this->addArray(array($k => $_), $indent);
#         $this->path = $CommonGroupPath;
#       }
#       return true;
} # __addArrayInline

setx='__addArray'
#==============================
__addArray() {
#($incoming_data, $incoming_indent)
#    // print_r ($incoming_data);

#     if (count ($incoming_data) > 1)
#       return $this->addArrayInline ($incoming_data, $incoming_indent);

#     $key = key ($incoming_data);
#     $value = isset($incoming_data[$key]) ? $incoming_data[$key] : null;
#     if ($key === '__!YAMLZero') $key = '0';

#     if ($incoming_indent == 0 && !$this->_containsGroupAlias && !$this->_containsGroupAnchor) { // Shortcut for root-level values.
#       if ($key || $key === '' || $key === '0') {
#         $this->result[$key] = $value;
#       } else {
#         $this->result[] = $value; end ($this->result); $key = key ($this->result);
#       }
#       $this->path[$incoming_indent] = $key;
#       return;
#     }



#     $history = array();
#     // Unfolding inner array tree.
#     $history[] = $_arr = $this->result;
#     foreach ($this->path as $k) {
#       $history[] = $_arr = $_arr[$k];
#     }

#     if ($this->_containsGroupAlias) {
#       $value = $this->referenceContentsByAlias($this->_containsGroupAlias);
#       $this->_containsGroupAlias = false;
#     }


#     // Adding string or numeric key to the innermost level or $this->arr.
#     if (is_string($key) && $key == '<<') {
#       if (!is_array ($_arr)) { $_arr = array (); }

#       $_arr = array_merge ($_arr, $value);
#     } else if ($key || $key === '' || $key === '0') {
#       if (!is_array ($_arr))
#         $_arr = array ($key=>$value);
#       else
#         $_arr[$key] = $value;
#     } else {
#       if (!is_array ($_arr)) { $_arr = array ($value); $key = 0; }
#       else { $_arr[] = $value; end ($_arr); $key = key ($_arr); }
#     }

#     $reverse_path = array_reverse($this->path);
#     $reverse_history = array_reverse ($history);
#     $reverse_history[0] = $_arr;
#     $cnt = count($reverse_history) - 1;
#     for ($i = 0; $i < $cnt; $i++) {
#       $reverse_history[$i+1][$reverse_path[$i]] = $reverse_history[$i];
#     }
#     $this->result = $reverse_history[$cnt];

#     $this->path[$incoming_indent] = $key;

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
        strip_line='' \
        lastChar='' \
        html_pattern='<.*?>$'

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
#     $line = self::stripIndent($line, $indent);
#     if ($literalBlockStyle !== '|') {
#         $line = self::stripIndent($line);
#     }
#     $line = rtrim ($line, "\r\n\t ") . "\n";
#     if ($literalBlockStyle == '|') {
#       return $literalBlock . $line;
#     }
#     if (strlen($line) == 0)
#       return rtrim($literalBlock, ' ') . "\n";
#     if ($line == "\n" && $literalBlockStyle == '>') {
#       return rtrim ($literalBlock, " \t") . "\n";
#     }
#     if ($line != "\n")
#       $line = trim ($line, "\r\n ") . " ";
#     return $literalBlock . $line;
} # __addLiteralLine

setx='revertLiteralPlaceHolder'
#==============================
revertLiteralPlaceHolder() {
#($lineArray, $literalBlock)
#      foreach ($lineArray as $k => $_) {
#       if (is_array($_))
#         $lineArray[$k] = $this->revertLiteralPlaceHolder ($_, $literalBlock);
#       else if (substr($_, -1 * strlen ($this->LiteralPlaceHolder)) == $this->LiteralPlaceHolder)
# 	       $lineArray[$k] = rtrim ($literalBlock, " \r\n");
#      }
#      return $lineArray;
} # revertLiteralPlaceHolder

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
      l) line="$OPTARG" ;;
      i) is_integer "$OPTARG" && indent="$OPTARG" || : ;;
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
__getParentPathByIndent() {
#($indent)
  local indent=$1

#     if ($indent == 0) return array();
#     $linePath = $this->path;
#     do {
#       end($linePath); $lastIndentInParentPath = key($linePath);
#       if ($indent <= $lastIndentInParentPath) array_pop ($linePath);
#     } while ($indent <= $lastIndentInParentPath);
#     return $linePath;
} # __getParentPathByIndent

setx='__clearBiggerPathValues'
#==============================
__clearBiggerPathValues() {
#($indent)
#     if ($indent == 0) $this->path = array();
#     if (empty ($this->path)) return true;

#     foreach ($this->path as $k => $_) {
#       if ($k > $indent) unset ($this->path[$k]);
#     }

#     return true;
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
__returnMappedSequence() {
  local line="$@"
#     $array = array();
#     $key         = self::unquote(trim(substr($line,1,-1)));
#     $array[$key] = array();
#     $this->delayedPath = array(strpos ($line, $key) + $this->indent => $key);
#     return array($array);
} # __returnMappedSequence

setx='__checkKeysInValue'
#==============================
__checkKeysInValue() {
#($value)
#     if (strchr('[{"\'', $value[0]) === false) {
#       if (strchr($value, ': ') !== false) {
#           throw new Exception('Too many keys: '.$value);
#       }
#     }
} # __checkKeysInValue

setx='__returnMappedValue'
#==============================
__returnMappedValue() {
  local line="$@"
#     $this->checkKeysInValue($line);
#     $array = array();
#     $key         = self::unquote (trim(substr($line,0,-1)));
#     $array[$key] = '';
#     return $array;
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
__returnArrayElement() {
  local line="$@"
#      if (strlen($line) <= 1) return array(array()); // Weird %)
#      $array = array();
#      $value   = trim(substr($line,1));
#      $value   = $this->_toType($value);
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
__addGroup() {
# OJO : VARIABLE CONTAINSGROUPANCHOR y CONTAINSGROUPALIAS
# DEBERÍAN SER SIMPLEMENTE BOOLEANS 0 Ó 1
  local line group 
  local -i OPTIND=1

  while getopts :g: opt ; do
    case "$opt" in
      g) group="$OPTARG" ;;
      # l)  line="$OPTARG" ;;
    esac
  done
  shift $(($OPTIND - 1))

  line="${@}"

  if [[ "${group:0:1}" == '&' ]]; then
    # $this->_containsGroupAnchor = substr ($group, 1);
    _containsGroupAnchor="${group:1}"
  elif [[ "${group:0:1}" == '*' ]]; then
    # $this->_containsGroupAlias = substr ($group, 1);
    _containsGroupAlias="${group:1}"
  fi

} # __addGroup

setx='__stripGroup'
#==============================
__stripGroup() {
# OJO : devuelve la línea correctamente?
  local line group 
  local -i OPTIND=1

  while getopts :g: opt ; do
    case "$opt" in
      g) group="$OPTARG" ;;
      # l)  line="$OPTARG" ;;
    esac
  done
  shift $(($OPTIND - 1))

  line="${@}"
  line="${line//${group}}"
  line="$(strip -s "${line}")"

  printf '%s' "${line}"
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
