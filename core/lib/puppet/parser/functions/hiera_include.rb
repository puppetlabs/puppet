require 'hiera_puppet'

module Puppet::Parser::Functions
  newfunction(:hiera_include, :arity => -2, :doc => "Assigns classes to a node
  using an array merge lookup that retrieves the value for a user-specified key
  from a Hiera data source.

  To use `hiera_include`, the following configuration is required:

  - A key name to use for classes, e.g. `classes`.
  - A line in the puppet `sites.pp` file (e.g. `/etc/puppet/manifests/sites.pp`)
    reading `hiera_include('classes')`. Note that this line must be outside any node
    definition and below any top-scope variables in use for Hiera lookups.
  - Class keys in the appropriate data sources. In a data source keyed to a node's role,
    one might have:

            ---
            classes:
              - apache
              - apache::passenger

  In addition to the required `key` argument, `hiera_include` accepts two additional
  arguments:

  - a `default` argument in the second position, providing an array to be returned
    in the absence of matches to the `key` argument
  - an `override` argument in the third position, providing a data source to consult
    for matching values, even if it would not ordinarily be part of the matched hierarchy.
    If Hiera doesn't find a matching key in the named override data source, it will continue
    to search through the rest of the hierarchy.

  More thorough examples of `hiera_include` are available at:
  <http://docs.puppetlabs.com/hiera/1/puppet.html#hiera-lookup-functions>
  ") do |*args|
    key, default, override = HieraPuppet.parse_args(args)
    if answer = HieraPuppet.lookup(key, default, self, override, :array)
      method = Puppet::Parser::Functions.function(:include)
      send(method, [answer])
    else
      raise Puppet::ParseError, "Could not find data item #{key}"
    end
  end
end

