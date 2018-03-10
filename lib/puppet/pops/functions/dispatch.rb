module Puppet::Pops
module Functions
# Defines a connection between a implementation method and the signature that
# the method will handle.
#
# This interface should not be used directly. Instead dispatches should be
# constructed using the DSL defined in {Puppet::Functions}.
#
# @api private
class Dispatch < Evaluator::CallableSignature
  # @api public
  attr_reader :type
  # TODO: refactor to parameter_names since that makes it API
  attr_reader :param_names
  attr_reader :injections

  # Describes how arguments are woven if there are injections, a regular argument is a given arg index, an array
  # an injection description.
  #
  attr_reader :weaving
  # @api public
  attr_reader :block_name

  # @param type [Puppet::Pops::Types::PArrayType, Puppet::Pops::Types::PTupleType] - type describing signature
  # @param method_name [String] the name of the method that will be called when type matches given arguments
  # @param param_names [Array<String>] names matching the number of parameters specified by type (or empty array)
  # @param block_name [String,nil] name of block parameter, no nil
  # @param injections [Array<Array>] injection data for weaved parameters
  # @param weaving [Array<Integer,Array>] weaving knits
  # @param last_captures [Boolean] true if last parameter is captures rest
  # @param argument_mismatch_handler [Boolean] true if this is a dispatch for an argument mismatch
  # @api private
  def initialize(type, method_name, param_names, last_captures = false, block_name = nil, injections = EMPTY_ARRAY, weaving = EMPTY_ARRAY, argument_mismatch_handler = false)
    @type = type
    @method_name = method_name
    @param_names = param_names
    @last_captures = last_captures
    @block_name = block_name
    @injections = injections
    @weaving = weaving
    @argument_mismatch_handler = argument_mismatch_handler
  end

  # @api private
  def parameter_names
    @param_names
  end

  # @api private
  def last_captures_rest?
    @last_captures
  end

  def argument_mismatch_handler?
    @argument_mismatch_handler
  end

  # @api private
  def invoke(instance, calling_scope, args, &block)
    result = instance.send(@method_name, *weave(calling_scope, args), &block)
    return_type = @type.return_type
    Types::TypeAsserter.assert_instance_of(nil, return_type, result) { "value returned from function '#{@method_name}'" } unless return_type.nil?
    result
  end

  # @api private
  def weave(scope, args)
    # no need to weave if there are no injections
    if @injections.empty?
      args
    else
      new_args = []
      @weaving.each do |knit|
        if knit.is_a?(Array)
          injection_name = @injections[knit[0]]
          new_args <<
            case injection_name
            when :scope
              scope
            when :pal_script_compiler
              Puppet.lookup(:pal_script_compiler)
            else
              raise ArgumentError, _("Unknown injection %{injection_name}") % { injection_name: injection_name }
            end
        else
          # Careful so no new nil arguments are added since they would override default
          # parameter values in the received
          if knit < 0
            idx = -knit - 1
            new_args += args[idx..-1] if idx < args.size
          else
            new_args << args[knit] if knit < args.size
          end
        end
      end
      new_args
    end
  end
end
end
end
