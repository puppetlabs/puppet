class abc {
  if $block != 'no_block_present' {
    $result = lookup(*$args) |$names| { if $block == true { $names } else { $block } }
  }
  else {
    $result = lookup(*$args)
  }
}
