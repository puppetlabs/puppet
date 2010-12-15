Puppet::Parser::Functions::newfunction(:sha1, :type => :rvalue, :doc => "Returns a SHA2 hash value from a provided string.") do |args|
      if args.size == 2
        Digest::SHA2.new(args[1]).hexdigest(args[0])
      elsif args.size == 1
        Digest::SHA2.hexdigest(args[0])
      else
        raise ArgumentError, "wrong number of arguments (#{args.size} for 2)"
      end
end