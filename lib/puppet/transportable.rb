#!/usr/local/bin/ruby -w

# $Id$

require 'puppet'

module Puppet
    #------------------------------------------------------------
    class TransObject < Hash
        attr_accessor :type

        @@ohash = {}
        @@oarray = []

        def TransObject.add(object)
            @@oarray.push object

            # this is just so we can check, at parse time, whether a required
            # object has already been mentioned when it is listed as required
            # because we're ordered, as long as an object gets made before its
            # dependent objects will get synced later
            @@ohash[object.longname] = object
        end

        def TransObject.clear
            @@oarray.clear
        end

        def TransObject.list
            return @@oarray
        end

        def initialize(name,type)
            self[:name] = name
            @type = type
            self.class.add(self)
        end

        def longname
            return [self.type,self[:name]].join('--')
        end

        def name
            return self[:name]
        end

        def to_s
            return "%s(%s) => %s" % [@type,self[:name],super]
        end

        def to_type
            retobj = nil
            if type = Puppet::Type.type(self.type)
                #begin
                    # this will fail if the type already exists
                    # which may or may not be a good thing...
                    retobj = type.new(self)
                #rescue => detail
                #    Puppet.err "Failed to create %s: %s" % [type.name,detail]
                #    puts self.class
                #    puts self.inspect
                #    exit
                #end
            else
                raise "Could not find object type %s" % self.type
            end

            return retobj
        end
    end
    #------------------------------------------------------------

    #------------------------------------------------------------
    class TransSetting
        attr_accessor :type, :name, :args, :evalcount

        def initialize
            @evalcount = 0
        end

        def evaluate
            @evalcount += 0
            if type = Puppet::Type.type(self.type)
                # call the settings
                name = self.name
                unless name.is_a?(Symbol)
                    name = name.intern
                end
                if type.allowedmethod(name)
                    type.send(self.name,self.args)
                else
                    Puppet.err("%s does not respond to %s" % [self.type,self.name])
                end
            else
                raise "Could not find object type %s" % setting.type
            end
        end
    end
    #------------------------------------------------------------

    #------------------------------------------------------------
    # just a linear container for objects
    class TransBucket < Array
        attr_accessor :name, :type

        def push(*args)
            args.each { |arg|
                case arg
                when Puppet::TransBucket, Puppet::TransObject, Puppet::TransSetting
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
                raise "TransBuckets must have names"
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
            container = Puppet::Component.new(hash)
            nametable = {}

            self.each { |child|
                # the fact that we descend here means that we are
                # always going to execute depth-first
                # which is _probably_ a good thing, but one never knows...
                if child.is_a?(Puppet::TransBucket)
                    # just perform the same operation on any children
                    container.push(child.to_type)
                elsif child.is_a?(Puppet::TransSetting)
                    # XXX this is wrong, but for now just evaluate the settings
                    child.evaluate
                elsif child.is_a?(Puppet::TransObject)
                    # do a simple little naming hack to see if the object already
                    # exists in our scope
                    # this assumes that type/name combinations are globally
                    # unique
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
                    else # the object does not exist yet in our scope
                        # now we have the object instantiated, in our scope
                        object = child.to_type
                        nametable[name] = object

                        # this sets the order of the object
                        container.push object
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
