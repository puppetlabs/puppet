# The RubyLegacyFunctionInstantiator loads a 3x function and turns it into a 4x function
# that is called with 3x semantics (values are transformed to be 3x compliant).
#
# The code is loaded from a string obtained by reading the 3x function ruby code into a string
# and then passing it to the loaders class method `create`. When Puppet[:biff] == true, the
# 3x Puppet::Parser::Function.newfunction method relays back to this function loader's
# class method legacy_newfunction which creates a Puppet::Functions class wrapping the 
# 3x function's block into a method in a function class derived from Puppet::Function.
# This class is then returned, and the Legacy loader continues the same way as it does
# for a 4x function.
#
# TODO: Wrapping of Scope
#   The 3x function expects itself to be Scope. It passes itself as scope to other parts of the runtime,
#   it expects to find all sorts of information in itself, get/set variables, get compiler, get environment
#   etc.
# TODO: Transformation of arguments to 3x compliant objects
#
class Puppet::Pops::Loader::RubyLegacyFunctionInstantiator

  # Produces an instance of the Function class with the given typed_name, or fails with an error if the
  # given ruby source does not produce this instance when evaluated.
  #
  # @param loader [Puppet::Pops::Loader::Loader] The loader the function is associated with
  # @param typed_name [Puppet::Pops::Loader::TypedName] the type / name of the function to load
  # @param source_ref [URI, String] a reference to the source / origin of the ruby code to evaluate
  # @param ruby_code_string [String] ruby code in a string
  #
  # @return [Puppet::Pops::Functions.Function] - an instantiated function with global scope closure associated with the given loader
  #
  def self.create(loader, typed_name, source_ref, ruby_code_string)
    # Old Ruby API supports calling a method via ::
    # this must also be checked as well as call with '.'
    #
    unless ruby_code_string.is_a?(String) && ruby_code_string =~ /Puppet\:\:Parser\:\:Functions(?:\.|\:\:)newfunction/
      raise ArgumentError, "The code loaded from #{source_ref} does not seem to be a Puppet 3x API function - no newfunction call."
    end

    # The evaluation of the 3x function creation source should result in a call to the legacy_newfunction
    #
    created = eval(ruby_code_string)
    unless created.is_a?(Class)
      raise ArgumentError, "The code loaded from #{source_ref} did not produce a Function class when evaluated. Got '#{created.class}'"
    end
    unless created.name.to_s == typed_name.name()
      raise ArgumentError, "The code loaded from #{source_ref} produced mis-matched name, expected '#{typed_name.name}', got #{created.name}"
    end
    # create the function instance - it needs closure (scope), and loader (i.e. where it should start searching for things
    # when calling functions etc.
    # It should be bound to global scope

    # TODO: Cheating wrt. scope - assuming it is found in the context
    closure_scope = Puppet.lookup(:global_scope) { {} }
    created.new(closure_scope, loader)
  end

  # This is a new implementation of the method that is used in 3x to create a function.
  # The arguments are the same as those passed to Puppet::Parser::Functions.newfunction, hence its
  # deviation from regular method naming practice.
  #
  def self.legacy_newfunction(name, options, &block)

    # 3x api allows arity to be specified, if unspecified it is 0 or more arguments
    # arity >= 0, is an exact count
    # airty < 0 is the number of required arguments -1 (i.e. -1 is 0 or more)
    # (there is no upper cap, there is no support for optional values, or defaults)
    #
    arity = options[:arity] || -1
    if arity >= 0
      min_arg_count = arity
      max_arg_count = arity
    else
      min_arg_count = (arity + 1).abs
      # infinity
      max_arg_count = :default
    end

    # Create a 4x function wrapper around the 3x Function
    created_function_class = Puppet::Functions.create_function(name) do
      # define a method on the new Function class with the same name as the function, but
      # padded with __ because the function may represent a ruby method with the same name that
      # expects to have inherited from Kernel, and then Object.
      # (This can otherwise lead to infinite recursion, or that an ArgumentError is raised).
      #
      __name__ = :"__#{name}__"
      define_method(__name__, &block)

      # Define the method that is called from dispatch - this method just changes a call
      # with multiple unknown arguments to passing all in an array (since this is expected in the 3x API).
      # We want the call to be checked for type and number of arguments so cannot call the function
      # defined by the block directly since it is defined to take a single argument.
      #
      define_method(:__relay__call__) do |*args|
        # dup the args since the function may destroy them
        # TODO: Should convert arguments to 3x, now :undef is send to the function
        send(__name__, args.dup)
      end

      # Define a dispatch that performs argument type/count checking
      #
      dispatch :__relay__call__ do
        # Use Puppet Type Object (not Optional[Object] since the 3x API passes undef as empty string).
        param 'Object', 'args'
        # Specify arg count (transformed from 3x function arity specification).
        arg_count(min_arg_count, max_arg_count)
      end
    end
    created_function_class
  end
end
