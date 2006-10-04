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

        self.builtin
    end

    def builtintype
        if t = Puppet::Type.type(self.type) and t.name != :component
            t
        else
            nil
        end
    end

    # Return the defined type for our obj.
    def definedtype
        unless defined? @definedtype
            if tmp = @scope.finddefine(self.type)
                @definedtype = tmp
            else
                fail Puppet::ParseError, "Could not find definition %s" % self.type
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
        "%s[%s]" % [type, title]
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

# $Id$
