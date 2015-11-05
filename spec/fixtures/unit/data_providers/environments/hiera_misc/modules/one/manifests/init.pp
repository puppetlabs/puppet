class one {
  class test($param = { key1 => 'default 1', key2 => 'default 2' }) {
    notify { "${param[key1]}, ${param[key2]}": }
  }

  class lopts_test($hash = { a => 'default A', b => 'default B', c => 'default C', m => {} }) {
    notify { "${hash[a]}, ${hash[b]}, ${hash[c]}, ${hash[m]['ma']}, ${hash[m]['mb']}, ${hash[m]['mc']}": }
  }

  class loptsm_test($hash = { a => 'default A', b => 'default B', c => 'default C', m => {} }) {
    notify { "${hash[a]}, ${hash[b]}, ${hash[c]}, ${hash[m]['ma']}, ${hash[m]['mb']}, ${hash[m]['mc']}": }
  }
}
