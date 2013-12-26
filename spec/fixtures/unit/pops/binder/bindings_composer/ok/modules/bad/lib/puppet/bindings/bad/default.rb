nil + nil + nil # broken on purpose, this file should never be loaded

Puppet::Bindings.newbindings('bad::default') do |scope|
  nil + nil + nil # broken on purpose, this should never be evaluated
end