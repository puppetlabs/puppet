require 'md5'

Puppet::Parser::Functions::newfunction(:md5, :type => :rvalue, :doc => "Returns a MD5 hash value from a provided string.") do |args|
      Digest::MD5.hexdigest(args[0])
end
