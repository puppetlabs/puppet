require 'puppet'
require 'puppet/parser/ast/branch'
require 'puppet/parser/collector'

# An object that collects stored objects from the central cache and returns
# them to the current host, yo.
class Puppet::Parser::AST
class CollExpr < AST::Branch
    attr_accessor :test1, :test2, :oper, :form, :type, :parens

    # We return an object that does a late-binding evaluation.
    def evaluate(scope)
        # Make sure our contained expressions have all the info they need.
        [@test1, @test2].each do |t|
            if t.is_a?(self.class)
                t.form ||= self.form
                t.type ||= self.type
            end
        end

        # The code is only used for virtual lookups
        str1, code1 = @test1.safeevaluate scope
        str2, code2 = @test2.safeevaluate scope

        # First build up the virtual code.
        # If we're a conjunction operator, then we're calling code.  I did
        # some speed comparisons, and it's at least twice as fast doing these
        # case statements as doing an eval here.
        code = proc do |resource|
            case @oper
            when "and"; code1.call(resource) and code2.call(resource)
            when "or"; code1.call(resource) or code2.call(resource)
            when "=="
                if str1 == "tag"
                    resource.tagged?(str2)
                else
                    if resource[str1].is_a?(Array)
                        resource[str1].include?(str2)
                    else
                        resource[str1] == str2
                    end
                end
            when "!="; resource[str1] != str2
            end
        end

        # Now build up the rails conditions code
        if self.parens and self.form == :exported
            Puppet.warning "Parentheses are ignored in Rails searches"
        end

        case @oper
        when "and", "or"
            if form == :exported
                raise Puppet::ParseError, "Puppet does not currently support collecting exported resources with more than one condition"
            end
            oper = @oper.upcase
        when "=="; oper = "="
        else
            oper = @oper
        end

        if oper == "=" or oper == "!="
            # Add the rails association info where necessary
            case str1
            when "title"
                str = "title #{oper} '#{str2}'"
            when "tag"
                str = "puppet_tags.name #{oper} '#{str2}'"
            else
                str = "param_values.value #{oper} '#{str2}' and " +
                    "param_names.name = '#{str1}'"
            end
        else
            str = "(%s) %s (%s)" % [str1, oper, str2]
        end

        return str, code
    end

    def initialize(hash = {})
        super

        unless %w{== != and or}.include?(@oper)
            raise ArgumentError, "Invalid operator %s" % @oper
        end
    end
end
end
