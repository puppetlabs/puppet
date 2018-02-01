module Puppet::Pops::Types
module Iterable

class TreeIterator
  include Iterable

  DEFAULT_CONTAINERS = TypeFactory.variant(
    PArrayType::DEFAULT,
    PHashType::DEFAULT,
    PObjectType::DEFAULT
    )

  # Creates a TreeIterator that by default treats all Array, Hash and Object instances as
  # containers - the 'containers' option can be set to a type that denotes which types of values
  # should be treated as containers - a `Variant[Array, Hash]` would for instance not treat
  # Object values as containers, whereas just `Object` would only treat objects as containers.
  #
  # Unrecognized options are silently ignored
  #
  # @param [Hash] options the options
  # @option options [PTypeType] :container_type ('Variant[Hash, Array, Object]') The type(s) that should be treated as containers. The
  #   given type(s) must be assignable to the default container_type.
  # @option options [Boolean] :include_root ('true') If the root container itself should be included in the iteration (requires
  #   `include_containers` to also be `true` to take effect).
  # @option options [Boolean] :include_containers ('true') If containers should be included in the iteration
  # @option options [Boolean] :include_values ('true') If non containers (values) should be included in the iteration
  # @option options [Boolean] :include_refs ('false') If (non containment) referenced values in Objects should be included 
  #
  def initialize(enum, options=EMPTY_HASH)
    @root = enum
    @element_t = nil
    @value_stack = [enum]
    @indexer_stack = []
    @current_path = []
    @recursed = false
    @containers_t = options['container_type'] || DEFAULT_CONTAINERS
    unless DEFAULT_CONTAINERS.assignable?(@containers_t)
      raise ArgumentError, _("Only Array, Hash, and Object types can be used as container types. Got %{type}") % {type: @containers_t}
    end
    @with_root       = extract_option(options, 'include_root', true)
    @with_containers = extract_option(options, 'include_containers', true)
    @with_values     = extract_option(options, 'include_values', true)
    @with_root       = @with_containers && extract_option(options, 'include_root', true)
    unless @with_containers || @with_values
      raise ArgumentError, _("Options 'include_containers' and 'include_values' cannot both be false")
    end
    @include_refs = !!options['include_refs']
  end

  # Yields each `path, value` if the block arity is 2, and only `value` if arity is 1
  #
  def each(&block)
    loop do
      if block.arity == 1
        yield(self.next)
      else
        yield(*self.next)
      end
    end
  end

  def size
    raise "Not yet implemented - computes size lazily"
  end

  def unbounded?
    false
  end

  def to_a
    result = []
    loop do
      result << self.next
    end
    result
  end

  def to_array
    to_a
  end

  def reverse_each(&block)
    r = Iterator.new(PAnyType::DEFAULT, to_array.reverse_each)
    block_given? ? r.each(&block) : r
  end

  def step(step, &block)
    r = StepIterator.new(PAnyType::DEFAULT, self, step)
    block_given? ? r.each(&block) : r
  end

  def indexer_on(val)
    return nil unless @containers_t.instance?(val)
    if val.is_a?(Array)
      val.size.times
    elsif val.is_a?(Hash)
      val.each_key
    else
      if @include_refs
        val._pcore_type.attributes.each_key
      else
        val._pcore_type.attributes.reject {|k,v| v.kind == PObjectType::ATTRIBUTE_KIND_REFERENCE }.each_key
      end
    end
  end
  private :indexer_on

  def has_next?(iterator)
    begin
      iterator.peek
      true
    rescue StopIteration
      false
    end
  end
  private :has_next?

  def extract_option(options, key, default)
    v = options[key]
    v.nil? ? default : !!v
  end
  private :extract_option
end

class DepthFirstTreeIterator < TreeIterator

  # Creates a DepthFirstTreeIterator that by default treats all Array, Hash and Object instances as
  # containers - the 'containers' option can be set to a type that denotes which types of values
  # should be treated as containers - a `Variant[Array, Hash]` would for instance not treat
  # Object values as containers, whereas just `Object` would only treat objects as containers.
  #
  # @param [Hash] options the options
  # @option options [PTypeType] :containers ('Variant[Hash, Array, Object]') The type(s) that should be treated as containers
  # @option options [Boolean] :with_root ('true') If the root container itself should be included in the iteration
  #
  def initialize(enum, options = EMPTY_HASH)
    super
  end

  def next
    loop do
      break if @value_stack.empty?

      # first call
      if @indexer_stack.empty?
        @indexer_stack << indexer_on(@root)
        @recursed = true
        return [[], @root] if @with_root
      end

      begin
        if @recursed
          @current_path << nil
          @recursed = false
        end
        idx = @indexer_stack[-1].next
        @current_path[-1] = idx
        v = @value_stack[-1]
        value = v.is_a?(PuppetObject) ? v.send(idx) : v[idx]
        indexer = indexer_on(value)
        if indexer
          # recurse
          @recursed = true
          @value_stack << value
          @indexer_stack << indexer
          redo unless @with_containers
        else
          redo unless @with_values
        end
        return [@current_path.dup, value]

      rescue StopIteration
        # end of current value's range of content
        # pop all until out of next values
        at_the_very_end = false
        loop do
          pop_level
          at_the_very_end = @indexer_stack.empty?
          break if at_the_very_end || has_next?(@indexer_stack[-1])
        end
      end
    end
    raise StopIteration
  end

  def pop_level
    @value_stack.pop
    @indexer_stack.pop
    @current_path.pop
  end
  private :pop_level
end

class BreadthFirstTreeIterator < TreeIterator
  def initialize(enum, options = EMPTY_HASH)
    @path_stack = []
    super
  end

  def next
    loop do
      break if @value_stack.empty?

      # first call
      if @indexer_stack.empty?
        @indexer_stack << indexer_on(@root)
        @recursed = true
        return [[], @root] if @with_root
      end

      begin
        if @recursed
          @current_path << nil
          @recursed = false
        end

        idx = @indexer_stack[0].next
        @current_path[-1] = idx
        v = @value_stack[0]
        value = v.is_a?(PuppetObject) ? v.send(idx) : v[idx]
        indexer = indexer_on(value)
        if indexer
          @value_stack << value
          @indexer_stack << indexer
          @path_stack << @current_path.dup
          next unless @with_containers
        end
        return [@current_path.dup, value]

      rescue StopIteration
        # end of current value's range of content
        # shift all until out of next values
        at_the_very_end = false
        loop do
          shift_level
          at_the_very_end = @indexer_stack.empty?
          break if at_the_very_end || has_next?(@indexer_stack[0])
        end
      end
    end
    raise StopIteration
  end

  def shift_level
    @value_stack.shift
    @indexer_stack.shift
    @current_path = @path_stack.shift
    @recursed = true
  end
  private :shift_level

end
end
end
