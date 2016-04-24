function puppet_init_calling_puppet() {
  usee::usee_puppet()
}

function puppet_init_calling_puppet_init() {
  usee_puppet_init()
}

function puppet_init_calling_ruby() {
  usee::usee_ruby()
}

class user {
  # Dummy resource. Added just to assert that a ruby type in another module is loaded correctly
  # by the auto loader
  Usee_type {
    name => 'pelle'
  }

  case $::case_number {
    1: {
      # Call a puppet function that resides in usee/functions directly from init.pp
      #
      notify { 'case_1': message => usee::usee_puppet() }
    }
    2: {
      # Call a puppet function that resides in usee/manifests/init.pp directly from init.pp
      #
      include usee
      notify { 'case_2': message => usee_puppet_init() }
    }
    3: {
      # Call a ruby function that resides in usee directly from init.pp
      #
      notify { 'case_3': message => usee::usee_ruby() }
    }
    4: {
      # Call a puppet function that resides in usee/functions from a puppet function under functions
      #
      notify { 'case_4': message => user::puppet_calling_puppet() }
    }
    5: {
      # Call a puppet function that resides in usee/manifests/init.pp from a puppet function under functions
      #
      include usee
      notify { 'case_5': message => user::puppet_calling_puppet_init() }
    }
    6: {
      # Call a ruby function that resides in usee from a puppet function under functions
      #
      notify { 'case_6': message => user::puppet_calling_ruby() }
    }
    7: {
      # Call a puppet function that resides in usee/functions from a puppet function in init.pp
      #
      notify { 'case_7': message => puppet_init_calling_puppet() }
    }
    8: {
      # Call a puppet function that resides in usee/manifests/init.pp from a puppet function in init.pp
      #
      include usee
      notify { 'case_8': message => puppet_init_calling_puppet_init() }
    }
    9: {
      # Call a ruby function that resides in usee from a puppet function in init.pp
      #
      notify { 'case_9': message => puppet_init_calling_ruby() }
    }
    10: {
      # Call a puppet function that resides in usee/functions from a ruby function in this module
      #
      notify { 'case_10': message => user::ruby_calling_puppet() }
    }
    11: {
      # Call a puppet function that resides in usee/manifests/init.pp from a ruby function in this module
      #
      include usee
      notify { 'case_11': message => user::ruby_calling_puppet_init() }
    }
    12: {
      # Call a ruby function that resides in usee from a ruby function in this module
      #
      notify { 'case_12': message => user::ruby_calling_ruby() }
    }
  }
}

