class xyz {
  include 'xyz::def'
}

class xyz::def ($test1, $test2, $test3) {
  notify { $test1: }
  notify { $test2: }
  notify { $test3: }
}
