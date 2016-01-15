readonly -A R=(
  # General shorthands:
  [w]='[a-zA-Z0-9_]'
  [W]='[^a-zA-Z0-9_]'
  [d]='[0-9]'
  [D]='[^0-9]'
  [h]='[0-9a-fA-F]'
  [H]='[^0-9a-fA-F]'
  [s]='[ \t\r\n\f]'
  [S]='[^ \t\r\n\f]'

  # Specific YAML patterns:
  [blank-line]='^ *$'
  [directive]="^(--- )? *%(${R[w]}+)"
  [document-delimiter]='^ *(---|[.][.][.])'
  [node-anchor-alias]="[&*][${R[w]}-]+"
  [tag]='!!?[^ \n]+'
  [bare-scalar]="([^-:,#!\n{\[ ]|[^#!\n{\[ ]${R[S]})[^#\n]*?"
  [hash-key]="(^(--- )?|{|([-,] +)+) *(${R[tag]} +)?(${R[bare-scalar]}) *:( +|\$)"
  # The beginning of a scalar context:
  [scalar-context]="(^(--- )?|{|( *[-,] +)+) *(${R[bare-scalar]} *: )?"
  # A line beginning a nested structure:
  [nested-map]=".*: *(&.*|{ *|${R[tag]} *)?\$"
  # The substring start of a block literal:
  [block-literal-base]=" *[>|][-+0-9]* *(\n|')"
  # A line beginning a YAML block literal:
  [block-literal]="${R[scalar-context]}(${R[tag]})?${R[block-literal-base]}"
  # A line containing one or more nested YAML sequences:
  [nested-sequence]="^(( *- +)+|( *-\$))(${R[bare-scalar]} *:( +.*)?)?\$"
  # Certain scalar constants in scalar context:
  [constant-scalars]="(^|(:|-|,|{|\[) +) *(~|null|Null|NULL|.nan|.NaN|.NAN|.inf|.Inf|.INF|-.inf|-.Inf|-.INF|y|Y|yes|Yes|YES|n|N|no|No|NO|true|True|TRUE|false|False|FALSE|on|On|ON|off|Off|OFF) *\$"
)
readonly -i INDENT_OFFSET=2
