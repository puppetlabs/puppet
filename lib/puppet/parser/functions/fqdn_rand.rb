require 'digest/sha2'

Puppet::Parser::Functions::newfunction(:fqdn_rand, :arity => -2, :type => :rvalue, :doc =>
  "Usage: `fqdn_rand(MAX, [SEED])`. MAX is required and must be a positive
  integer; SEED is optional and may be any number or string.

  Generates a random Integer number greater than or equal to 0 and less than MAX,
  combining the `$fqdn` fact and the value of SEED for repeatable randomness.
  (That is, each node will get a different random number from this function, but
  a given node's result will be the same every time unless its hostname changes.)

  This function is usually used for spacing out runs of resource-intensive cron
  tasks that run on many nodes, which could cause a thundering herd or degrade
  other services if they all fire at once. Adding a SEED can be useful when you
  have more than one such task and need several unrelated random numbers per
  node. (For example, `fqdn_rand(30)`, `fqdn_rand(30, 'expensive job 1')`, and
  `fqdn_rand(30, 'expensive job 2')` will produce totally different numbers.)") do |args|
    max = args.shift.to_i
 
    # We are consciously not using different hash algs based on fips mode here
    # since the randomness is not guaranteed to be predictable for a given node
    # It just needs to be unique for a given node
    seed = Digest::SHA256.hexdigest([self['::fqdn'],max,args].join(':')).hex
    Puppet::Util.deterministic_rand_int(seed,max)
end
