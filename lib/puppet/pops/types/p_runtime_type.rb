module Puppet::Pops
module Types

# @api public
class PRuntimeType < PAnyType
  TYPE_NAME_OR_PATTERN = PVariantType.new([PStringType::NON_EMPTY, PTupleType.new([PRegexpType::DEFAULT, PStringType::NON_EMPTY])])

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType',
      'runtime' => {
        KEY_TYPE => POptionalType.new(PStringType::NON_EMPTY),
        KEY_VALUE => nil
      },
      'name_or_pattern' => {
        KEY_TYPE => POptionalType.new(TYPE_NAME_OR_PATTERN),
        KEY_VALUE => nil
      }
    )
  end

  attr_reader :runtime, :name_or_pattern

  # Creates a new instance of a Runtime type
  #
  # @param runtime [String] the name of the runtime, e.g. 'ruby'
  # @param name_or_pattern [String,Array(Regexp,String)] name of runtime or two patterns, mapping Puppet name => runtime name
  # @api public
  def initialize(runtime, name_or_pattern)
    unless runtime.nil? || runtime.is_a?(Symbol)
      runtime = TypeAsserter.assert_instance_of("Runtime 'runtime'", PStringType::NON_EMPTY, runtime).to_sym
    end
    @runtime = runtime
    @name_or_pattern = TypeAsserter.assert_instance_of("Runtime 'name_or_pattern'", TYPE_NAME_OR_PATTERN, name_or_pattern, true)
  end

  def hash
    @runtime.hash ^ @name_or_pattern.hash
  end

  def eql?(o)
    self.class == o.class && @runtime == o.runtime && @name_or_pattern == o.name_or_pattern
  end

  def instance?(o, guard = nil)
    assignable?(TypeCalculator.infer(o), guard)
  end

  def iterable?(guard = nil)
    if @runtime == :ruby && !runtime_type_name.nil?
      begin
        c = ClassLoader.provide(self)
        return c < Iterable unless c.nil?
      rescue ArgumentError
      end
    end
    false
  end

  def iterable_type(guard = nil)
    iterable?(guard) ? PIterableType.new(self) : nil
  end

  # @api private
  def runtime_type_name
    @name_or_pattern.is_a?(String) ? @name_or_pattern : nil
  end

  # @api private
  def class_or_module
    raise "Only ruby classes or modules can be produced by this runtime, got '#{runtime}" unless runtime == :ruby
    raise 'A pattern based Runtime type cannot produce a class or module' if @name_or_pattern.is_a?(Array)
    com = ClassLoader.provide(self)
    raise "The name #{@name_or_pattern} does not represent a ruby class or module" if com.nil?
    com
  end

  # @api private
  def from_puppet_name(puppet_name)
    if @name_or_pattern.is_a?(Array)
      substituted = puppet_name.sub(*@name_or_pattern)
      substituted == puppet_name ? nil : PRuntimeType.new(@runtime, substituted)
    else
      nil
    end
  end

  DEFAULT = PRuntimeType.new(nil, nil)
  RUBY = PRuntimeType.new(:ruby, nil)

  protected

  # Assignable if o's has the same runtime and the runtime name resolves to
  # a class that is the same or subclass of t1's resolved runtime type name
  # @api private
  def _assignable?(o, guard)
    return false unless o.is_a?(PRuntimeType)
    return false unless @runtime.nil? || @runtime == o.runtime
    return true if @name_or_pattern.nil? # t1 is wider

    onp = o.name_or_pattern
    return true if @name_or_pattern == onp
    return false unless @name_or_pattern.is_a?(String) && onp.is_a?(String)

    # NOTE: This only supports Ruby, must change when/if the set of runtimes is expanded
    begin
      c1 = ClassLoader.provide(self)
      c2 = ClassLoader.provide(o)
      c1.is_a?(Module) && c2.is_a?(Module) && !!(c2 <= c1)
    rescue ArgumentError
      false
    end
  end
end
end
end
