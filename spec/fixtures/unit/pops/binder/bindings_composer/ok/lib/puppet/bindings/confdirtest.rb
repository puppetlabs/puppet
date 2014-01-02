Puppet::Bindings.newbindings('confdirtest') do |scope|
  bind {
    name 'has_funny_hat'
    to 'the pope'
  }
  bind {
    name 'the_meaning_of_life'
    to 42
  }
end