class one {
  class test($param_a = "param default is 100", $param_b = "param default is 200", $param_c = "param default is 300") {
    notify { "$param_a, $param_b, $param_c": }
  }
}
