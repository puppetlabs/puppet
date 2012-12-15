require 'puppet/provider/confine_collection'

module Puppet::Provider::Confiner
  # Confines a provider to be suitable only under the given conditions.
  # The hash describes a confine using mapping from symbols to values or predicate code.
  #
  # * _fact_name_ => value of fact
  # * `:exists` => the path to an existing file
  # * `:true` => a predicate code block returning true
  # * `:false` => a predicate code block returning false
  # * `:feature` => name of system feature that must be present
  #
  # @example
  #   confine :operatingsystem => [:redhat, :fedora]
  #   confine :true { ... }
  #
  # @param hash [Hash<{Symbol => Object}>] hash of confines
  # @return [void]
  # @api public
  #
  def confine(hash)
    confine_collection.confine(hash)
  end

  # @return [Puppet::Provider::ConfineCollection] the collection of confines
  # @api private
  def confine_collection
    @confine_collection ||= Puppet::Provider::ConfineCollection.new(self.to_s)
  end

  # Checks whether this implementation is suitable for the current platform (or returns a summary
  # of all confines if short == false).
  # @return [Boolean. Hash] Returns whether the confines are all valid (if short = true), or a hash of all confines
  #   if short == false. 
  # @api public
  #
  def suitable?(short = true)
    return(short ? confine_collection.valid? : confine_collection.summary)
  end
end
