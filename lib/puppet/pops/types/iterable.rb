module Puppet::Pops::Types
  # The runtime Iterable type for an Iterable
  module Iterable
    # Produces an `Iterable` for one of the following types with the following characterstics:
    #
    # `String`       - yields each character in the string
    # `Array`        - yields each element in the array
    # `Hash`         - yields each key/value pair as a two element array
    # `Integer`      - when positive, yields each value from zero to the given number
    # `PIntegerType` - yields each element from min to max (inclusive) provided min < max and neither is unbounded.
    # `PEnumtype`    - yields each possible value of the enum.
    # `Range`        - yields an iterator for all elements in the range provided that the range start and end
    #                  are both integers or both strings and start is less than end using natural ordering.
    # `Dir`          - yields each name in the directory
    #
    # An `ArgumentError` is raised for all other objects.
    #
    # @param o [Object] The object to produce an `Iterable` for
    # @return [Iterable,nil] The produced `Iterable`
    # @raise [ArgumentError] In case an `Iterable` cannot be produced
    # @api public
    def self.asserted_iterable(caller, obj)
      iter = self.on(obj)
      raise ArgumentError, "#{caller.class}(): wrong argument type (#{obj.class}; is not Iterable." if iter.nil?
      iter
    end

    # Produces an `Iterable` for one of the following types with the following characterstics:
    #
    # `String`       - yields each character in the string
    # `Array`        - yields each element in the array
    # `Hash`         - yields each key/value pair as a two element array
    # `Integer`      - when positive, yields each value from zero to the given number
    # `PIntegerType` - yields each element from min to max (inclusive) provided min < max and neither is unbounded.
    # `PEnumtype`    - yields each possible value of the enum.
    # `Range`        - yields an iterator for all elements in the range provided that the range start and end
    #                  are both integers or both strings and start is less than end using natural ordering.
    # `Dir`          - yields each name in the directory
    #
    # The value `nil` is returned for all other objects.
    #
    # @param o [Object] The object to produce an `Iterable` for
    # @return [Iterable,nil] The produced `Iterable` or `nil` if it couldn't be produced
    #
    # @api public
    def self.on(o)
      case o
      when Iterable
        o
      when String
        Iterator.new(PStringType.new(PIntegerType.new(1, 1)), o.each_char)
      when Array
        if o.empty?
          Iterator.new(PUnitType::DEFAULT, o.each)
        else
          tc = TypeCalculator.singleton
          Iterator.new(PVariantType.maybe_create(o.map {|e| tc.infer_set(e) }), o.each)
        end
      when Hash
        # Each element is a two element [key, value] tuple.
        if o.empty?
          Iterator.new(PHashType::DEFAULT_KEY_PAIR_TUPLE, o.each)
        else
          tc = TypeCalculator.singleton
          Iterator.new(PTupleType.new([
            PVariantType.maybe_create(o.keys.map {|e| tc.infer_set(e) }),
            PVariantType.maybe_create(o.values.map {|e| tc.infer_set(e) })], PHashType::KEY_PAIR_TUPLE_SIZE), o.each_pair)
        end
      when Integer
        if o == 0
          Iterator.new(PUnitType::DEFAULT, o.times)
        elsif o > 0
          IntegerRangeIterator.new(PIntegerType.new(0, o - 1))
        else
          nil
        end
      when PIntegerType
        # a finite range will always produce at least one element since it's inclusive
        o.finite_range? ? IntegerRangeIterator.new(o) : nil
      when PEnumType
        Iterator.new(o, o.values.each)
      when Range
        min = o.min
        max = o.max
        if min.is_a?(Integer) && max.is_a?(Integer) && max >= min
          IntegerRangeIterator.new(PIntegerType.new(min, max))
        elsif min.is_a?(String) && max.is_a?(String) && max >= min
          # A generalized element type where only the size is inferred is used here since inferring the full
          # range might waste a lot of memory.
          if min.length < max.length
            shortest = min
            longest = max
          else
            shortest = max
            longest = min
          end
          Iterator.new(PStringType.new(PIntegerType.new(shortest.length, longest.length)), o.each)
        else
          # Unsupported range. It's either descending or nonsensical for other reasons (float, mixed types, etc.)
          nil
        end
      else
        # Not supported. We cannot determine the element type
        nil
      end
    end

    # Answers the question if there is an end to the iteration. Puppet does not currently provide any unbounded
    # iterables.
    #
    # @return [Boolean] `true` if the iteration is unbounded
    def self.unbounded?(object)
      case object
      when Iterable
        object.unbounded?
      when String,Integer,Array,Hash,Enumerator,PIntegerType,PEnumType,Dir
        false
      else
        TypeAsserter.assert_instance_of('', PIterableType::DEFAULT, object, false)
        !object.respond_to?(:size)
      end
    end

    def each(&block)
      step(1, &block)
    end

    def element_type
      PAnyType::DEFAULT
    end

    def reverse_each(&block)
      # Default implementation cannot propagate reverse_each to a new enumerator so chained
      # calls must put reverse_each last.
      raise ArgumentError 'Step is not implemented'
    end

    def step(step, &block)
      # Default implementation cannot propagate step to a new enumerator so chained
      # calls must put stepping last.
      raise ArgumentError 'Step is not implemented'
    end

    def to_a
      raise Puppet::Error, 'Attempt to create an Array from an unbounded Iterable' if unbounded?
      super
    end

    def unbounded?
      true
    end
  end

  # @api private
  class Iterator
    # Note! We do not include Enumerable module here since that would make this class respond
    # in a bad way to all enumerable methods. We want to delegate all those calls directly to
    # the contained @enumeration
    include Iterable

    def initialize(element_type, enumeration)
      @element_type = element_type
      @enumeration = enumeration
    end

    def element_type
      @element_type
    end

    def size
      @enumeration.size
    end

    def respond_to_missing?(name, include_private)
      @enumeration.respond_to?(name, include_private)
    end

    def method_missing(name, *arguments, &block)
      @enumeration.send(name, *arguments, &block)
    end

    def step(step, &block)
      raise ArgumentError if step <= 0
      r = self
      r = r.step_iterator(step) if step > 1

      if block_given?
        begin
        if block.arity == 1
          loop { yield(r.next) }
        else
          loop { yield(*r.next) }
        end
        rescue StopIteration
        end
        self
      else
        r
      end
    end

    def reverse_each(&block)
      r = Iterator.new(@element_type, @enumeration.reverse_each)
      block_given? ? r.each(&block) : r
    end

    def step_iterator(step)
      StepIterator.new(@element_type, self, step)
    end

    def to_s
      et = element_type
      et.nil? ? 'Iterator-Value' : "Iterator[#{et.generalize}]-Value"
    end

    def unbounded?
      Iterable.unbounded?(@enumeration)
    end
  end

  # @api private
  class StepIterator < Iterator
    include Enumerable

    def initialize(element_type, enumeration, step_size)
      super(element_type, enumeration)
      raise ArgumentError if step_size <= 0
      @step_size = step_size
    end

    def next
      result = @enumeration.next
      skip = @step_size - 1
      if skip > 0
        begin
          skip.times { @enumeration.next }
        rescue StopIteration
        end
      end
      result
    end

    def reverse_each(&block)
      r = Iterator.new(@element_type, to_a.reverse_each)
      block_given? ? r.each(&block) : r
    end

    def size
      super / @step_size
    end
  end

  # @api private
  class IntegerRangeIterator < Iterator
    include Enumerable

    def initialize(range, step = 1)
      raise ArgumentError if step == 0
      @range = range
      @step_size = step
      @current = (step < 0 ? range.to : range.from) - step
    end

    def element_type
      @range
    end

    def next
      value = @current + @step_size
      if @step_size < 0
        raise StopIteration if value < @range.from
      else
        raise StopIteration if value > @range.to
      end
      @current = value
    end

    def reverse_each(&block)
      r = IntegerRangeIterator.new(@range, -@step_size)
      block_given? ? r.each(&block) : r
    end

    def size
      (@range.to - @range.from) / @step_size.abs
    end

    def step_iterator(step)
      # The step iterator must use a range that has its logical end truncated at an even step boundary. This will
      # fulfil two objectives:
      # 1. The element_type method should not report excessive integers as possible numbers
      # 2. A reversed iterator must start at the correct number
      #
      range = @range
      step = @step_size * step
      mod = (range.to - range.from) % step
      if mod < 0
        range = PIntegerType.new(range.from - mod, range.to)
      elsif mod > 0
        range = PIntegerType.new(range.from, range.to - mod)
      end
      IntegerRangeIterator.new(range, step)
    end

    def unbounded?
      false
    end
  end
end
