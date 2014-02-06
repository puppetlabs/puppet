# The Enumeration class provides default Enumerable::Enumerator creation for Puppet Programming Language
# runtime objects that supports the concept of enumeration.
#
class Puppet::Pops::Types::Enumeration
  # Produces an Enumerable::Enumerator for Array, Hash, Integer, Integer Range, and String.
  #
  def self.enumerator(o)
    @@singleton ||= new
    @@singleton.enumerator(o)
  end

  # Produces an Enumerable::Enumerator for Array, Hash, Integer, Integer Range, and String.
  #
  def enumerator(o)
    case o
    when String
      o.chars
    when Integer
      o.times
    when Array
      o.each
    when Hash
      o.each
    when Puppet::Pops::Types::PIntegerType
      # Not enumerable if representing an infinite range
      return nil if o.to.nil? || o.from.nil?
      o.each
    else
      nil
    end
  end
end