class one {
  class test($param_a = "param default is 100", $param_b = "param default is 200", $param_c = "param default is 300", $param_d = "param default is 400", $param_e = "param default is 500", $param_f = "param default is 600", $param_g = "param default is 700") {
    notify { "$param_a, $param_b, $param_c, $param_d, $param_e, $param_f, $param_g": }
  }
}
