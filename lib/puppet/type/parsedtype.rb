require 'etc'
require 'facter'
require 'puppet/filetype'
require 'puppet/type/state'

module Puppet
    class State
        # The base parameter for all of these types.  Its only job is to copy
        # the 'should' value to the 'is' value and to do support the right logging
        # and such.
        class ParsedParam < Puppet::State
            def self.isoptional
                @isoptional = true
            end

            def self.isoptional?
                if defined? @isoptional
                    return @isoptional
                else
                    return false
                end
            end

            # By default, support ':absent' as a value for optional
            # parameters.  Any parameters that define their own validation
            # need to do this manuallly.
            validate do |value|
                if self.class.isoptional? and (
                    value == "absent" or value == :absent
                )
                    return :absent
                else
                    return value
                end
            end

            # Fix things so that the fields have to match exactly, instead
            # of only kinda
            def insync?
                self.is == self.should
            end

            # Normally this would retrieve the current value, but our state is not
            # actually capable of doing so.
            def retrieve
                # If we've synced, then just copy the values over and return.
                # This allows this state to behave like any other state.
                if defined? @synced and @synced
                    # by default, we only copy over the first value.
                    @is = @synced
                    @synced = false
                    return
                end

                unless defined? @is and ! @is.nil?
                    @is = :absent
                end
            end

            # If the ensure state is out of sync, it will always be called
            # first, so I don't need to worry about that.
            def sync(nostore = false)
                ebase = @parent.class.name.to_s

                tail = nil
                if self.class.name == :ensure
                    # We're either creating or destroying the object
                    if @is == :absent
                        #@is = self.should
                        tail = "created"

                        # If we're creating it, then sync all of the other states
                        # but tell them not to store (we'll store just once,
                        # at the end).
                        unless nostore
                            @parent.eachstate { |state|
                                next if state == self or state.name == :ensure
                                state.sync(true)
                            }
                        end
                    elsif self.should == :absent
                        @parent.remove(true)
                        tail = "deleted"
                    end
                else
                    # We don't do the work here, it gets done in 'store'
                    tail = "changed"
                end
                @synced = self.should

                # This should really only be done once per run, rather than
                # every time.  I guess we need some kind of 'flush' mechanism.
                if nostore
                    self.retrieve
                else
                    @parent.store
                end
                
                return (ebase + "_" + tail).intern
            end
        end
    end

    class Type
        # The collection of classes that are just simple records aggregated
        # into a file. See 'host.rb' for an example.
        class ParsedType < Puppet::Type
            @name = :parsedtype
            class << self
                attr_accessor :filetype, :hostfile, :fileobj, :fields, :path
            end

            # Override 'newstate' so that all states default to having the
            # correct parent type
            def self.newstate(name, parent = nil, &block)
                parent ||= Puppet::State::ParsedParam
                super(name, parent, &block)
            end

            # Add another type var.
            def self.initvars
                @instances = []
                super
            end

            # Override the Puppet::Type#[]= method so that we can store the
            # instances in per-user arrays.  Then just call +super+.
            def self.[]=(name, object)
                self.instance(object)
                super
            end

            # In addition to removing the instances in @objects, we have to remove
            # per-user host tab information.
            def self.clear
                @instances = []
                @fileobj = nil
                super
            end

            # Override the default Puppet::Type method, because instances
            # also need to be deleted from the @instances hash
            def self.delete(child)
                if @instances.include?(child)
                    @instances.delete(child)
                end
                super
            end

            # Return the header placed at the top of each generated file, warning
            # users that modifying this file manually is probably a bad idea.
            def self.header
%{# HEADER: This file was autogenerated at #{Time.now}
# HEADER: by puppet.  While it can still be managed manually, it
# HEADER: is definitely not recommended.\n}
            end

            # Store a new instance of a host.  Called from Host#initialize.
            def self.instance(obj)
                unless @instances.include?(obj)
                    @instances << obj
                end
            end

            # Parse a file
            #
            # Subclasses must override this method.
            def self.parse(text)
                raise Puppet::DevError, "Parse was not overridden in %s" %
                    self.name
            end

            # Convert the hash to an object.
            def self.hash2obj(hash)
                obj = nil

                unless hash.include?(:name) and hash[:name]
                    raise Puppet::DevError, "Hash was not passed with name"
                end

                # if the obj already exists with that name...
                if obj = self[hash[:name]]
                    # We're assuming here that objects with the same name
                    # are the same object, which *should* be the case, assuming
                    # we've set up our naming stuff correctly everywhere.

                    # Mark found objects as present
                    obj.is = [:ensure, :present]
                    hash.each { |param, value|
                        if state = obj.state(param)
                            state.is = value
                        elsif val = obj[param]
                            obj[param] = val
                        else
                            # There is a value on disk, but it should go away
                            obj.is = [param, value]
                            obj[param] = :absent
                        end
                    }
                else
                    # create a new obj, since no existing one seems to
                    # match
                    obj = self.create(:name => hash[:name])

                    # We can't just pass the hash in at object creation time,
                    # because it sets the should value, not the is value.
                    hash.delete(:name)
                    hash.each { |param, value|
                        obj.is = [param, value]
                    }
                end
            end

            # Retrieve the text for the file. Returns nil in the unlikely
            # event that it doesn't exist.
            def self.retrieve
                @fileobj ||= @filetype.new(@path)
                text = @fileobj.read
                if text.nil? or text == ""
                    # there is no host file
                    return nil
                else
                    # First we mark all of our objects absent; any objects
                    # subsequently found will be marked present
                    self.each { |obj|
                        obj.each { |state|
                            state.is = :absent
                        }
                    }
                    self.parse(text)
                end
            end

            # Write out the file.
            def self.store
                @fileobj ||= @filetype.new(@path)

                if @instances.empty?
                    Puppet.notice "No %s instances for %s" % [self.name, @path]
                else
                    @fileobj.write(self.to_file())
                end
            end

            # Collect all Host instances convert them into literal text.
            def self.to_file
                str = self.header()
                unless @instances.empty?
                    str += @instances.reject { |obj|
                        # Don't write out objects that should be absent
                        if obj.is_a?(self)
                            if obj.should(:ensure) == :absent
                                true
                            end
                        end
                    }.collect { |obj|
                        if obj.is_a?(self)
                            obj.to_record
                        else
                            obj.to_s
                        end
                    }.join("\n") + "\n"

                    return str
                else
                    Puppet.notice "No %s instances" % self.name
                    return ""
                end
            end

            # Return the last time the hosts file was loaded.  Could
            # be used for reducing writes, but currently is not.
            def self.loaded?(user)
                @fileobj ||= @filetype.new(@path)
                @fileobj.loaded
            end

            def create
                self[:ensure] = :present
                self.store
            end

            # hash2obj marks the 'ensure' state as present
            def exists?
                @states.include?(:ensure) and @states[:ensure].is == :present
            end

            def destroy
                self[:ensure] = :absent
                self.store
            end

            # Override the default Puppet::Type method because we need to call
            # the +@filetype+ retrieve method.
            def retrieve
                self.class.retrieve()

                self.eachstate { |st| st.retrieve }
            end

            # Write the entire host file out.
            def store
                self.class.store()
            end

            def value(name)
                unless name.is_a? Symbol
                    name = name.intern
                end
                if @states.include? name
                    val = @states[name].value
                    if val == :absent
                        return nil
                    else
                        return val
                    end
                elsif @parameters.include? name
                    return @parameters[name].value
                else
                    return nil
                end
            end
        end
    end
end

require 'puppet/type/parsedtype/host'
require 'puppet/type/parsedtype/port'

# $Id$
