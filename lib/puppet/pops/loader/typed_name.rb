module Puppet::Pops
module Loader
# A namespace/name/type combination that can be used as a compound hash key
#
# @api public
class TypedName
  attr_reader :hash
  attr_reader :type
  attr_reader :name_authority
  attr_reader :name
  attr_reader :name_parts
  attr_reader :compound_name

  def initialize(type, name, name_authority = Pcore::RUNTIME_NAME_AUTHORITY)
    name = name.downcase
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
    @name_parts = parts.freeze

    # Use a frozen compound key for the hash and comparison. Most varying part first
    @compound_name = "#{@name}/#{@type}/#{@name_authority}".freeze
    @hash = @compound_name.hash
    freeze
  end

  def ==(o)
    o.class == self.class && o.compound_name == @compound_name
  end

  alias eql? ==

  # @return the parent of this instance, or nil if this instance is not qualified
  def parent
    @name_parts.size > 1 ? self.class.new(@type, @name_parts[0...-1].join(DOUBLE_COLON), @name_authority) : nil
  end

  def qualified?
    @name_parts.size > 1
  end

  def to_s
    "#{@name_authority}/#{@type}/#{@name}"
  end
end
end
end
