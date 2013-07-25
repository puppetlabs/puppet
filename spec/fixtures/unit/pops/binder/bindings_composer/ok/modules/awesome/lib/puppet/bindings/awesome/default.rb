Puppet::Bindings.newbindings('awesome::default') do |scope|
  bind.name('all your base').to('are belong to us')
  bind.name('env_meaning_of_life').to(puppet_string("$environment thinks it is 42", __FILE__))
end