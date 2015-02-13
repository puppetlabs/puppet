class test($param_a = 1, $param_b = 2, $param_c = 3) {
  notify { "$param_a, $param_b, $param_c": }
}

include test
include dataprovider::test
