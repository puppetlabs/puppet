require 'hiera/puppet_function'

# @see lib/puppet/parser/functions/hiera.rb for documentation
# TODO: Move docs here when the format has been determined.
#
Puppet::Functions.create_function(:hiera, Hiera::PuppetFunction) do
  init_dispatch
end
