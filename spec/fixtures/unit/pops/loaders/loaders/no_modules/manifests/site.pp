function bar() {
  $value_from_scope
}

class foo::bar {
  with(1) |$x| { notice $x }
  notify { bar(): }
}

include foo::bar
