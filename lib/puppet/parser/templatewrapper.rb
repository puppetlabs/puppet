# A simple wrapper for templates, so they don't have full access to
# the scope objects.
class Puppet::Parser::TemplateWrapper
    attr_accessor :scope, :file
    include Puppet::Util
    Puppet::Util.logmethods(self)

    def initialize(scope, file)
        @scope = scope
        @file = Puppet::Module::find_template(file, @scope.compiler.environment)

        unless FileTest.exists?(@file)
            raise Puppet::ParseError,
                "Could not find template %s" % file
        end

        # We'll only ever not have a parser in testing, but, eh.
        if @scope.parser
            @scope.parser.watch_file(@file)
        end
    end

    # Should return true if a variable is defined, false if it is not
    def has_variable?(name)
        if @scope.lookupvar(name.to_s, false) != :undefined
            true
        else
            false
        end
    end

    # Ruby treats variables like methods, so we can cheat here and
    # trap missing vars like they were missing methods.
    def method_missing(name, *args)
        # We have to tell lookupvar to return :undefined to us when
        # appropriate; otherwise it converts to "".
        value = @scope.lookupvar(name.to_s, false)
        if value != :undefined
            return value
        else
            # Just throw an error immediately, instead of searching for
            # other missingmethod things or whatever.
            raise Puppet::ParseError,
                "Could not find value for '%s'" % name
        end
    end

    def result
        result = nil
        benchmark(:debug, "Interpolated template #{@file}") do
            template = ERB.new(File.read(@file), 0, "-")
            result = template.result(binding)
        end

        result
    end

    def to_s
        "template[%s]" % @file
    end
end

