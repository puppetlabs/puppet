# A simple wrapper for templates, so they don't have full access to
# the scope objects.
require 'puppet/parser/files'

class Puppet::Parser::TemplateWrapper
    attr_writer :scope
    attr_reader :file
    attr_accessor :string
    include Puppet::Util
    Puppet::Util.logmethods(self)

    def initialize(scope)
        @__scope__ = scope
    end

    def scope
        @__scope__
    end

    # Should return true if a variable is defined, false if it is not
    def has_variable?(name)
        if scope.lookupvar(name.to_s, false) != :undefined
            true
        else
            false
        end
    end

    # Allow templates to access the defined classes
    def classes
        return scope.catalog.classes
    end

    # Allow templates to access the tags defined in the current scope
    def tags
        return scope.tags
    end

    # Allow templates to access the all the defined tags
    def all_tags
        return scope.catalog.tags
    end

    # Ruby treats variables like methods, so we used to expose variables
    # within scope to the ERB code via method_missing.  As per RedMine #1427,
    # though, this means that conflicts between methods in our inheritance
    # tree (Kernel#fork) and variable names (fork => "yes/no") could arise.
    #
    # Worse, /new/ conflicts could pop up when a new kernel or object method
    # was added to Ruby, causing templates to suddenly fail mysteriously when
    # Ruby was upgraded.
    #
    # To ensure that legacy templates using unqualified names work we retain
    # the missing_method definition here until we declare the syntax finally
    # dead.
    def method_missing(name, *args)
        # We have to tell lookupvar to return :undefined to us when
        # appropriate; otherwise it converts to "".
        value = scope.lookupvar(name.to_s, false)
        if value != :undefined
            return value
        else
            # Just throw an error immediately, instead of searching for
            # other missingmethod things or whatever.
            raise Puppet::ParseError, "Could not find value for '%s'" % name
        end
    end

    def file=(filename)
        unless @file = Puppet::Parser::Files.find_template(filename, scope.compiler.environment)
            raise Puppet::ParseError, "Could not find template '%s'" % filename
        end

        # We'll only ever not have a parser in testing, but, eh.
        if scope.parser
            scope.parser.watch_file(file)
        end

        @string = File.read(file)
    end

    def result(string = nil)
        if string
            self.string = string
            template_source = "inline template"
        else
            template_source = file
        end

        # Expose all the variables in our scope as instance variables of the
        # current object, making it possible to access them without conflict
        # to the regular methods.
        benchmark(:debug, "Bound template variables for #{template_source}") do
            scope.to_hash.each { |name, value|
                if name.kind_of?(String)
                    realname = name.gsub(/[^\w]/, "_")
                else
                    realname = name
                end
                instance_variable_set("@#{realname}", value)
            }
        end

        result = nil
        benchmark(:debug, "Interpolated template #{template_source}") do
            template = ERB.new(self.string, 0, "-")
            result = template.result(binding)
        end

        result
    end

    def to_s
        "template[%s]" % (file ? file : "inline")
    end
end
