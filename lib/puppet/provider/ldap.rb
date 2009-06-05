require 'puppet/provider'

# The base class for LDAP providers.
class Puppet::Provider::Ldap < Puppet::Provider
    require 'puppet/util/ldap/manager'

    class << self
        attr_reader :manager
    end

    # Look up all instances at our location.  Yay.
    def self.instances
        return [] unless list = manager.search

        list.collect { |entry| new(entry) }
    end

    # Specify the ldap manager for this provider, which is
    # used to figure out how we actually interact with ldap.
    def self.manages(*args)
        @manager = Puppet::Util::Ldap::Manager.new
        @manager.manages(*args)

        # Set up our getter/setter methods.
        mk_resource_methods
        return @manager
    end

    # Query all of our resources from ldap.
    def self.prefetch(resources)
        resources.each do |name, resource|
            if result = manager.find(name)
                result[:ensure] = :present
                resource.provider = new(result)
            else
                resource.provider = new(:ensure => :absent)
            end
        end
    end

    def manager
        self.class.manager
    end

    def create
        @property_hash[:ensure] = :present
        self.class.resource_type.validproperties.each do |property|
            if val = resource.should(property)
                @property_hash[property] = val
            end
        end
    end

    def delete
        @property_hash[:ensure] = :absent
    end

    def exists?
        @property_hash[:ensure] != :absent
    end

    # Apply our changes to ldap, yo.
    def flush
        # Just call the manager's update() method.
        @property_hash.delete(:groups)
        @ldap_properties.delete(:groups)
        manager.update(name, ldap_properties, properties)
        @property_hash.clear
        @ldap_properties.clear
    end

    def initialize(*args)
        raise(Puppet::DevError, "No LDAP Configuration defined for %s" % self.class) unless self.class.manager
        raise(Puppet::DevError, "Invalid LDAP Configuration defined for %s" % self.class) unless self.class.manager.valid?
        super

        @property_hash = @property_hash.inject({}) do |result, ary|
            param, values = ary

            # Skip any attributes we don't manage.
            next result unless self.class.resource_type.validattr?(param)

            paramclass = self.class.resource_type.attrclass(param)

            unless values.is_a?(Array)
                result[param] = values
                next result
            end

            # Only use the first value if the attribute class doesn't manage
            # arrays of values.
            if paramclass.superclass == Puppet::Parameter or paramclass.array_matching == :first
                result[param] = values[0]
            else
                result[param] = values
            end
            result
        end

        # Make a duplicate, so that we have a copy for comparison
        # at the end.
        @ldap_properties = @property_hash.dup
    end

    # Return the current state of ldap.
    def ldap_properties
        @ldap_properties.dup
    end

    # Return (and look up if necessary) the desired state.
    def properties
        if @property_hash.empty?
            @property_hash = query || {:ensure => :absent}
            if @property_hash.empty?
                @property_hash[:ensure] = :absent
            end
        end
        @property_hash.dup
    end

    # Collect the current attributes from ldap.  Returns
    # the results, but also stores the attributes locally,
    # so we have something to compare against when we update.
    # LAK:NOTE This is normally not used, because we rely on prefetching.
    def query
        # Use the module function.
        unless attributes = manager.find(name)
            @ldap_properties = {}
            return nil
        end

        @ldap_properties = attributes
        return @ldap_properties.dup
    end
end
