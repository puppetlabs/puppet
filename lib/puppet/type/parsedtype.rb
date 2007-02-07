require 'etc'
require 'facter'
require 'puppet/filetype'
require 'puppet/type/property'

module Puppet
    # The base parameter for all of these types.  Its only job is to copy
    # the 'should' value to the 'is' value and to do support the right logging
    # and such.
    class Property::ParsedParam < Puppet::Property
        # This is the info retrieved from disk.
        attr_accessor :found

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

        def clear
            super
            @found = nil
        end

        # Fix things so that the fields have to match exactly, instead
        # of only kinda
        def insync?
            self.is == self.should
        end

        # Normally this would retrieve the current value, but our property is not
        # actually capable of doing so.  So, we retrieve the whole object and
        # just collect our current state.  Note that this method is not called
        # during a transaction, since transactions call the parent object method.
        def retrieve
            @parent.retrieve
        end

        # All this does is return an event; all of the work gets done
        # in the flush method on the model.
        def sync
            if e = self.class.event(self.should)
                return e
            else
                if self.class.name == :ensure
                    if self.should == :absent
                        return (@parent.class.name.to_s + "_removed").intern
                    else
                        return (@parent.class.name.to_s + "_created").intern
                    end
                else
                    return (@parent.class.name.to_s + "_changed").intern
                end
            end
        end
    end

    # The collection of classes that are just simple records aggregated
    # into a file. See 'host.rb' for an example.
    class Type::ParsedType < Puppet::Type
        @name = :parsedtype

        # Convert the hash to an object.
        def self.hash2obj(hash)
            obj = nil

            namevar = self.namevar
            unless hash.include?(namevar) and hash[namevar]
                raise Puppet::DevError, "Hash was not passed with namevar"
            end

            # if the obj already exists with that name...
            if obj = self[hash[namevar]]
                # We're assuming here that objects with the same name
                # are the same object, which *should* be the case, assuming
                # we've set up our naming stuff correctly everywhere.

                # Mark found objects as present
                obj.is = [:ensure, :present]
                obj.property(:ensure).found = :present
                hash.each { |param, value|
                    if property = obj.property(param)
                        property.is = value
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
                obj = self.create(namevar => hash[namevar])

                # We can't just pass the hash in at object creation time,
                # because it sets the should value, not the is value.
                hash.delete(namevar)
                hash.each { |param, value|
                    obj.is = [param, value]
                }
            end

            return obj
        end

        # Override 'newproperty' so that all properties default to having the
        # correct parent type
        def self.newproperty(name, options = {}, &block)
            options[:parent] ||= Puppet::Property::ParsedParam
            super(name, options, &block)
        end

        def self.list
            ret = suitableprovider.collect do |provider|
                provider.retrieve.find_all { |i| i.is_a? Hash }.collect { |i| hash2obj(i) }
            end.flatten
        end

        def self.listbyname
            suitableprovider.collect do |provider|
                provider.retrieve.find_all { |i| i.is_a? Hash }.collect { |i| i[:name] }
            end.flatten
        end

        # Make sure they've got an explicit :ensure class.
        def self.postinit
            unless validproperty? :ensure
                newproperty(:ensure) do
                    newvalue(:present) do
                        # The value will get flushed appropriately
                        return nil
                    end

                    newvalue(:absent) do
                        # The value will get flushed appropriately
                        return nil
                    end

                    defaultto do
                        if @parent.managed?
                            :present
                        else
                            nil
                        end
                    end
                end
            end
        end

        def exists?
            h = self.retrieve

            if h.nil? or h[:ensure] == :absent
                return false
            else
                return true
            end
        end

        # Flush our content to disk.
        def flush
            provider.store(self.to_hash)
        end

        # Retrieve our current state from our provider
        def retrieve
            if h = provider.hash and ! h.empty?
                h[:ensure] ||= :present

                # If they passed back info we don't have, then mark it to
                # be deleted.
                h.each do |name, value|
                    next unless self.class.validproperty?(name)
                    unless @parameters[name]
                        self.newproperty(name, :should => :absent)
                    end
                end

                properties().each do |property|
                    if h.has_key? property.name
                        property.is = h[property.name]
                    else
                        property.is = :absent
                    end
                end

                return h
            else
                properties().each do |property|
                    property.is = :absent
                end
                return nil
            end
        end
    end
end

# $Id$
