class hieraprovider {
  class test($param_a = "param default is 100") {
    notify { "$param_a": }
  }
}
