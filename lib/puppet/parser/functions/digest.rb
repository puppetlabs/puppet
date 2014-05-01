require 'puppet/util/checksums'
Puppet::Parser::Functions::newfunction(:digest, :type => :rvalue, :arity => 1, :doc => "Returns a hash value from a provided string using the digest_algorithm setting from the Puppet config file.") do |args|
  algo = Puppet[:digest_algorithm]
  Puppet::Util::Checksums.method(algo.intern).call args[0]
end
