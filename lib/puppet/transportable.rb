require 'puppet'
require 'yaml'

module Puppet
    # The transportable objects themselves.  Basically just a hash with some
    # metadata and a few extra methods.  I used to have the object actually
    # be a subclass of Hash, but I could never correctly dump them using
    # YAML.
    class TransObject
        include Enumerable
        attr_accessor :type, :name, :file, :line, :collectable

        attr_writer :tags

        %w{has_key? include? length delete empty? << [] []=}.each { |method|
            define_method(method) do |*args|
                @params.send(method, *args)
            end
        }

        def each
            @params.each { |p,v| yield p, v }
        end

        def initialize(name,type)
            @type = type
            @name = name
            @collectable = false
            @params = {}
            @tags = []
        end

        def longname
            return [@type,@name].join('--')
        end

        def tags
            return @tags
        end

        def to_hash
            @params.dup
        end

        def to_s
            return "%s(%s) => %s" % [@type,@name,super]
        end

        def to_manifest
            "#{self.type.to_s} { \"#{self.name}\":\n%s\n}" % @params.collect { |p, v|
                "    #{p} => \"#{v}\""
            }.join(",\n")
        end

        def to_yaml_properties
            instance_variables
            #%w{ @type @name @file @line @tags }.find_all { |v|
            #}
        end

        def to_type(parent = nil)
            retobj = nil
            if typeklass = Puppet::Type.type(self.type)
                # FIXME This should really be done differently, but...
                if retobj = typeklass[self.name]
                    self.each do |param, val|
                        retobj[param] = val
                    end
                else
                    unless retobj = typeklass.create(self)
                        #Puppet.notice "Could not create %s[%s]" %
                        #    [self.type, self.name]
                        return nil
                    end
                end
                #retobj.file = @file
                #retobj.line = @line
            else
                raise Puppet::Error.new("Could not find object type %s" % self.type)
            end

            if parent
                parent.push retobj
            end

            return retobj
        end
    end

    # Just a linear container for objects.  Behaves mostly like an array, except
    # that YAML will correctly dump them even with their instance variables.
    class TransBucket
        include Enumerable

        attr_accessor :name, :type, :file, :line, :classes, :keyword, :top

        %w{delete shift include? length empty? << []}.each { |method|
            define_method(method) do |*args|
                #Puppet.warning "Calling %s with %s" % [method, args.inspect]
                @children.send(method, *args)
                #Puppet.warning @params.inspect
            end
        }

        # Remove all collectable objects from our tree, since the client
        # should not see them.
        def collectstrip!
            @children.dup.each do |child|
                if child.is_a? self.class
                    child.collectstrip!
                else
                    if child.collectable
                        @children.delete(child)
                    end
                end
            end
        end

        # Recursively yield everything.
        def delve(&block)
            @children.each do |obj|
                block.call(obj)
                if obj.is_a? self.class
                    obj.delve(&block)
                else
                    obj
                end
            end
        end

        def each
            @children.each { |c| yield c }
        end

        # Turn our heirarchy into a flat list
        def flatten
            @children.collect do |obj|
                if obj.is_a? Puppet::TransBucket
                    obj.flatten
                else
                    obj
                end
            end.flatten
        end

        def initialize
            @children = []
        end

        def push(*args)
            args.each { |arg|
                case arg
                when Puppet::TransBucket, Puppet::TransObject
                    # nada
                else
                    raise Puppet::DevError,
                        "TransBuckets cannot handle objects of type %s" %
                            arg.class
                end
            }
            @children += args
        end

        # Convert to a parseable manifest
        def to_manifest
            unless self.top
                unless defined? @keyword and @keyword
                    raise Puppet::DevError, "No keyword; cannot convert to manifest"
                end
            end

            str = nil
            if self.top
                str = "%s"
            else
                str = "#{@keyword} #{@type} {\n%s\n}"
            end
            str % @children.collect { |child|
                child.to_manifest
            }.collect { |str|
                if self.top
                    str
                else
                    str.gsub(/^/, "    ") # indent everything once
                end
            }.join("\n\n") # and throw in a blank line
        end

        def to_yaml_properties
            instance_variables
        end

        def to_type(parent = nil)
            # this container will contain the equivalent of all objects at
            # this level
            #container = Puppet::Component.new(:name => @name, :type => @type)
            #unless defined? @name
            #    raise Puppet::DevError, "TransBuckets must have names"
            #end
            unless defined? @type
                Puppet.debug "TransBucket '%s' has no type" % @name
            end
            usetrans = true

            if usetrans
                tmpname = nil

                # Nodes have the same name and type
                if self.name
                    tmpname = "%s[%s]" % [@type, self.name]
                else
                    tmpname = @type
                end
                trans = TransObject.new(tmpname, :component)
                if defined? @parameters
                    @parameters.each { |param,value|
                        Puppet.debug "Defining %s on %s of type %s" %
                            [param,@name,@type]
                        trans[param] = value
                    }
                else
                    #Puppet.debug "%s[%s] has no parameters" % [@type, @name]
                end
                container = Puppet.type(:component).create(trans)

                if parent
                    container.parent = parent
                    #Puppet.warning "parent is of type %s" % parent.class
                    #trans[:parent] = parent
                end
            else
                hash = {
                    :name => self.name,
                    :type => @type
                }
                if defined? @parameters
                    @parameters.each { |param,value|
                        Puppet.debug "Defining %s on %s of type %s" %
                            [param,@name,@type]
                        hash[param] = value
                    }
                else
                    #Puppet.debug "%s[%s] has no parameters" % [@type, @name]
                end

                if parent
                    hash[:parent] = parent
                end
                container = Puppet.type(:component).create(hash)
            end
            #Puppet.info container.inspect

            if parent
                parent.push container
            end

            # unless we successfully created the container, return an error
            unless container
                Puppet.warning "Got no container back"
                return nil
            end

            self.each { |child|
                # the fact that we descend here means that we are
                # always going to execute depth-first
                # which is _probably_ a good thing, but one never knows...
                unless  child.is_a?(Puppet::TransBucket) or
                        child.is_a?(Puppet::TransObject)
                    raise Puppet::DevError,
                        "TransBucket#to_type cannot handle objects of type %s" %
                            child.class
                end

                # Now just call to_type on them with the container as a parent
                unless obj = child.to_type(container)
                    # nothing; we assume the method already warned
                    #Puppet.warning "Could not create child %s" % child.name
                end
            }

            # at this point, no objects at are level are still Transportable
            # objects
            return container
        end

        def param(param,value)
            unless defined? @parameters
                @parameters = {}
            end
            @parameters[param] = value
        end

    end
    #------------------------------------------------------------
end

# $Id$
