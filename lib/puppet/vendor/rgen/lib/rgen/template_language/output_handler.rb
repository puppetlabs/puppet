# RGen Framework
# (c) Martin Thiede, 2006

module RGen
  
module TemplateLanguage
  
  class OutputHandler
    attr_writer :indent
    attr_accessor :noIndentNextLine
    
    def initialize(indent=0, indentString="   ", mode=:explicit)
      self.mode = mode
      @indent = indent
      @indentString = indentString
      @state = :wait_for_nonws
      @output = ""
    end
    
    # ERB will call this method for every string s which is part of the
    # template file in between %> and <%. If s contains a newline, it will
    # call this method for every part of s which is terminated by a \n
    # 
    def concat(s)
      return @output.concat(s) if s.is_a? OutputHandler
      #puts [object_id, noIndentNextLine, @state, @output.to_s, s].inspect
      s = s.to_str.gsub(/^[\t ]*\r?\n/,'') if @ignoreNextNL
      s = s.to_str.gsub(/^\s+/,'') if @ignoreNextWS
      @ignoreNextNL = @ignoreNextWS = false if s =~ /\S/
      if @mode == :direct
        @output.concat(s)
      elsif @mode == :explicit
        while s.size > 0
          if @state == :wait_for_nl
            if s =~ /\A([^\r\n]*\r?\n)(.*)/m
              rest = $2
              @output.concat($1.gsub(/[\t ]+(?=\r|\n)/,''))
              s = rest || ""
              @state = :wait_for_nonws
            else
              @output.concat(s)
              s = ""
            end
          elsif @state == :wait_for_nonws
            if s =~ /\A\s*(\S+.*)/m
              s = $1 || ""
              if !@noIndentNextLine && !(@output.to_s.size > 0 && @output.to_s[-1] != "\n"[0])
                @output.concat(@indentString * @indent)
              else
                @noIndentNextLine = false
              end
              @state = :wait_for_nl
            else
              s = ""
            end
          end
        end
      end
    end
    alias << concat
    
    def to_str
      @output
    end
    alias to_s to_str
    
    def direct_concat(s)
      @output.concat(s)
    end
    
    def ignoreNextNL
      @ignoreNextNL = true
    end
    
    def ignoreNextWS
      @ignoreNextWS = true
    end
    
    def mode=(m)
      raise StandardError.new("Unknown mode: #{m}") unless [:direct, :explicit].include?(m)
      @mode = m
    end
  end
  
end
  
end