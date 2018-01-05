require 'digest/sha2'

Puppet::Parser::Functions::newfunction(:sha256, :type => :rvalue, :arity => 1, :doc => "Returns a SHA256 hash value from a provided string.") do |args|
  Digest::SHA256.hexdigest(args[0])
end
