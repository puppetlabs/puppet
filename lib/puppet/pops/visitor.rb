module Puppet::Pops
# A Visitor performs delegation to a given receiver based on the configuration of the Visitor.
# A new visitor is created with a given receiver, a method prefix, min, and max argument counts.
# e.g.
#   visitor = Visitor.new(self, "visit_from", 1, 1)
# will make the visitor call "self.visit_from_CLASS(x)" where CLASS is resolved to the given
# objects class, or one of is ancestors, the first class for which there is an implementation of
# a method will be selected.
#
# Raises RuntimeError if there are too few or too many arguments, or if the receiver is not
# configured to handle a given visiting object.
#
class Visitor
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
    visit_this(@receiver, thing, args)
  end

  NO_ARGS = EMPTY_ARRAY

  # Visit an explicit receiver
  def visit_this(receiver, thing, args)
    raise "Visitor Error: Too few arguments passed. min = #{@min_args}" unless args.length >= @min_args
    if @max_args
      raise "Visitor Error: Too many arguments passed. max = #{@max_args}" unless args.length <= @max_args
    end
    if method_name = @cache[thing.class]
      return receiver.send(method_name, thing, *args)
    else
      thing.class.ancestors().each do |ancestor|
        name = ancestor.name
        next if name.nil?
        method_name = :"#{@message}_#{name.split(DOUBLE_COLON).last}"
        next unless receiver.respond_to?(method_name, true)
        @cache[thing.class] = method_name
        return receiver.send(method_name, thing, *args)
      end
    end
    raise "Visitor Error: the configured receiver (#{receiver.class}) can't handle instance of: #{thing.class}"
  end

  # Visit an explicit receiver
  def visit_this_class(receiver, clazz, args)
    raise "Visitor Error: Too few arguments passed. min = #{@min_args}" unless args.length >= @min_args
    if @max_args
      raise "Visitor Error: Too many arguments passed. max = #{@max_args}" unless args.length <= @max_args
    end
    if method_name = @cache[clazz]
      return receiver.send(method_name, clazz, *args)
    else
      clazz.ancestors().each do |ancestor|
        name = ancestor.name
        next if name.nil?
        method_name = :"#{@message}_#{name.split(DOUBLE_COLON).last}"
        next unless receiver.respond_to?(method_name, true)
        @cache[clazz] = method_name
        return receiver.send(method_name, clazz, *args)
      end
    end
    raise "Visitor Error: the configured receiver (#{receiver.class}) can't handle instance of: #{clazz}"
  end

  # Visit an explicit receiver with 0 args
  # (This is ~30% faster than calling the general method)
  #
  def visit_this_0(receiver, thing)
    if method_name = @cache[thing.class]
      return receiver.send(method_name, thing)
    end
    visit_this(receiver, thing, NO_ARGS)
  end

  # Visit an explicit receiver with 1 args
  # (This is ~30% faster than calling the general method)
  #
  def visit_this_1(receiver, thing, arg)
    if method_name = @cache[thing.class]
      return receiver.send(method_name, thing, arg)
    end
    visit_this(receiver, thing, [arg])
  end

  # Visit an explicit receiver with 2 args
  # (This is ~30% faster than calling the general method)
  #
  def visit_this_2(receiver, thing, arg1, arg2)
    if method_name = @cache[thing.class]
      return receiver.send(method_name, thing, arg1, arg2)
    end
    visit_this(receiver, thing, [arg1, arg2])
  end

  # Visit an explicit receiver with 3 args
  # (This is ~30% faster than calling the general method)
  #
  def visit_this_3(receiver, thing, arg1, arg2, arg3)
    if method_name = @cache[thing.class]
      return receiver.send(method_name, thing, arg1, arg2, arg3)
    end
    visit_this(receiver, thing, [arg1, arg2, arg3])
  end

end
end
