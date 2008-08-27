Puppet::Parser::Functions::newfunction(:fqdn_rand, :type => :rvalue, :doc => 
    "Generates random numbers based on the node's fqdn. The first argument 
    sets the range.  The second argument specifies a number to add to the 
    seed and is optional.") do |args|
        require 'md5'
        max = args[0]
        if args[1] then
             seed = args[1]
        else
             seed = 1
        end
        fqdn_seed = MD5.new(lookupvar('fqdn')).to_s.hex
        srand(seed+fqdn_seed)
        rand(max).to_s
end
