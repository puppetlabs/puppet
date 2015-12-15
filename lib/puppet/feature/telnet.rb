require 'puppet/util/feature'

Puppet.features.add :telnet do
  begin
    require 'net/telnet'
  rescue LoadError
    false
  end
end
