# Manage indirections to termini.  They are organized in terms of indirections -
# - e.g., configuration, node, file, certificate -- and each indirection has one
# or more terminus types defined.  The indirection is configured via the
# +indirects+ method, which will be called by the class extending itself
# with this module.
module Puppet::Indirector
  # LAK:FIXME We need to figure out how to handle documentation for the
  # different indirection types.

  require 'puppet/indirector/indirection'
  require 'puppet/indirector/terminus'
  require 'puppet/indirector/code'
  require 'puppet/indirector/envelope'
  require 'puppet/network/format_support'

  def self.configure_routes(application_routes)
    application_routes.each do |indirection_name, termini|
      indirection_name = indirection_name.to_sym
      terminus_name = termini["terminus"]
      cache_name    = termini["cache"]

      Puppet::Indirector::Terminus.terminus_class(indirection_name, terminus_name || cache_name)

      indirection = Puppet::Indirector::Indirection.instance(indirection_name)
      raise _("Indirection %{indirection_name} does not exist") % { indirection_name: indirection_name } unless indirection

      indirection.terminus_class = terminus_name if terminus_name
      indirection.cache_class = cache_name if cache_name
    end
  end

  # Declare that the including class indirects its methods to
  # this terminus.  The terminus name must be the name of a Puppet
  # default, not the value -- if it's the value, then it gets
  # evaluated at parse time, which is before the user has had a chance
  # to override it.
  def indirects(indirection, options = {})
    raise(ArgumentError, _("Already handling indirection for %{current}; cannot also handle %{next}") % { current: @indirection.name, next: indirection }) if @indirection
    # populate this class with the various new methods
    extend ClassMethods
    include Puppet::Indirector::Envelope
    include Puppet::Network::FormatSupport

    # record the indirected class name for documentation purposes
    options[:indirected_class] = name

    # instantiate the actual Terminus for that type and this name (:ldap, w/ args :node)
    # & hook the instantiated Terminus into this class (Node: @indirection = terminus)
    @indirection = Puppet::Indirector::Indirection.new(self, indirection, options)
  end

  module ClassMethods
    attr_reader :indirection
  end

  # Helper definition for indirections that handle filenames.
  BadNameRegexp = Regexp.union(/^\.\./,
                               %r{[\\/]},
                               "\0",
                               /(?i)^[a-z]:/)
end
