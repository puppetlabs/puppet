Puppet::Parser::Functions::newfunction(:digest, :type => :rvalue, :doc => "Returns a hash value from a provided string using the digest_algorithm setting from the Puppet config file, or MD5 if that is not set.") do |args|
  require 'puppet/util/checksums'
  dc = Class.new { include Puppet::Util::Checksums }
  algo = Puppet[:digest_algorithm] || 'md5'
  dc.new.method(algo.intern).call args[0]
end
