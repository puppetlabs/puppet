# frozen_string_literal: true

require 'digest/md5'
require 'digest/sha2'

Puppet::Parser::Functions.newfunction(:fqdn_rand, :arity => -2, :type => :rvalue, :doc =>
  "Usage: `fqdn_rand(MAX, [SEED], [DOWNCASE])`. MAX is required and must be a positive
  integer; SEED is optional and may be any number or string; DOWNCASE is optional
  and should be a boolean true or false.

  Generates a random Integer number greater than or equal to 0 and less than MAX,
  combining the `$fqdn` fact and the value of SEED for repeatable randomness.
  (That is, each node will get a different random number from this function, but
  a given node's result will be the same every time unless its hostname changes.) If
  DOWNCASE is true, then the `fqdn` fact will be downcased when computing the value
  so that the result is not sensitive to the case of the `fqdn` fact.

  This function is usually used for spacing out runs of resource-intensive cron
  tasks that run on many nodes, which could cause a thundering herd or degrade
  other services if they all fire at once. Adding a SEED can be useful when you
  have more than one such task and need several unrelated random numbers per
  node. (For example, `fqdn_rand(30)`, `fqdn_rand(30, 'expensive job 1')`, and
  `fqdn_rand(30, 'expensive job 2')` will produce totally different numbers.)") do |args|
  max = args.shift.to_i
  initial_seed = args.shift
  downcase = !!args.shift

  fqdn = self['facts'].dig('networking', 'fqdn')
  fqdn = fqdn.downcase if downcase

  # Puppet 5.4's fqdn_rand function produces a different value than earlier versions
  # for the same set of inputs.
  # This causes problems because the values are often written into service configuration files.
  # When they change, services get notified and restart.

  # Restoring previous fqdn_rand behavior of calculating its seed value using MD5
  # when running on a non-FIPS enabled platform and only using SHA256 on FIPS enabled
  # platforms.
  if Puppet::Util::Platform.fips_enabled?
    seed = Digest::SHA256.hexdigest([fqdn, max, initial_seed].join(':')).hex
  else
    seed = Digest::MD5.hexdigest([fqdn, max, initial_seed].join(':')).hex
  end

  Puppet::Util.deterministic_rand_int(seed, max)
end
