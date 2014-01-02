Puppet::Bindings.newbindings('awesome2::default') do |scope|
  bind.name('all your base').to('are belong to us')
  bind.name('env_meaning_of_life').to(puppet_string("$environment thinks it is 42", __FILE__))
  bind {
    name 'awesome_x'
    to 'golden'
  }
  bind {
    name 'the_meaning_of_life'
    to 100
  }
  bind {
    name 'has_funny_hat'
    to 'kkk'
  }
  bind {
    name 'good_x'
    to 'golden'
  }
end