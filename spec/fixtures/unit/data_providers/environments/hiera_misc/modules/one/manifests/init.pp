class one {
  class test($param = { key1 => 'default 1', key2 => 'default 2' }) {
    notify { "${param[key1]}, ${param[key2]}": }
  }
}
