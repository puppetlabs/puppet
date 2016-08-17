function bar() {
  'some data'
}

class foo::bar {
  notify { "${bar()}": }
}

include foo::bar
