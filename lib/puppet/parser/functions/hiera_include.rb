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

  The function can be called in one of three ways:
  1. Using 1 to 3 arguments where the arguments are:
     'key'      [String] Required
           The key to lookup.
     'default`  [Any] Optional
           A value to return when there's no match for `key`. Optional
     `override` [Any] Optional
           An argument in the third position, providing a data source
           to consult for matching values, even if it would not ordinarily be
           part of the matched hierarchy. If Hiera doesn't find a matching key
           in the named override data source, it will continue to search through the
           rest of the hierarchy.

  2. Using a 'key' and an optional 'override' parameter like in #1 but with a block to
     provide the default value. The block is called with one parameter (the key) and
     should return the array to be used in the subsequent call to include.
     This option can only be used with the 3x future parser or
     from 4.0.0.

  3. Like #1 but with all arguments passed in an array.

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

