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
