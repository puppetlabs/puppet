require 'hiera/puppet_function'

# @see lib/puppet/parser/functions/hiera_hash.rb for documentation
# TODO: Move docs here when the format has been determined.
#
Puppet::Functions.create_function(:hiera_hash, Hiera::PuppetFunction) do
  init_dispatch

  def merge_type
    :hash
  end
end
