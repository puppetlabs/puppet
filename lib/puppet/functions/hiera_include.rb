require 'hiera/puppet_function'

# @see lib/puppet/parser/functions/hiera_include.rb for documentation
# TODO: Move docs here when the format has been determined.
#
Puppet::Functions.create_function(:hiera_include, Hiera::PuppetFunction) do
  init_dispatch

  def merge_type
    :array
  end

  def post_lookup(key, value)
    raise Puppet::ParseError, "Could not find data item #{key}" if value.nil?
    call_function('include', value) unless value.empty?
  end
end
