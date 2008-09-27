Puppet::Parser::Functions::newfunction(:sha1, :type => :rvalue,
        :doc => "Returns a SHA1 hash value from a provided string.") do |args|
            require 'sha1'

            Digest::SHA1.hexdigest(args[0])
end
