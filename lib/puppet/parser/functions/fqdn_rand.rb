Puppet::Parser::Functions::newfunction(:fqdn_rand, :type => :rvalue, :doc =>
  "Generates random numbers based on the node's fqdn. Generated random values
  will be a range from 0 up to and excluding n, where n is the first parameter.
  The second argument specifies a number to add to the seed and is optional, for example:

      $random_number = fqdn_rand(30)
      $random_number_seed = fqdn_rand(30,30)") do |args|
    require 'md5'
    max = args.shift
    srand MD5.new([lookupvar('fqdn'),args].join(':')).to_s.hex
    rand(max).to_s
end
