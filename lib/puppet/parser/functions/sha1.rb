require 'digest/sha1'

Puppet::Parser::Functions::newfunction(:sha1, :type => :rvalue, :arity => 1, :doc => "Returns a SHA1 hash value from a provided string.") do |args|
      Digest::SHA1.hexdigest(args[0])
end
