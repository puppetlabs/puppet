# A name/type combination that can be used as a compound hash key
#
module Puppet::Pops
module Loader
class TypedName
  DOUBLE_COLON = '::'

  attr_reader :hash
  attr_reader :type
  attr_reader :name_authority
  attr_reader :name
  attr_reader :name_parts
  attr_reader :compound_name

  def initialize(type, name, name_authority = Pcore::RUNTIME_NAME_AUTHORITY)
    @type = type
    @name_authority = name_authority
    # relativize the name (get rid of leading ::), and make the split string available
    parts = name.to_s.split(DOUBLE_COLON)
    if parts[0].empty?
      parts.shift
      @name = name[2..-1]
    else
      @name = name
    end
    @name_parts = parts

    # Use a frozen compound key for the hash and comparison
    @compound_name = "#{name_authority}/#{type}/#{name}".freeze
    @hash = @compound_name.hash
    freeze
  end

  def ==(o)
    o.class == self.class && o.compound_name == @compound_name
  end

  alias eql? ==

  def qualified?
    @name_parts.size > 1
  end

  def to_s
    @compound_name
  end
end
end
end
