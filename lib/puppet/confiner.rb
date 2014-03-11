require 'puppet/confine_collection'

# The Confiner module contains methods for managing a Provider's confinement (suitability under given
# conditions). The intent is to include this module in an object where confinement management is wanted.
# It lazily adds an instance variable `@confine_collection` to the object where it is included.
#
module Puppet::Confiner
  # Confines a provider to be suitable only under the given conditions.
  # The hash describes a confine using mapping from symbols to values or predicate code.
  #
  # * _fact_name_ => value of fact (or array of facts)
  # * `:exists` => the path to an existing file
  # * `:true` => a predicate code block returning true
  # * `:false` => a predicate code block returning false
  # * `:feature` => name of system feature that must be present
  # * `:any` => an array of expressions that will be ORed together
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

  # @return [Puppet::ConfineCollection] the collection of confines
  # @api private
  #
  def confine_collection
    @confine_collection ||= Puppet::ConfineCollection.new(self.to_s)
  end

  # Checks whether this implementation is suitable for the current platform (or returns a summary
  # of all confines if short == false).
  # @return [Boolean. Hash] Returns whether the confines are all valid (if short == true), or a hash of all confines
  #   if short == false.
  # @api public
  #
  def suitable?(short = true)
    return(short ? confine_collection.valid? : confine_collection.summary)
  end
end
