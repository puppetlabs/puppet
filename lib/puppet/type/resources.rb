require 'puppet'
require 'puppet/parameter/boolean'

Puppet::Type.newtype(:resources) do
  @doc = "This is a metatype that can manage other resource types.  Any
    metaparams specified here will be passed on to any generated resources,
    so you can purge umanaged resources but set `noop` to true so the
    purging is only logged and does not actually happen."

  # Make sure all types are loaded first
  Puppet::Type.loadall
  Puppet::Type.eachtype do |type|
    resources_params = type.resources_params || {}
    resources_params.each do |n, h|
      b = h[:block]
      newparam(n, h[:options], &b) unless parameters.include? n
    end
  end

  newparam(:name) do
    desc "The name of the type to be managed."

    validate do |name|
      raise ArgumentError, "Could not find resource type '#{name}'" unless Puppet::Type.type(name)
    end

    munge { |v| v.to_s }
  end

  newparam(:purge, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "Whether to purge unmanaged resources.  When set to `true`, this will
      delete any resource that is not specified in your configuration and is not
      autorequired by any managed resources. **Note:** The `ssh_authorized_key`
      resource type can't be purged this way; instead, see the `purge_ssh_keys`
      attribute of the `user` type."

    defaultto :false

    validate do |value|
      if munge(value)
        unless @resource.resource_type.respond_to?(:instances)
          raise ArgumentError, "Purging resources of type #{@resource[:name]} is not supported, since they cannot be queried from the system"
        end
        raise ArgumentError, "Purging is only supported on types that accept 'ensure'" unless @resource.resource_type.validproperty?(:ensure)
      end
    end
  end

  def check(resource)
    t = Puppet::Type.type(self[:name].to_s)
    @checkmethod ||= "#{self[:name]}_check"
    @hascheck ||= t.respond_to?(@checkmethod)
    if @hascheck
      return t.send(@checkmethod, resource, self)
    else
      return true
    end
  end

  def able_to_ensure_absent?(resource)
      resource[:ensure] = :absent
  rescue ArgumentError, Puppet::Error
      err "The 'ensure' attribute on #{self[:name]} resources does not accept 'absent' as a value"
      false
  end

  # Generate any new resources we need to manage.  This is pretty hackish
  # right now, because it only supports purging.
  def generate
    return [] unless self.purge?
    resource_type.instances.
      reject { |r| catalog.resource_refs.include? r.ref }.
      select { |r| check(r) }.
      select { |r| r.class.validproperty?(:ensure) }.
      select { |r| able_to_ensure_absent?(r) }.
      each { |resource|
        @parameters.each do |name, param|
          resource[name] = param.value if param.metaparam?
        end

        # Mark that we're purging, so transactions can handle relationships
        # correctly
        resource.purging
      }
  end

  def resource_type
    unless defined?(@resource_type)
      unless type = Puppet::Type.type(self[:name])
        raise Puppet::DevError, "Could not find resource type"
      end
      @resource_type = type
    end
    @resource_type
  end

end
