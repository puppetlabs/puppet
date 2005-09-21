#!/usr/local/bin/ruby -w

# $Id$

require 'puppet'

module Puppet
    #------------------------------------------------------------
    class TransObject < Hash
        attr_accessor :type, :name, :file, :line

        def initialize(name,type)
            self[:name] = name
            @type = type
            @name = name
            #self.class.add(self)
        end

        def longname
            return [self.type,self[:name]].join('--')
        end

        def to_s
            return "%s(%s) => %s" % [@type,self[:name],super]
        end

        def to_type
            retobj = nil
            if type = Puppet::Type.type(self.type)
                unless retobj = type.create(self)
                    return nil
                end
                retobj.file = @file
                retobj.line = @line
            else
                raise Puppet::Error.new("Could not find object type %s" % self.type)
            end

            return retobj
        end
    end
    #------------------------------------------------------------

    #------------------------------------------------------------
    # just a linear container for objects
    class TransBucket < Array
        attr_accessor :name, :type, :file, :line

        def push(*args)
            args.each { |arg|
                case arg
                when Puppet::TransBucket, Puppet::TransObject
                    # nada
                else
                    raise "TransBuckets cannot handle objects of type %s" %
                        arg.class
                end
            }
            super
        end

        def to_type
            # this container will contain the equivalent of all objects at
            # this level
            #container = Puppet::Component.new(:name => @name, :type => @type)
            unless defined? @name
                raise Puppet::DevError, "TransBuckets must have names"
            end
            unless defined? @type
                Puppet.debug "TransBucket '%s' has no type" % @name
            end
            hash = {
                :name => @name,
                :type => @type
            }
            if defined? @parameters
                @parameters.each { |param,value|
                    Puppet.debug "Defining %s on %s of type %s" %
                        [param,@name,@type]
                    hash[param] = value
                }
            else
                Puppet.debug "%s has no parameters" % @name
            end
            container = Puppet::Type::Component.create(hash)

            # unless we successfully created the container, return an error
            unless container
                return nil
            end
            nametable = {}

            self.each { |child|
                # the fact that we descend here means that we are
                # always going to execute depth-first
                # which is _probably_ a good thing, but one never knows...
                if child.is_a?(Puppet::TransBucket)
                    # just perform the same operation on any children
                    obj = child.to_type
                    if obj
                        container.push(obj)
                    else
                        # FIXME we need to figure out error handling.
                        # really
                    end
                elsif child.is_a?(Puppet::TransObject)
                    # do a simple little naming hack to see if the object already
                    # exists in our scope
                    # this assumes that type/name combinations are globally
                    # unique

                    # FIXME this still might be wrong, because it doesn't search
                    # up scopes
                    # either that, or it's redundant
                    name = [child[:name],child.type].join("--")

                    if nametable.include?(name)
                        object = nametable[name]
                        child.each { |var,value|
                            # don't rename; this shouldn't be possible anyway
                            next if var == :name

                            Puppet.debug "Adding %s to %s" % [var,name]
                            # override any existing values
                            object[var] = value
                        }
                        object.parent = self
                    else # the object does not exist yet in our scope
                        # now we have the object instantiated, in our scope
                        if object = child.to_type
                            # the object will be nil if it failed
                            nametable[name] = object

                            # this sets the order of the object
                            container.push object
                        end
                    end
                else
                    raise "TransBucket#to_type cannot handle objects of type %s" %
                        child.class
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
