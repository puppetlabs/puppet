# frozen_string_literal: true

# The RubyLegacyFunctionInstantiator instantiates a Puppet::Functions::Function given the ruby source
# that calls Puppet::Functions.create_function.
#
require 'ripper'
class Puppet::Pops::Loader::RubyLegacyFunctionInstantiator
  UNKNOWN = '<unknown>'

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
    # Assert content of 3x function by parsing
    assertion_result = []
    if assert_code(ruby_code_string, source_ref, assertion_result)
      unless ruby_code_string.is_a?(String) && assertion_result.include?(:found_newfunction)
        raise ArgumentError, _("The code loaded from %{source_ref} does not seem to be a Puppet 3x API function - no 'newfunction' call.") % { source_ref: source_ref }
      end
    end

    # make the private loader available in a binding to allow it to be passed on
    loader_for_function = loader.private_loader
    here = get_binding(loader_for_function)

    # Avoid reloading the function if already loaded via one of the APIs that trigger 3x function loading
    # Check if function is already loaded the 3x way (and obviously not the 4x way since we would not be here in the
    # first place.
    environment = Puppet.lookup(:current_environment)
    func_info = Puppet::Parser::Functions.environment_module(environment).get_function_info(typed_name.name.to_sym)
    if func_info.nil?
      # This will do the 3x loading and define the "function_<name>" and "real_function_<name>" methods
      # in the anonymous module used to hold function definitions.
      #
      func_info = eval(ruby_code_string, here, source_ref, 1) # rubocop:disable Security/Eval

      # Validate what was loaded
      unless func_info.is_a?(Hash)
        # TRANSLATORS - the word 'newfunction' should not be translated as it is a method name.
        raise ArgumentError, _("Illegal legacy function definition! The code loaded from %{source_ref} did not return the result of calling 'newfunction'. Got '%{klass}'") % { source_ref: source_ref, klass: func_info.class }
      end

      unless func_info[:name] == "function_#{typed_name.name()}"
        raise ArgumentError, _("The code loaded from %{source_ref} produced mis-matched name, expected 'function_%{type_name}', got '%{created_name}'") % {
          source_ref: source_ref, type_name: typed_name.name, created_name: func_info[:name]
        }
      end
    end

    created = Puppet::Functions::Function3x.create_function(typed_name.name(), func_info, loader_for_function)

    # create the function instance - it needs closure (scope), and loader (i.e. where it should start searching for things
    # when calling functions etc.
    # It should be bound to global scope

    # Sets closure scope to nil, to let it be picked up at runtime from Puppet.lookup(:global_scope)
    # If function definition used the loader from the binding to create a new loader, that loader wins
    created.new(nil, loader_for_function)
  end

  # Produces a binding where the given loader is bound as a local variable (loader_injected_arg). This variable can be used in loaded
  # ruby code - e.g. to call Puppet::Function.create_loaded_function(:name, loader,...)
  #
  def self.get_binding(loader_injected_arg)
    binding
  end
  private_class_method :get_binding

  def self.assert_code(code_string, source_ref, result)
    ripped = Ripper.sexp(code_string)
    return false if ripped.nil? # Let the next real parse crash and tell where and what is wrong

    ripped.each { |x| walk(x, source_ref, result) }
    true
  end
  private_class_method :assert_code

  def self.walk(x, source_ref, result)
    return unless x.is_a?(Array)

    first = x[0]
    case first
    when :fcall, :call
      # Ripper returns a :fcall for a function call in a module (want to know there is a call to newfunction()).
      # And it returns :call for a qualified named call
      identity_part = find_identity(x)
      result << :found_newfunction if identity_part.is_a?(Array) && identity_part[1] == 'newfunction'
    when :def, :defs
      # There should not be any calls to def in a 3x function
      mname, mline = extract_name_line(find_identity(x))
      raise SecurityError, _("Illegal method definition of method '%{method_name}' in source %{source_ref} on line %{line} in legacy function. See %{url} for more information") % {
        method_name: mname,
        source_ref: source_ref,
        line: mline,
        url: "https://puppet.com/docs/puppet/latest/functions_refactor_legacy.html"
      }
    end
    x.each { |v| walk(v, source_ref, result) }
  end
  private_class_method :walk

  def self.find_identity(rast)
    rast.find { |x| x.is_a?(Array) && x[0] == :@ident }
  end
  private_class_method :find_identity

  # Extracts the method name and line number from the Ripper Rast for an id entry.
  # The expected input (a result from Ripper :@ident entry) is an array with:
  # [0] == :def (or :defs for self.def)
  # [1] == method name
  # [2] == [ <filename>, <linenumber> ]
  #
  # Returns an Array; a tuple with method name and line number or "<unknown>" if either is missing, or format is not the expected
  #
  def self.extract_name_line(x)
    (if x.is_a?(Array)
       [x[1], x[2].is_a?(Array) ? x[2][1] : nil]
     else
       [nil, nil]
     end).map { |v| v.nil? ? UNKNOWN : v }
  end
  private_class_method :extract_name_line
end
