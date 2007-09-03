# A reference to a resource.  Mostly just the type and title.
class Puppet::Parser::Resource::Reference
    include Puppet::Util::MethodHelper
    include Puppet::Util::Errors

    attr_accessor :type, :title, :builtin, :file, :line, :scope

    # Are we a builtin type?
    def builtin?
        unless defined? @builtin
            if builtintype()
                @builtin = true
            else
                @builtin = false
            end
        end

        @builtin
    end

    def builtintype
        if t = Puppet::Type.type(self.type) and t.name != :component
            t
        else
            nil
        end
    end

    # Return the defined type for our obj.  This can return classes,
    # definitions or nodes.
    def definedtype
        unless defined? @definedtype
            type = self.type.to_s.downcase
            name = self.title
            case type
            when "class": # look for host classes
                tmp = @scope.findclass(self.title)
            when "node": # look for node definitions
                tmp = @scope.parser.nodes[self.title]
            else # normal definitions
                # We have to swap these variables around so the errors are right.
                name = type
                type = "type"
                tmp = @scope.finddefine(self.type)
            end

            if tmp
                @definedtype = tmp
            else
                fail Puppet::ParseError, "Could not find resource %s '%s'" % [type, name]
            end
        end

        @definedtype
    end

    def initialize(hash)
        set_options(hash)
        requiredopts(:type, :title)
    end

    def to_ref
        return [type.to_s,title.to_s]
    end

    def to_s
        unless defined? @namestring
            @namestring = "%s[%s]" % [type.capitalize, title]
        end
        @namestring
    end

    def typeclass
        unless defined? @typeclass
            if tmp = builtintype || definedtype
                @typeclass = tmp
            else
                fail Puppet::ParseError, "Could not find type %s" % self.type
            end
        end

        @typeclass
    end
end
