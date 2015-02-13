class abc {
  if $block {
    $result = lookup(*$args) |$names| { if $block == true { $names } else { $block } }
  }
  else {
    $result = lookup(*$args)
  }
}
