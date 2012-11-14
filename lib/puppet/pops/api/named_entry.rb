module Puppet; module Pops; module API
  # A NamedEntry describes the API for returned scope entries. A scope always returns frozen (immutable)
  # name entries.
  # NameEntries representing a variable has type set to :variable.
  # The #origin is optional, if set it should either be an intance of URI, or a Producer
  # (that produces instance of URI on call to #uri()).
  # The encoding of the URI is determined by the scheme; A user of the origin may
  # interpret the URL parameters line as line number, offset as total offset from file start, and
  # length as the number of characters, where missing entries (or -1) indicates unknown.
  # 
  # Raises ArgumentError if a given origin is not a URI or responds to #uri
  #
  class NamedEntry
  attr_reader :type, :name, :value, :origin
    
    def initialize (type, name, value, origin = nil)
      @type = type
      @name = name
      @value = value
      if origin && !(origin.is_a?(URI) || origin.respond_to(:uri))
        raise ArgumentError.new("A given origin must be a URI, or respond to #uri().")
      end
      @origin = origin
    end 
  end
end; end; end