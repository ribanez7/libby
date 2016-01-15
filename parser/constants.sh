#!/bin/bash
readonly -A REGEX=(
  # A line containing only (valid) whitespace:
  [blank-line]='^ *$'
  # A line contatining a YAML directive:
  [directive]='^\(?:--- \)? *%\(\w+\)'
  # A document delimiter line:
  [document-delimiter]='^ *\(?:---\|[.][.][.]\)'
  # A node anchor or alias:
  [node-anchor-alias]='[&*][a-zA-Z0-9_-]+'
  # A tag:
  [tag]='!!?[^ \n]+'
  # A bare scalar:
  [bare-scalar]='\(?:[^-:,#!\n{\[ ]\|[^#!\n{\[ ]\S-\)[^#\n]*?'
  # A single YAML hash key:
  [hash-key_1]='\(?:^\(?:--- \)?\|{\|\(?:[-,] +\)+\) *'
  [hash-key_2]="\\(?:${REGEX[tag]} +\\)?"
  [hash-key_3]="\\(${REGEX[bare-scalar]}\\) *:"
  [hash-key_4]='\(?: +\|$\)'
  # The beginning of a scalar context:
  [scalar-context_1]='\(?:^\(?:--- \)?\|{\|\(?: *[-,] +\)+\) *'
  [scalar-context_2]="\\(?:${REGEX[bare-scalar]} *: \\)?"
  # A line beginning a nested structure:
  [nested-map]=".*: *\\(?:&.*\\|{ *\\|${REGEX[tag]} *\\)?\$"
  # The substring start of a block literal:
  [block-literal-base]=" *[>|][-+0-9]* *\\(?:\n\\|\\'\\)"
  # A line beginning a YAML block literal:
  [block-literal_1]="${REGEX[scalar-context]}"
  [block-literal_2]="\\(?:${REGEX[tag]}\\)?"
  [block-literal_3]="${REGEX[block-literal-base]}"
  # A line containing one or more nested YAML sequences:
  [nested-sequence_1]='^\(?:\(?: *- +\)+\|\(:? *-$\)\)'
  [nested-sequence_2]="\\(?:${REGEX[bare-scalar]} *:\\(?: +.*\\)?\\)?\$"
  # Certain scalar constants in scalar context:
  [constant-scalars_1]='\(?:^\|\(?::\|-\|,\|{\|\[\) +\) *'
  [constant-scalars_2]='\(~\|null\|Null\|NULL\|.nan\|.NaN\|.NAN\|.inf\|.Inf\|.INF\|-.inf\|-.Inf\|-.INF\|y\|Y\|yes\|Yes\|YES\|n\|N\|no\|No\|NO\|true\|True\|TRUE\|false\|False\|FALSE\|on\|On\|ON\|off\|Off\|OFF\)'
  [constant-scalars_3]=' *$'
)
