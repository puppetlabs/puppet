# Complies with Proc API by mapping a Puppet::Pops::Evaluator::Closure to a ruby Proc.
# Creating and passing an instance of this class instead of just a plain block makes
# it possible to inherit the parameter info and arity from the closure. Advanced users
# may also access the closure itself. The Puppet::Pops::Functions::Dispatcher uses this
# when it needs to get the Callable type of the closure.
#
# The class is part of the Puppet Function API for Ruby and thus public API but a user
# should never create an instance of this class.
#
# @api public
class Puppet::Pops::Evaluator::PuppetProc < Proc
  # Creates a new instance from a closure and a block that will dispatch
  # all parameters to the closure. The block must be similar to:
  #
  #   { |*args| closure.call(*args) }
  #
  # @param closure [Puppet::Pops::Evaluator::Closure] The closure to map
  # @param &block [Block] The varargs block that invokes the closure.call method
  #
  # @api private
  def self.new(closure, &block)
    proc = super(&block)
    proc.instance_variable_set(:@closure, closure)
    proc
  end

  # @return  [Puppet::Pops::Evaluator::Closure] the mapped closure
  # @api public
  attr_reader :closure

  # @overrides Block.lambda?
  # @return [Boolean] always false since this proc doesn't do the Ruby lambda magic
  # @api public
  def lambda?
    false
  end

  # Maps the closure parameters to standard Block parameter info where each
  # parameter is represented as a two element Array where the first
  # element is :req, :opt, or :rest and the second element is the name
  # of the parameter.
  #
  # @return [Array<Array<Symbol>>] array of parameter info pairs
  # @overrides Block.parameters
  # @api public
  def parameters
    @closure.parameters.map do |param|
      sym = param.name.to_sym
      if param.captures_rest
        [ :rest, sym ]
      elsif param.value
        [ :opt, sym ]
      else
        [ :req, sym ]
      end
    end
  end

  # @return [Integer] the arity of the block
  # @overrides Block.arity
  # @api public
  def arity
    parameters.reduce(0) do |memo, param|
      count = memo + 1
      break -count unless param[0] == :req
      count
    end
  end
end
