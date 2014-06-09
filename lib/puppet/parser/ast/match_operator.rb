require 'puppet'
require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
  class MatchOperator < AST::Branch

    attr_accessor :lval, :rval, :operator

    # Iterate across all of our children.
    def each
      [@lval,@rval].each { |child| yield child }
    end

    # Returns a boolean which is the result of the boolean operation
    # of lval and rval operands
    def evaluate(scope)
      tmp_lval = @lval.safeevaluate(scope)

      unless tmp_lval.is_a?(String)
        msg = "Match against non String is deprecated. See http://links.puppetlabs.com/deprecate-match-nonstring.\n"+
          "Got #{tmp_lval.class.name} "
        loc = []
        loc << "in file #{file}" if file
        loc << "at line #{line}" if line
        msg << loc.join(", ")

        # Note that regep (rval) also checks against deprecation of positive matches and the same
        # key must be used to avoid multiple deprecations for the same occurence of a match operator.
        Puppet.deprecation_warning(msg, "match #{rval.file}, #{rval.line}")
      end

      return(rval.evaluate_match(tmp_lval, scope) ? @operator == "=~" : @operator == "!~")
    end

    def initialize(hash)
      super

      raise ArgumentError, "Invalid regexp operator #{@operator}" unless %w{!~ =~}.include?(@operator)
    end
  end
end
