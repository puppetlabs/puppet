# A reference to a resource.  Mostly just the type and title.
require 'puppet/resource/reference'
require 'puppet/file_collection/lookup'
require 'puppet/parser/yaml_trimmer'

# A reference to a resource.  Mostly just the type and title.
class Puppet::Parser::Resource::Reference < Puppet::Resource::Reference
    include Puppet::Parser::YamlTrimmer
    include Puppet::FileCollection::Lookup
    include Puppet::Util::MethodHelper
    include Puppet::Util::Errors

    attr_accessor :builtin, :file, :line, :scope

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
        if t = Puppet::Type.type(self.type.downcase) and t.name != :component
            t
        else
            nil
        end
    end

    # Return the defined type for our obj.  This can return classes,
    # definitions or nodes.
    def definedtype
        unless defined? @definedtype
            case self.type
            when "Class" # look for host classes
                if self.title == :main
                    tmp = @scope.find_hostclass("")
                else
                    unless tmp = @scope.parser.hostclass(self.title)
                        fail Puppet::ParseError, "Could not find class '%s'" % self.title
                    end
                end
            when "Node" # look for node definitions
                unless tmp = @scope.parser.node(self.title)
                    fail Puppet::ParseError, "Could not find node '%s'" % self.title
                end
            else # normal definitions
                # The resource type is capitalized, so we have to downcase.  Really,
                # we should have a better interface for finding these, but eh.
                tmp = @scope.parser.definition(self.type.downcase)
            end

            if tmp
                @definedtype = tmp
            else
                fail Puppet::ParseError, "Could not find resource type '%s'" % self.type
            end
        end

        @definedtype
    end

    def initialize(hash)
        set_options(hash)
        requiredopts(:type, :title)
    end

    def skip_for_yaml
        %w{@typeclass @definedtype}
    end

    def to_ref
        # We have to return different cases to provide backward compatibility
        # from 0.24.x to 0.23.x.
        if builtin?
            return [type.to_s.downcase, title.to_s]
        else
            return [type.to_s, title.to_s]
        end
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
