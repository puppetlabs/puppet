module Puppet::Pops::Lookup

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

    def to_s
      io = StringIO.new
      dump_on(io, '', '')
      io.string
    end

    def dump_on(io, indent, first_indent)
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
      @key = key
      @value = value
      @event = :found_in_overrides
    end

    def found_in_defaults(key, value)
      @key = key
      @value = value
      @event = :found_in_defaults
    end

    def found(key, value)
      @key = key
      @value = value
      @event = :found
    end

    def result(value)
      @value = value
      @event = :result
    end

    def not_found(key)
      @key = key
      @event = :not_found
    end

    def path_not_found
      @event = :path_not_found
    end

    def module_not_found
      @event = :module_not_found
    end

    def increase_indent(indent)
      indent + '  '
    end

    def to_hash
      hash = super
      hash[:key] = @key unless @key.nil?
      hash[:value] = @value if [:found, :found_in_defaults, :found_in_overrides, :result].include?(@event)
      hash[:event] = @event unless @event.nil?
      hash[:type] = type
      hash
    end

    def type
      :root
    end

    def dump_outcome(io, indent)
      io << indent << 'No such key: "' << @key << "\"\n" if @event == :not_found
      if [:found, :found_in_overrides, :found_in_defaults].include?(@event)
        io << indent << 'Found key: "' << @key << '" value: '
        dump_value(io, indent, @value)
        io << ' in overrides' if @event == :found_in_overrides
        io << ' in defaults' if @event == :found_in_defaults
        io << "\n"
      end
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
  end

  class ExplainTop < ExplainTreeNode
    def initialize(parent, type, key)
      super(parent)
      @type = type
      self.key = key
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
      @key = key
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

      io << first_indent << 'Merge strategy ' << @merge.class.key << "\n"
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

  class ExplainModule < ExplainTreeNode
    def initialize(parent, mod)
      super(parent)
      @module = mod
    end

    def dump_on(io, indent, first_indent)
      io << indent << 'Module "' << @module << '"'
      if branches.size == 1
        branches[0].dump_on(io, indent, ' using ')
      else
        io << "\n"
        indent = increase_indent(indent)
        branches.each {|b| b.dump_on(io, indent, indent)}
      end
      io << indent << "Module not found\n" if @event == :module_not_found
    end

    def to_hash
      if branches.size == 1
        branches[0].to_hash.merge(:module => @module)
      else
        hash = super
        hash[:module] = @module
        hash
      end
    end

    def type
      :module
    end
  end

  class ExplainGlobal < ExplainTreeNode
    def initialize(parent, binding_terminus)
      super(parent)
      @binding_terminus = binding_terminus
    end

    def dump_on(io, indent, first_indent)
      io << first_indent << 'Data Binding "' << @binding_terminus << "\"\n"
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
      io << first_indent << 'Data Provider "' << @provider.name << "\"\n"
      indent = increase_indent(indent)
      io << indent << 'ConfigurationPath "' << @provider.config_path << "\"\n" if @provider.respond_to?(:config_path)
      branches.each {|b| b.dump_on(io, indent, indent)}
      dump_outcome(io, indent)
    end

    def to_hash
      hash = super
      hash[:name] = @provider.name
      hash[:configuration_path] = @provider.config_path.to_s if @provider.respond_to?(:config_path)
      hash
    end

    def type
      :data_provider
    end
  end

  class ExplainPath < ExplainTreeNode
    def initialize(parent, path)
      super(parent)
      @path = path
    end

    def dump_on(io, indent, first_indent)
      io << indent << 'Path "' << @path.path << "\"\n"
      indent = increase_indent(indent)
      io << indent << 'Original path: "' << @path.original_path << "\"\n"
      branches.each {|b| b.dump_on(io, indent, indent)}
      io << indent << "Path not found\n" if @event == :path_not_found
      dump_outcome(io, indent)
    end

    def to_hash
      hash = super
      hash[:original_path] = @path.original_path
      hash[:path] = @path.path.to_s
      hash
    end

    def type
      :path
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
    def initialize(parent)
      super(parent)
    end

    def dump_on(io, indent, first_indent)
      io << indent << 'Global Scope' << "\n"
      indent = increase_indent(indent)
      dump_outcome(io, indent)
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
        when :path
          ExplainPath.new(@current, qualifier)
        when :module
          ExplainModule.new(@current, qualifier)
        when :interpolate
          ExplainInterpolate.new(@current, qualifier)
        when :data_provider
          ExplainDataProvider.new(@current, qualifier)
        when :merge
          ExplainMerge.new(@current, qualifier)
        when :scope
          ExplainScope.new(@current)
        when :sub_lookup
          ExplainSubLookup.new(@current, qualifier)
        when :segment
          ExplainKeySegment.new(@current, qualifier)
        when :meta, :data
          ExplainTop.new(@current, qualifier_type, qualifier)
        when :invalid_key
          ExplainInvalidKey.new(@current, qualifier)
        else
          raise ArgumentError, "Unknown Explain type #{qualifier_type}"
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

    def accept_path_not_found
      @current.path_not_found
    end

    def accept_module_not_found
      @current.module_not_found
    end

    def accept_result(result)
      @current.result(result)
    end

    def dump_on(io, indent, first_indent)
      branches.each { |b| b.dump_on(io, indent, first_indent) }
    end

    def to_hash
      branches.size == 1 ? branches[0].to_hash : super
    end
  end
end
