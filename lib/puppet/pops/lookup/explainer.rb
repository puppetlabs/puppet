module Puppet::Pops
module Lookup

# The ExplainNode contains information of a specific node in a tree traversed during
# lookup. The tree can be traversed using the `parent` and `branches` attributes of
# each node.
#
# Each leaf node contains information about what happened when the leaf of the branch
# was traversed.
  class ExplainNode
    def branches
      @branches ||= []
    end

    def to_hash
      hash = {}
      hash[:branches] = @branches.map {|b| b.to_hash} unless @branches.nil? || @branches.empty?
      hash
    end

    def explain
      io = ''
      dump_on(io, '', '')
      io
    end

    def inspect
      to_s
    end

    def to_s
      s = self.class.name
      s = "#{s} with #{@branches.size} branches" unless @branches.nil?
      s
    end

    def text(text)
      @texts ||= []
      @texts << text
    end

    def dump_on(io, indent, first_indent)
      dump_texts(io, indent)
    end

    def dump_texts(io, indent)
      @texts.each { |text| io << indent << text << "\n" } if instance_variable_defined?(:@texts)
    end
  end

  class ExplainTreeNode < ExplainNode
    attr_reader :parent, :event, :value
    attr_accessor :key

    def initialize(parent)
      @parent = parent
      @event = nil
    end

    def found_in_overrides(key, value)
      @key = key.to_s
      @value = value
      @event = :found_in_overrides
    end

    def found_in_defaults(key, value)
      @key = key.to_s
      @value = value
      @event = :found_in_defaults
    end

    def found(key, value)
      @key = key.to_s
      @value = value
      @event = :found
    end

    def result(value)
      @value = value
      @event = :result
    end

    def not_found(key)
      @key = key.to_s
      @event = :not_found
    end

    def location_not_found
      @event = :location_not_found
    end

    def increase_indent(indent)
      indent + '  '
    end

    def to_hash
      hash = super
      hash[:key] = @key unless @key.nil?
      hash[:value] = @value if [:found, :found_in_defaults, :found_in_overrides, :result].include?(@event)
      hash[:event] = @event unless @event.nil?
      hash[:texts] = @texts unless @texts.nil?
      hash[:type] = type
      hash
    end

    def type
      :root
    end

    def dump_outcome(io, indent)
      case @event
      when :not_found
        io << indent << 'No such key: "' << @key << "\"\n"
      when :found, :found_in_overrides, :found_in_defaults
        io << indent << 'Found key: "' << @key << '" value: '
        dump_value(io, indent, @value)
        io << ' in overrides' if @event == :found_in_overrides
        io << ' in defaults' if @event == :found_in_defaults
        io << "\n"
      end
      dump_texts(io, indent)
    end

    def dump_value(io, indent, value)
      case value
      when Hash
        io << '{'
        unless value.empty?
          inner_indent = increase_indent(indent)
          value.reduce("\n") do |sep, (k, v)|
            io << sep << inner_indent
            dump_value(io, inner_indent, k)
            io << ' => '
            dump_value(io, inner_indent, v)
            ",\n"
          end
          io << "\n" << indent
        end
        io << '}'
      when Array
        io << '['
        unless value.empty?
          inner_indent = increase_indent(indent)
          value.reduce("\n") do |sep, v|
            io << sep << inner_indent
            dump_value(io, inner_indent, v)
            ",\n"
          end
          io << "\n" << indent
        end
        io << ']'
      else
        io << value.inspect
      end
    end

    def to_s
      "#{self.class.name}: #{@key}, #{@event}"
    end
  end

  class ExplainTop < ExplainTreeNode
    def initialize(parent, type, key)
      super(parent)
      @type = type
      self.key = key.to_s
    end

    def dump_on(io, indent, first_indent)
      io << first_indent << 'Searching for "' << key << "\"\n"
      indent = increase_indent(indent)
      branches.each {|b| b.dump_on(io, indent, indent)}
    end
  end

  class ExplainInvalidKey < ExplainTreeNode
    def initialize(parent, key)
      super(parent)
      @key = key.to_s
    end

    def dump_on(io, indent, first_indent)
      io << first_indent << "Invalid key \"" << @key << "\"\n"
    end

    def type
      :invalid_key
    end
  end

  class ExplainMergeSource < ExplainNode
    attr_reader :merge_source

    def initialize(merge_source)
      @merge_source = merge_source
    end

    def dump_on(io, indent, first_indent)
      io << first_indent << 'Using merge options from "' << merge_source << "\" hash\n"
    end

    def to_hash
      { :type => type, :merge_source => merge_source }
    end

    def type
      :merge_source
    end
  end

  class ExplainModule < ExplainTreeNode
    def initialize(parent, module_name)
      super(parent)
      @module_name = module_name
    end

    def dump_on(io, indent, first_indent)
      case @event
      when :module_not_found
        io << indent << 'Module "' << @module_name << "\" not found\n"
      when :module_provider_not_found
        io << indent << 'Module data provider for module "' << @module_name << "\" not found\n"
      end
    end

    def module_not_found
      @event = :module_not_found
    end

    def module_provider_not_found
      @event = :module_provider_not_found
    end

    def type
      :module
    end
  end

  class ExplainInterpolate < ExplainTreeNode
    def initialize(parent, expression)
      super(parent)
      @expression = expression
    end

    def dump_on(io, indent, first_indent)
      io << first_indent << 'Interpolation on "' << @expression << "\"\n"
      indent = increase_indent(indent)
      branches.each {|b| b.dump_on(io, indent, indent)}
    end

    def to_hash
      hash = super
      hash[:expression] = @expression
      hash
    end

    def type
      :interpolate
    end
  end

  class ExplainMerge < ExplainTreeNode
    def initialize(parent, merge)
      super(parent)
      @merge = merge
    end

    def dump_on(io, indent, first_indent)
      return if branches.size == 0

      # It's pointless to report a merge where there's only one branch
      return branches[0].dump_on(io, indent, first_indent) if branches.size == 1

      io << first_indent << 'Merge strategy ' << @merge.class.key.to_s << "\n"
      indent = increase_indent(indent)
      options = options_wo_strategy
      unless options.nil?
        io << indent << 'Options: '
        dump_value(io, indent, options)
        io << "\n"
      end
      branches.each {|b| b.dump_on(io, indent, indent)}
      if @event == :result
        io << indent << 'Merged result: '
        dump_value(io, indent, @value)
        io << "\n"
      end
    end

    def to_hash
      return branches[0].to_hash if branches.size == 1
      hash = super
      hash[:merge] = @merge.class.key
      options = options_wo_strategy
      hash[:options] = options unless options.nil?
      hash
    end

    def type
      :merge
    end

    def options_wo_strategy
      options = @merge.options
      if !options.nil? && options.include?('strategy')
        options = options.dup
        options.delete('strategy')
      end
      options.empty? ? nil : options
    end
  end

  class ExplainGlobal < ExplainTreeNode
    def initialize(parent, binding_terminus)
      super(parent)
      @binding_terminus = binding_terminus
    end

    def dump_on(io, indent, first_indent)
      io << first_indent << 'Data Binding "' << @binding_terminus.to_s << "\"\n"
      indent = increase_indent(indent)
      branches.each {|b| b.dump_on(io, indent, indent)}
      dump_outcome(io, indent)
    end

    def to_hash
      hash = super
      hash[:name] = @binding_terminus
      hash
    end

    def type
      :global
    end
  end

  class ExplainDataProvider < ExplainTreeNode
    def initialize(parent, provider)
      super(parent)
      @provider = provider
    end

    def dump_on(io, indent, first_indent)
      io << first_indent << @provider.name << "\n"
      indent = increase_indent(indent)
      if @provider.respond_to?(:config_path)
        path = @provider.config_path
        io << indent << 'Using configuration "' << path.to_s << "\"\n" unless path.nil?
      end
      branches.each {|b| b.dump_on(io, indent, indent)}
      dump_outcome(io, indent)
    end

    def to_hash
      hash = super
      hash[:name] = @provider.name
      if @provider.respond_to?(:config_path)
        path = @provider.config_path
        hash[:configuration_path] = path.to_s unless path.nil?
      end
      hash[:module] = @provider.module_name if @provider.is_a?(ModuleDataProvider)
      hash
    end

    def type
      :data_provider
    end
  end

  class ExplainLocation < ExplainTreeNode
    def initialize(parent, location)
      super(parent)
      @location = location
    end

    def dump_on(io, indent, first_indent)
      location = @location.location
      type_name = type == :path ? 'Path' : 'URI'
      io << indent << type_name << ' "' << location.to_s << "\"\n"
      indent = increase_indent(indent)
      io << indent << 'Original ' << type_name.downcase << ': "' << @location.original_location << "\"\n"
      branches.each {|b| b.dump_on(io, indent, indent)}
      io << indent << type_name << " not found\n" if @event == :location_not_found
      dump_outcome(io, indent)
    end

    def to_hash
      hash = super
      location = @location.location
      if type == :path
        hash[:original_path] = @location.original_location
        hash[:path] = location.to_s
      else
        hash[:original_uri] = @location.original_location
        hash[:uri] = location.to_s
      end
      hash
    end

    def type
      @location.location.is_a?(Pathname) ? :path : :uri
    end
  end

  class ExplainSubLookup < ExplainTreeNode
    def initialize(parent, sub_key)
      super(parent)
      @sub_key = sub_key
    end

    def dump_on(io, indent, first_indent)
      io << indent << 'Sub key: "' << @sub_key.join('.') << "\"\n"
      indent = increase_indent(indent)
      branches.each {|b| b.dump_on(io, indent, indent)}
      dump_outcome(io, indent)
    end

    def type
      :sub_key
    end
  end

  class ExplainKeySegment < ExplainTreeNode
    def initialize(parent, segment)
      super(parent)
      @segment = segment
    end

    def dump_on(io, indent, first_indent)
      dump_outcome(io, indent)
    end

    def type
      :segment
    end
  end

  class ExplainScope < ExplainTreeNode
    def initialize(parent, name)
      super(parent)
      @name = name
    end

    def dump_on(io, indent, first_indent)
      io << indent << @name << "\n"
      indent = increase_indent(indent)
      branches.each {|b| b.dump_on(io, indent, indent)}
      dump_outcome(io, indent)
    end

    def to_hash
      hash = super
      hash[:name] = @name
      hash
    end

    def type
      :scope
    end
  end

  class Explainer < ExplainNode
    def initialize(explain_options = false, only_explain_options = false)
      @current = self
      @explain_options = explain_options
      @only_explain_options = only_explain_options
    end

    def push(qualifier_type, qualifier)
      node = case (qualifier_type)
        when :global
         ExplainGlobal.new(@current, qualifier)
        when :location
          ExplainLocation.new(@current, qualifier)
        when :interpolate
          ExplainInterpolate.new(@current, qualifier)
        when :data_provider
          ExplainDataProvider.new(@current, qualifier)
        when :merge
          ExplainMerge.new(@current, qualifier)
        when :module
          ExplainModule.new(@current, qualifier)
        when :scope
          ExplainScope.new(@current, qualifier)
        when :sub_lookup
          ExplainSubLookup.new(@current, qualifier)
        when :segment
          ExplainKeySegment.new(@current, qualifier)
        when :meta, :data
          ExplainTop.new(@current, qualifier_type, qualifier)
        when :invalid_key
          ExplainInvalidKey.new(@current, qualifier)
        else
          #TRANSLATORS 'Explain' is referring to the 'Explainer' class and should not be translated
          raise ArgumentError, _("Unknown Explain type %{qualifier_type}") % { qualifier_type: qualifier_type }
        end
      @current.branches << node
      @current = node
    end

    def only_explain_options?
      @only_explain_options
    end

    def explain_options?
      @explain_options
    end

    def pop
      @current = @current.parent unless @current.parent.nil?
    end

    def accept_found_in_overrides(key, value)
      @current.found_in_overrides(key, value)
    end

    def accept_found_in_defaults(key, value)
      @current.found_in_defaults(key, value)
    end

    def accept_found(key, value)
      @current.found(key, value)
    end

    def accept_merge_source(merge_source)
      @current.branches << ExplainMergeSource.new(merge_source)
    end

    def accept_not_found(key)
      @current.not_found(key)
    end

    def accept_location_not_found
      @current.location_not_found
    end

    def accept_module_not_found(module_name)
      push(:module, module_name)
      @current.module_not_found
      pop
    end

    def accept_module_provider_not_found(module_name)
      push(:module, module_name)
      @current.module_provider_not_found
      pop
    end

    def accept_result(result)
      @current.result(result)
    end

    def accept_text(text)
      @current.text(text)
    end

    def dump_on(io, indent, first_indent)
      branches.each { |b| b.dump_on(io, indent, first_indent) }
      dump_texts(io, indent)
    end

    def to_hash
      branches.size == 1 ? branches[0].to_hash : super
    end
  end

  class DebugExplainer < Explainer
    attr_reader :wrapped_explainer

    def initialize(wrapped_explainer)
      @wrapped_explainer = wrapped_explainer
      if wrapped_explainer.nil?
        @current = self
        @explain_options = false
        @only_explain_options = false
      else
        @current = wrapped_explainer
        @explain_options = wrapped_explainer.explain_options?
        @only_explain_options = wrapped_explainer.only_explain_options?
      end
    end

    def dump_on(io, indent, first_indent)
      @current.equal?(self) ? super : @current.dump_on(io, indent, first_indent)
    end

    def emit_debug_info(preamble)
      io = ''
      io << preamble << "\n"
      dump_on(io, '  ', '  ')
      Puppet.debug(io.chomp!)
    end
  end
end
end
