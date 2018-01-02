module Puppet::Pops
module Types

# @api public
class PInitType < PTypeWithContainedType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType',
      'type' => {
        KEY_TYPE => POptionalType.new(PTypeType::DEFAULT),
        KEY_VALUE => nil
      },
      'init_args' => {
        KEY_TYPE => PArrayType::DEFAULT,
        KEY_VALUE => EMPTY_ARRAY
      }
    )
  end

  attr_reader :init_args

  def initialize(type, init_args)
    super(type)
    @init_args = init_args.nil? ? EMPTY_ARRAY : init_args

    if type.nil?
      raise ArgumentError, _('Init cannot be parameterized with an undefined type and additional arguments') unless @init_args.empty?
      @initialized = true
    else
      @initialized = false
    end
  end

  def instance?(o, guard = nil)
    really_instance?(o, guard) == 1
  end

  # @api private
  def really_instance?(o, guard = nil)
    if @type.nil?
      TypeFactory.rich_data.really_instance?(o)
    else
      assert_initialized
      guarded_recursion(guard, 0) do |g|
        v = @type.really_instance?(o, g)
        if v < 1
          if @single_type
            s = @single_type.really_instance?(o, g)
            v = s if s > v
          end
        end
        if v < 1
          if @other_type
            s = @other_type.really_instance?(o, g)
            s = @other_type.really_instance?([o], g) if s < 0 && @has_optional_single
            v = s if s > v
          end
        end
        v
      end
    end
  end

  def eql?(o)
    super && @init_args == o.init_args
  end

  def hash
    super ^ @init_args.hash
  end

  def new_function
    return super if type.nil?
    assert_initialized

    target_type = type
    single_type = @single_type
    if @init_args.empty?
      @new_function ||= Puppet::Functions.create_function(:new_Init, Puppet::Functions::InternalFunction) do
        @target_type = target_type
        @single_type = single_type

        dispatch :from_array do
          scope_param
          param 'Array', :value
        end

        dispatch :create do
          scope_param
          param 'Any', :value
        end

        def self.create(scope, value, func)
          func.call(scope, @target_type, value)
        end

        def self.from_array(scope, value, func)
          # If there is a single argument that matches the array, then that gets priority over
          # expanding the array into all arguments
          if @single_type.instance?(value) || (@other_type && !@other_type.instance?(value) && @has_optional_single && @other_type.instance?([value]))
            func.call(scope, @target_type, value)
          else
            func.call(scope, @target_type, *value)
          end
        end

        def from_array(scope, value)
          self.class.from_array(scope, value, loader.load(:function, 'new'))
        end

        def create(scope, value)
          self.class.create(scope, value, loader.load(:function, 'new'))
        end
      end
    else
      init_args = @init_args
      @new_function ||= Puppet::Functions.create_function(:new_Init, Puppet::Functions::InternalFunction) do
        @target_type = target_type
        @init_args = init_args

        dispatch :create do
          scope_param
          param 'Any', :value
        end

        def self.create(scope, value, func)
          func.call(scope, @target_type, value, *@init_args)
        end

        def create(scope, value)
          self.class.create(scope, value, loader.load(:function, 'new'))
        end
      end
    end
  end

  DEFAULT = PInitType.new(nil, EMPTY_ARRAY)

  EXACTLY_ONE = [1, 1].freeze

  def assert_initialized
    return self if @initialized

    @initialized = true
    @self_recursion = true

    begin
      # Filter out types that will provide a new_function but are unsuitable to be contained in Init
      #
      # Calling Init#new would cause endless recursion
      # The Optional is the same as Variant[T,Undef].
      # The NotUndef is not meaningful to create instances of
      if @type.instance_of?(PInitType) || @type.instance_of?(POptionalType) || @type.instance_of?(PNotUndefType)
        raise ArgumentError.new
      end
      new_func = @type.new_function
    rescue ArgumentError
      raise ArgumentError, _("Creation of new instance of type '%{type_name}' is not supported") % { type_name: @type.to_s }
    end
    param_tuples = new_func.dispatcher.signatures.map { |closure| closure.type.param_types }

    # An instance of the contained type is always a match to this type.
    single_types = [@type]

    if @init_args.empty?
      # A value that is assignable to the type of a single parameter is also a match
      single_tuples, other_tuples = param_tuples.partition { |tuple| EXACTLY_ONE == tuple.size_range }
      single_types.concat(single_tuples.map { |tuple| tuple.types[0] })
    else
      tc = TypeCalculator.singleton
      init_arg_types = @init_args.map { |arg| tc.infer_set(arg) }
      arg_count = 1 + init_arg_types.size

      # disqualify all parameter tuples that doesn't allow one value (type unknown at ths stage) + init args.
      param_tuples = param_tuples.select do |tuple|
        min, max = tuple.size_range
        if arg_count >= min && arg_count <= max
          # Aside from the first parameter, does the other parameters match?
          tuple.assignable?(PTupleType.new(tuple.types[0..0].concat(init_arg_types)))
        else
          false
        end
      end
      if param_tuples.empty?
        raise ArgumentError, _("The type '%{type}' does not represent a valid set of parameters for %{subject}.new()") %
          { type: to_s, subject: @type.generalize.name }
      end
      single_types.concat(param_tuples.map { |tuple| tuple.types[0] })
      other_tuples = EMPTY_ARRAY
    end
    @single_type = PVariantType.maybe_create(single_types)
    unless other_tuples.empty?
      @other_type = PVariantType.maybe_create(other_tuples)
      @has_optional_single = other_tuples.any? { |tuple| tuple.size_range.min == 1 }
    end

    guard = RecursionGuard.new
    accept(NoopTypeAcceptor::INSTANCE, guard)
    @self_recursion = guard.recursive_this?(self)
  end

  def accept(visitor, guard)
    guarded_recursion(guard, nil) do |g|
      super(visitor, g)
      @single_type.accept(visitor, guard) if @single_type
      @other_type.accept(visitor, guard) if @other_type
    end
  end

  protected

  def _assignable?(o, guard)
    guarded_recursion(guard, false) do |g|
      assert_initialized
      if o.is_a?(PInitType)
        @type.nil? || @type.assignable?(o.type, g)
      elsif @type.nil?
        TypeFactory.rich_data.assignable?(o, g)
      else
        @type.assignable?(o, g) ||
          @single_type && @single_type.assignable?(o, g) ||
          @other_type && (@other_type.assignable?(o, g) || @has_optional_single && @other_type.assignable?(PTupleType.new([o])))
      end
    end
  end

  private

  def guarded_recursion(guard, dflt)
    if @self_recursion
      guard ||= RecursionGuard.new
      guard.with_this(self) { |state| (state & RecursionGuard::SELF_RECURSION_IN_THIS) == 0 ? yield(guard) : dflt }
    else
      yield(guard)
    end
  end
end
end
end
