Puppet::Parser::Functions::newfunction(:fqdn_rand, :type => :rvalue, :doc =>
    "Generates random numbers based on the node's fqdn. The first argument
    sets the range.  Additional (optional) arguments may be used to further 
    distinguish the seed.") do |args|
        require 'md5'
        max = args.shift
        srand MD5.new([lookupvar('fqdn'),args].join(':')).to_s.hex
        rand(max).to_s
end
