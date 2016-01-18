function is_valid_string? ()
{
  [[ $@ =~ ^[A-Za-z0-9]*$ ]]
}

function is_integer? ()
{
  [[ $@ =~ ^-?[0-9]+$ ]]
}
