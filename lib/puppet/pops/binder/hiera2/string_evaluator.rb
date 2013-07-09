module Puppet::Pops::Binder::Hiera2

  # Simple string evaluator used only when expanding values defined in the configuration.
  # This evaluator is not intended to be used when the bindings are evaluated
  class StringEvaluator

    # Initialize the instance
    #
    # @param scope [Hash<String,String>] The scope to use when performing variable interpolation
    # @param parser [Puppet::Pops::Parser::Parser] The parser that will parse the strings
    # @param diag [Puppet::Pops::Binder::Hiera2::DiagnosticProducer] Receiver of diagnostic messages
    def initialize(scope, parser, diag)
      @@eval_visitor ||= Puppet::Pops::Visitor.new(nil, "_eval", 1, 1)
      @parser = parser
      @scope = scope
      @diag = diag
    end

    # Evaluate the argument using the scope assigned to this instance
    def eval(x)
      if x.is_a?(String)
        _eval(@parser.parse_string(StringEvaluator.quote(x)).current, x)
      else
        x
      end
    end

    def _eval(o, x)
      @@eval_visitor.visit_this(self, o, x)
    end

    def _eval_Expression(o, x)
      # Evaluation ends up here if the expression is an unsupported expression
      @diag.accept(Issues::UNSUPPORTED_STRING_EXPRESSION, x, { :expr => o})
    end

    def _eval_LiteralValue(o, x)
      o.value
    end

    def _eval_VariableExpression(o, x)
      key = o.expr.value
      val = @scope[key]
      return val unless val.nil?
      @diag.accept(Issues::UNRESOLVED_STRING_VARIABLE, x, { :key => key })
      val = ''
    end

    def _eval_TextExpression(o, x)
      _eval(o.expr, x)
    end

    def _eval_ConcatenatedString(o, x)
      o.segments.collect { |s| _eval(s, x) }.join()
    end

    # Translates an already parsed string that contains control characters, quotes
    # and backslashes into a quoted string where all such constructs have been escaped
    # Parsing the return value of this method using the puppet parser should yield
    # exactly the same string as the argument passed to this method
    #
    # The method makes an exception for the two character sequences \$ and \s. They
    # will not be escaped since they have a special meaning in puppet syntax.
    #
    # @param x [String] The string to quote and "unparse"
    # @return [String] The quoted string
    #
    def self.quote(x)
      escaped = '"'
      p = nil
      x.each_codepoint do |c|
        case p
        when nil
          # do nothing
        when 0x09
          escaped << '\\t'
        when 0x0a
          escaped << '\\n'
        when 0x0d
          escaped << '\\f'
        when 0x0d
          escaped << '\\c'
        when 0x22
          escaped << '\\"'
        when 0x5c
          escaped << if c == 0x24 || c == 0x73; p; else '\\\\'; end # don't escape \ when followed by s or $
        else
          escaped << p
        end
        p = c
      end
      escaped << p unless p.nil?
      escaped << '"'
    end
  end
end
