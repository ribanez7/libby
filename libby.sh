#!/bin/bash
#%
#% ${PROGNAME} - query a yaml file using the libby parser
#%
#% usage: ${PROGNAME}.sh -f <file> -q 
#%
#% where:
#%
#%  -h|--help       :  show this help
#%  -v|--verbose    :  verbose mode
#%  -d|--debug      :  debug mode, set -x
#%  -f|--file       :  file or files. Wilcards allowed. Must be last option
#%  -q|--query      :  queries after the q
#%
#%	Available queries:
#%
#%  return-key     --  <value>
#%  return-value   --  <key>
#%  fetch          --  <key:ifnone>   
#%  values-at      --  <key,key,key,...>
#%  omit-if        --  'boolean expression' 'boolean expression' '...'
#%  each-pair      --  'function previously defined with 2 parms'
#%  each-value     --  'function previously defined with 1 parm'
#%  each-key       --  'function previously defined with 1 parm'
#%  has-value      --  <value> (true if found)
#%
#% history:
#% 2016-02-15       :  created by Rubén Ibáñez Carmona
#%
