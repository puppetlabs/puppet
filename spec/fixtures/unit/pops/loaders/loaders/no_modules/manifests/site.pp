function bar() {
  $value_from_scope
}

class foo::bar {
  notify { bar(): }
}

include foo::bar
