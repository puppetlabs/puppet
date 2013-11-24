# A Visitor performs delegation to a given receiver based on the configuration of the Visitor.
# A new visitor is created with a given receiver, a method prefix, min, and max argument counts.
# e.g.
#   vistor = Visitor.new(self, "visit_from", 1, 1)
# will make the visitor call "self.visit_from_CLASS(x)" where CLASS is resolved to the given
# objects class, or one of is ancestors, the first class for which there is an implementation of
# a method will be selected.
#
# Raises RuntimeError if there are too few or too many arguments, or if the receiver is not
# configured to handle a given visiting object.
#
class Puppet::Pops::Visitor
  attr_reader :receiver, :message, :min_args, :max_args, :cache
  def initialize(receiver, message, min_args=0, max_args=nil)
    raise ArgumentError.new("min_args must be >= 0") if min_args < 0
    raise ArgumentError.new("max_args must be >= min_args or nil") if max_args && max_args < min_args

    @receiver = receiver
    @message = message
    @min_args = min_args
    @max_args = max_args
    @cache = Hash.new
  end

  # Visit the configured receiver
  def visit(thing, *args)
    visit_this(@receiver, thing, *args)
  end

  # Visit an explicit receiver
  def visit_this(receiver, thing, *args)
    raise "Visitor Error: Too few arguments passed. min = #{@min_args}" unless args.length >= @min_args
    if @max_args
      raise "Visitor Error: Too many arguments passed. max = #{@max_args}" unless args.length <= @max_args
    end
    if method_name = @cache[thing.class]
      return receiver.send(method_name, thing, *args)
    else
      thing.class.ancestors().each do |ancestor|
        method_name = :"#{@message}_#{ancestor.name.split(/::/).last}"
        next unless receiver.respond_to?(method_name, true)
        @cache[thing.class] = method_name
        return receiver.send(method_name, thing, *args)
      end
    end
    raise "Visitor Error: the configured receiver (#{receiver.class}) can't handle instance of: #{thing.class}"
  end

  # Visit an explicit receiver with 0 args
  # (This is ~30% faster than calling the general method)
  #
  def visit_this_0(receiver, thing)
    if method_name = @cache[thing.class]
      return receiver.send(method_name, thing)
    end
    visit_this(receiver, thing)
  end

  # Visit an explicit receiver with 1 args
  # (This is ~30% faster than calling the general method)
  #
  def visit_this_1(receiver, thing, arg)
    if method_name = @cache[thing.class]
      return receiver.send(method_name, thing, arg)
    end
    visit_this(receiver, thing, arg)
  end

  # Visit an explicit receiver with 2 args
  # (This is ~30% faster than calling th general method)
  #
  def visit_this_2(receiver, thing, arg1, arg2)
    if method_name = @cache[thing.class]
      return receiver.send(method_name, thing, arg1, arg2)
    end
    visit_this(receiver, thing, arg1, arg2)
  end

  # Visit an explicit receiver with 3 args
  # (This is ~30% faster than calling the general method)
  #
  def visit_this_3(receiver, thing, arg1, arg2, arg3)
    if method_name = @cache[thing.class]
      return receiver.send(method_name, thing, arg1, arg2, arg3)
    end
    visit_this(receiver, thing, arg1, arg2, arg3)
  end

  # This is an alternative implementation that separates the finding of method names
  # (Cached in the Visitor2 class), and bound methods (in an inner Delegator class) that
  # are cached for this receiver instance. This is based on micro benchmarks measuring that a send is slower
  # that directly calling a bound method.
  # Larger benchmark however show that the overhead is fractional. Additional (larger) tests may 
  # show otherwise.
  # To use this class instead of the regular Visitor.
  #   @@the_visitor_c = Visitor2.new(...)
  #   @@the_visitor = @@the_visitor_c.instance(self)
  #   then visit with one of the Delegator's visit methods.
  #
  # Performance Note: there are still issues with this implementation (although cleaner) since it requires
  # holding on to the first instance in order to compute respond_do?. This is required if the class
  # is using method_missing? which cannot be computed by introspection of the class (which would be
  # ideal). Another approach is to pre-scan all the available methods starting with the pattern for
  # the visitor, scan the class, and just check if the class has this method. (This will not work
  # for dispatch to methods that requires method missing. (Maybe that does not matter)
  # Further experiments could try looking up unbound methods via the class, cloning and binding them
  # instead of again looking them up with #method(name)
  # Also note that this implementation does not check min/max args on each call - there was not much gain
  # from skipping this. It is safe to skip, but produces less friendly errors if there is an error in the
  # implementation.
  #
  class Visitor2
    attr_reader :receiver, :message, :min_args, :max_args, :cache

    def initialize(receiver, message, min_args=0, max_args=nil)
      raise ArgumentError.new("receiver can not be nil") if receiver.nil?
      raise ArgumentError.new("min_args must be >= 0") if min_args < 0
      raise ArgumentError.new("max_args must be >= min_args or nil") if max_args && max_args < min_args

      @receiver = receiver
      @message = message
      @min_args = min_args
      @max_args = max_args
      @cache = Hash.new
    end

    def instance(receiver)
      # Create a visitable instance for the receiver
      Delegator.new(receiver, self)
    end

    # Produce the name of the method to use
    # @return [Symbol, nil] the method name symbol, or nil if there is no method to call for thing
    #
    def method_name_for(thing)
      if method_name = @cache[thing.class]
        return method_name
      else
        thing.class.ancestors().each do |ancestor|
          method_name = :"#{@message}_#{ancestor.name.split(/::/).last}"
          next unless receiver.respond_to?(method_name, true)
          @cache[thing.class] = method_name
          return method_name
        end
      end
    end

    class Delegator
      attr_reader :receiver, :visitor, :cache
      def initialize(receiver, visitor)
        @receiver = receiver
        @visitor = visitor
        @cache = Hash.new
      end

      # Visit
      def visit(thing, *args)
        if method = @cache[thing.class]
          return method.call(thing, *args)
        else
          method_name = visitor.method_name_for(thing)
          method = receiver.method(method_name)
          unless method
            raise "Visitor Error: the configured receiver (#{receiver.class}) can't handle instance of: #{thing.class}"
          end
          @cache[thing.class] = method
          method.call(thing, *args)
        end
      end

      # Visit an explicit receiver with 0 args
      # (This is ~30% faster than calling the general method)
      #
      def visit_0(thing)
        (method = @cache[thing.class]) ? method.call(thing) : visit(thing)
      end

      def visit_1(thing, arg)
        (method = @cache[thing.class]) ? method.call(thing, arg) : visit(thing, arg)
      end

      def visit_2(thing, arg1, arg2)
        (method = @cache[thing.class]) ? method.call(thing, arg1, arg2) : visit(thing, arg1, arg2)
      end

      def visit_3(thing, arg1, arg2, arg3)
        (method = @cache[thing.class]) ? method.call(thing, arg1, arg2, arg3) : visit(thing, arg1, arg2, arg3)
      end

    end
  end
end
