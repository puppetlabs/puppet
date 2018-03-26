require 'puppet/util/autoload'
require 'puppet/util'

# A module that can easily autoload things for us.  Uses an instance
# of Puppet::Util::Autoload
module Puppet::Util::InstanceLoader
  include Puppet::Util

  # Are we instance-loading this type?
  def instance_loading?(type)
    defined?(@autoloaders) and @autoloaders.include?(type.intern)
  end

  # Define a new type of autoloading.
  def instance_load(type, path, options = {})
    @autoloaders ||= {}
    @instances ||= {}
    type = type.intern
    @instances[type] = {}
    @autoloaders[type] = Puppet::Util::Autoload.new(self, path, options)

    # Now define our new simple methods
    unless respond_to?(type)
      meta_def(type) do |name|
        loaded_instance(type, name)
      end
    end
  end

  # Return a list of the names of all instances
  def loaded_instances(type)
    @instances[type].keys
  end

  # Collect the docs for all of our instances.
  def instance_docs(type)
    docs = ""

    # Load all instances.
    instance_loader(type).loadall

    # Use this method so they all get loaded
    loaded_instances(type).sort { |a,b| a.to_s <=> b.to_s }.each do |name|
      mod = self.loaded_instance(type, name)
      docs << "#{name}\n#{"-" * name.to_s.length}\n"

      docs << Puppet::Util::Docs.scrub(mod.doc) << "\n\n"
    end

    docs
  end

  # Return the instance hash for our type.
  def instance_hash(type)
    @instances[type.intern]
  end

  # Return the Autoload object for a given type.
  def instance_loader(type)
    @autoloaders[type.intern]
  end

  # Retrieve an already-loaded instance, or attempt to load our instance.
  def loaded_instance(type, name)
    name = name.intern
    return nil unless instances = instance_hash(type)
    unless instances.include? name
      if instance_loader(type).load(name)
        unless instances.include? name
          Puppet.warning(_("Loaded %{type} file for %{name} but %{type} was not defined") % { type: type, name: name })
          return nil
        end
      else
        return nil
      end
    end
    instances[name]
  end
end
