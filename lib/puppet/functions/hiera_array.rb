require 'hiera/puppet_function'

# @see lib/puppet/parser/functions/hiera_array.rb for documentation
# TODO: Move docs here when the format has been determined.
#
Puppet::Functions.create_function(:hiera_array, Hiera::PuppetFunction) do
  init_dispatch

  def merge_type
    :array
  end
end