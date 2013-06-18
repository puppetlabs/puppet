require "psych"
require "base64"

module SafeYAML
  class PsychHandler < Psych::Handler
    def initialize(options)
      @options      = SafeYAML::OPTIONS.merge(options || {})
      @initializers = @options[:custom_initializers] || {}
      @anchors      = {}
      @stack        = []
      @current_key  = nil
      @result       = nil
    end

    def result
      @result
    end

    def add_to_current_structure(value, anchor=nil, quoted=nil, tag=nil)
      value = Transform.to_proper_type(value, quoted, tag, @options)

      @anchors[anchor] = value if anchor

      if @result.nil?
        @result = value
        @current_structure = @result
        return
      end

      if @current_structure.respond_to?(:<<)
        @current_structure << value

      elsif @current_structure.respond_to?(:[]=)
        if @current_key.nil?
          @current_key = value

        else
          if @current_key == "<<"
            @current_structure.merge!(value)
          else
            @current_structure[@current_key] = value
          end

          @current_key = nil
        end

      else
        raise "Don't know how to add to a #{@current_structure.class}!"
      end
    end

    def end_current_structure
      @stack.pop
      @current_structure = @stack.last
    end

    def streaming?
      false
    end

    # event handlers
    def alias(anchor)
      add_to_current_structure(@anchors[anchor])
    end

    def scalar(value, anchor, tag, plain, quoted, style)
      add_to_current_structure(value, anchor, quoted, tag)
    end

    def start_mapping(anchor, tag, implicit, style)
      map = @initializers.include?(tag) ? @initializers[tag].call : {}
      self.add_to_current_structure(map, anchor)
      @current_structure = map
      @stack.push(map)
    end

    def end_mapping
      self.end_current_structure()
    end

    def start_sequence(anchor, tag, implicit, style)
      seq = @initializers.include?(tag) ? @initializers[tag].call : []
      self.add_to_current_structure(seq, anchor)
      @current_structure = seq
      @stack.push(seq)
    end

    def end_sequence
      self.end_current_structure()
    end
  end
end
