#  Created by Luke Kanies on 2006-12-12.
#  Copyright (c) 2006. All rights reserved.

require 'puppet'

Puppet::Type.newtype(:resources) do
    @doc = "This is a metatype that can manage other resource types.  Any
        metaparams specified here will be passed on to any generated resources,
        so you can purge umanaged resources but set ``noop`` to true so the
        purging is only logged and does not actually happen."
    
    
    newparam(:name) do
        desc "The name of the type to be managed."
        
        validate do |name|
            unless Puppet::Type.type(name)
                raise ArgumentError, "Could not find resource type '%s'" % name
            end
        end
    end
    
    newparam(:purge, :boolean => true) do
        desc "Purge unmanaged resources.  This will delete any resource
            that is not specified in your configuration
            and is not required by any specified resources."
            
        newvalues(:true, :false)
        
        validate do |value|
            if [:true, true, "true"].include?(value)
                unless @parent.resource_type.respond_to?(:list)
                    raise ArgumentError, "Purging resources of type %s is not supported" % @parent[:name]
                end
                unless @parent.resource_type.validstate?(:ensure)
                    raise ArgumentError, "Purging is only supported on types that accept 'ensure'"
                end
            end
        end
    end
    
    # Generate any new resources we need to manage.
    def generate
        resource_type.list.find_all do |resource|
            ! resource.managed?
        end.each do |resource|
            begin
                resource[:ensure] = :absent
            rescue ArgumentError, Parse::Error => detail
                err "The 'ensure' attribute on %s resources does not accept 'absent' as a value" %
                    [self[:name]]
                return []
            end
        end
    end
    
    def resource_type
        unless defined? @resource_type
            unless type = Puppet::Type.type(self[:name])
                raise Puppet::DevError, "Could not find resource type"
            end
            @resource_type = type
        end
        @resource_type
    end
end

# $Id$