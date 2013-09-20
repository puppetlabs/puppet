require 'digest/md5'

Puppet::Parser::Functions::newfunction(:fqdn_rand, :arity => -2, :type => :rvalue, :doc =>
  "Generates random numbers based on the node's fqdn. Generated random values
  will be a range from 0 up to and excluding n, where n is the first parameter.
  The second argument specifies a number to add to the seed and is optional, for example:

      $random_number = fqdn_rand(30)
      $random_number_seed = fqdn_rand(30,30)") do |args|
    max = args.shift.to_i
    seed = Digest::MD5.hexdigest([self['::fqdn'],args].join(':')).hex
    Puppet::Util.deterministic_rand(seed,max)
end
