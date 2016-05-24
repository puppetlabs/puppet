module Puppet::Pops
module Types
class TypeSetReference
  include Annotatable

  attr_reader :name_authority
  attr_reader :name
  attr_reader :version_range
  attr_reader :type_set

  def initialize(owner, i12n_hash)
    @owner = owner
    @name_authority = (i12n_hash[KEY_NAME_AUTHORITY] || owner.name_authority).freeze
    @name = i12n_hash[KEY_NAME].freeze
    @version_range = PSemVerRangeType.convert(i12n_hash[KEY_VERSION_RANGE])
    init_annotatable(i12n_hash)
  end

  def accept(visitor, guard)
    annotatable_accept(visitor, guard)
  end

  def eql?(o)
    self.class == o.class && @name_authority.eql?(o.name_authority) && @name.eql?(o.name) && @version_range.eql?(o.version_range)
  end

  def hash
    [@name_authority, @name, @version_range].hash
  end

  def i12n_hash
    result = super
    result[KEY_NAME_AUTHORITY] = @name_authority unless @name_authority == @owner.name_authority
    result[KEY_NAME] = @name
    result[KEY_VERSION_RANGE] = @version_range.to_s
    result
  end

  def resolve(type_parser, loader)
    typed_name = Loader::TypedName.new(:type, @name.downcase, @name_authority)
    loaded_entry = loader.load_typed(typed_name)
    type_set = loaded_entry.nil? ? nil : loaded_entry.value

    raise ArgumentError, "#{self} cannot be resolved" if type_set.nil?
    raise ArgumentError, "#{self} resolves to a #{type_set.name}" unless type_set.is_a?(PTypeSetType)

    @type_set = type_set.resolve(type_parser, loader)
    unless @version_range.include?(@type_set.version)
      raise ArgumentError, "#{self} resolves to an incompatible version. Expected #{@version_range}, got #{type_set.version}"
    end
    nil
  end

  def to_s
    "#{@owner.label} reference to TypeSet named '#{@name}'"
  end
end
end
end
