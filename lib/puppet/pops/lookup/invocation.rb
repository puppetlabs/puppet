require_relative 'explainer'

module Puppet::Pops
module Lookup
# @api private
class Invocation
  attr_reader :scope, :override_values, :default_values, :explainer, :module_name, :top_key, :adapter_class

  def self.current
    @current
  end

  # Creates a context object for a lookup invocation. The object contains the current scope, overrides, and default
  # values and may optionally contain an {ExplanationAcceptor} instance that will receive book-keeping information
  # about the progress of the lookup.
  #
  # If the _explain_ argument is a boolean, then _false_ means that no explanation is needed and _true_ means that
  # the default explanation acceptor should be used. The _explain_ argument may also be an instance of the
  # `ExplanationAcceptor` class.
  #
  # @param scope [Puppet::Parser::Scope] The scope to use for the lookup
  # @param override_values [Hash<String,Object>|nil] A map to use as override. Values found here are returned immediately (no merge)
  # @param default_values [Hash<String,Object>] A map to use as the last resort (but before default)
  # @param explainer [boolean,Explanainer] An boolean true to use the default explanation acceptor or an explainer instance that will receive information about the lookup
  def initialize(scope, override_values = EMPTY_HASH, default_values = EMPTY_HASH, explainer = nil, adapter_class = LookupAdapter)
    @scope = scope
    @override_values = override_values
    @default_values = default_values

    parent_invocation = self.class.current
    if parent_invocation.nil?
      @name_stack = []
      @adapter_class = adapter_class
      unless explainer.is_a?(Explainer)
        explainer = explainer == true ? Explainer.new : nil
      end
      explainer = DebugExplainer.new(explainer) if Puppet[:debug] && !explainer.is_a?(DebugExplainer)
    else
      @name_stack = parent_invocation.name_stack
      @adapter_class = parent_invocation.adapter_class
      set_global_only if parent_invocation.global_only?
      povr = parent_invocation.hiera_v3_location_overrides
      set_hiera_v3_location_overrides(povr) unless povr.empty?
      explainer = explainer == false ? nil : parent_invocation.explainer
    end
    @explainer = explainer
  end

  def lookup(key, module_name)
    @top_key = key
    @module_name = module_name
    save_current = self.class.current
    if save_current.equal?(self)
      yield
    else
      begin
        self.class.instance_variable_set(:@current, self)
        yield
      ensure
        self.class.instance_variable_set(:@current, save_current)
      end
    end
  end

  def check(name)
    if @name_stack.include?(name)
      raise Puppet::DataBinding::RecursiveLookupError, "Recursive lookup detected in [#{@name_stack.join(', ')}]"
    end
    return unless block_given?

    @name_stack.push(name)
    begin
      yield
    rescue Puppet::DataBinding::LookupError
      raise
    rescue Puppet::Error => detail
      raise Puppet::DataBinding::LookupError.new(detail.message, nil, nil, nil, detail)
    ensure
      @name_stack.pop
    end
  end

  def emit_debug_info(preamble)
    @explainer.emit_debug_info(preamble) if @explainer.is_a?(DebugExplainer)
  end

  def lookup_adapter
    @adapter ||= @adapter_class.adapt(scope.compiler)
  end

  # This method is overridden by the special Invocation used while resolving interpolations in a
  # Hiera configuration file (hiera.yaml) where it's used for collecting and remembering the current
  # values that the configuration was based on
  #
  # @api private
  def remember_scope_lookup(*lookup_result)
    # Does nothing by default
  end

  # The qualifier_type can be one of:
  # :global - qualifier is the data binding terminus name
  # :data_provider - qualifier a DataProvider instance
  # :path - qualifier is a ResolvedPath instance
  # :merge - qualifier is a MergeStrategy instance
  # :interpolation - qualifier is the unresolved interpolation expression
  # :meta - qualifier is the module name
  # :data - qualifier is the key
  #
  # @param qualifier [Object] A branch, a provider, or a path
  def with(qualifier_type, qualifier)
    if explainer.nil?
      yield
    else
      @explainer.push(qualifier_type, qualifier)
      begin
        yield
      ensure
        @explainer.pop
      end
    end
  end

  def only_explain_options?
    @explainer.nil? ? false : @explainer.only_explain_options?
  end

  def explain_options?
    @explainer.nil? ? false : @explainer.explain_options?
  end

  def report_found_in_overrides(key, value)
    @explainer.accept_found_in_overrides(key, value) unless @explainer.nil?
    value
  end

  def report_found_in_defaults(key, value)
    @explainer.accept_found_in_defaults(key, value) unless @explainer.nil?
    value
  end

  def report_found(key, value)
    @explainer.accept_found(key, value) unless @explainer.nil?
    value
  end

  def report_merge_source(merge_source)
    @explainer.accept_merge_source(merge_source) unless @explainer.nil?
  end

  # Report the result of a merge or fully resolved interpolated string
  # @param value [Object] The result to report
  # @return [Object] the given value
  def report_result(value)
    @explainer.accept_result(value) unless @explainer.nil?
    value
  end

  def report_not_found(key)
    @explainer.accept_not_found(key) unless @explainer.nil?
  end

  def report_location_not_found
    @explainer.accept_location_not_found unless @explainer.nil?
  end

  def report_module_not_found(module_name)
    @explainer.accept_module_not_found(module_name) unless @explainer.nil?
  end

  def report_module_provider_not_found(module_name)
    @explainer.accept_module_provider_not_found(module_name) unless @explainer.nil?
  end

  def report_text(&block)
    unless @explainer.nil?
      @explainer.accept_text(block.call)
    end
  end

  def global_only?
    lookup_adapter.global_only? || (instance_variable_defined?(:@global_only) ? @global_only : false)
  end

  # Instructs the lookup framework to only perform lookups in the global layer
  # @return [Invocation] self
  def set_global_only
    @global_only = true
    self
  end

  # @return [Pathname] the full path of the hiera.yaml config file
  def global_hiera_config_path
    lookup_adapter.global_hiera_config_path
  end

  # Overrides passed from hiera_xxx functions down to V3DataHashFunctionProvider
  def set_hiera_v3_location_overrides(overrides)
    @hiera_v3_location_overrides = [overrides].flatten unless overrides.nil?
  end

  def hiera_v3_location_overrides
    instance_variable_defined?(:@hiera_v3_location_overrides) ? @hiera_v3_location_overrides : EMPTY_ARRAY
  end

  protected

  def name_stack
    @name_stack.clone
  end
end
end
end
