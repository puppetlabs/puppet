#
# Common code for AIX providers
#
# Author::    Hector Rivas Gandara <keymon@gmail.com>
#
#  
class Puppet::Provider::AixObject < Puppet::Provider
  desc "User management for AIX! Users are managed with mkuser, rmuser, chuser, lsuser"

  # Constants
  # Loadable AIX I/A module for users and groups. By default we manage compat.
  # TODO:: add a type parameter to change this
  class << self 
    attr_accessor :ia_module
  end
  
   
  # AIX attributes to properties mapping. Subclasses should rewrite them
  # It is a list with of hash
  #  :aix_attr      AIX command attribute name
  #  :puppet_prop   Puppet propertie name
  #  :to            Method to adapt puppet property to aix command value. Optional.
  #  :from            Method to adapt aix command value to puppet property. Optional
  class << self
    attr_accessor :attribute_mapping
  end

  # Provider must implement these functions.
  def lscmd(value=@resource[:name])
    raise Puppet::Error, "Method not defined #{@resource.class.name} #{@resource.name}: #{detail}"
  end

  def addcmd(extra_attrs = [])
    raise Puppet::Error, "Method not defined #{@resource.class.name} #{@resource.name}: #{detail}"
  end

  def modifycmd(attributes_hash)
    raise Puppet::Error, "Method not defined #{@resource.class.name} #{@resource.name}: #{detail}"
  end

  def deletecmd
    raise Puppet::Error, "Method not defined #{@resource.class.name} #{@resource.name}: #{detail}"
  end

  # attribute_mapping class variable, 
  class << self 
    attr_accessor :attribute_mapping
  end
  def self.attribute_mapping_to
    if ! @attribute_mapping_to
      @attribute_mapping_to = {}
      attribute_mapping.each { |elem|
        attribute_mapping_to[elem[:puppet_prop]] = {
          :key => elem[:aix_attr],
          :method => elem[:to]
        }
      }
    end
    @attribute_mapping_to
  end    
  def self.attribute_mapping_from
    if ! @attribute_mapping_from
      @attribute_mapping_from = {}
      attribute_mapping.each { |elem|
        attribute_mapping_from[elem[:aix_attr]] = {
          :key => elem[:puppet_prop],
          :method => elem[:from]
        }
      }
    end
    @attribute_mapping_from
  end

  # This functions translates a key and value using the given mapping.
  # Mapping can be nil (no translation) or a hash with this format
  # {:key => new_key, :method => translate_method}
  # It returns a list [key, value]
  def self.translate_attr(key, value, mapping)
    return [key, value] unless mapping
    return nil unless mapping[key]
    
    if mapping[key][:method]
      new_value = method(mapping[key][:method]).call(value)
    else
      new_value = value
    end
    [mapping[key][:key], new_value]
  end
  
  #-----
  # Convert a pair key-value using the 
  
  # Parse AIX command attributes (string) and return provider hash
  # If a mapping is provided, the keys are translated as defined in the
  # mapping hash. Only values included in mapping will be added
  # NOTE: it will ignore the items not including '='
  def self.attr2hash(str, mapping=attribute_mapping_from)
    properties = {}
    attrs = []
    if !str or (attrs = str.split()[0..-1]).empty?
      return nil
    end 

    attrs.each { |i|
      if i.include? "=" # Ignore if it does not include '='
        (key_str, val) = i.split('=')
        # Check the key
        if !key_str or key_str.empty?
          info "Empty key in string 'i'?"
          continue
        end
        key = key_str.to_sym
       
        if ret = self.translate_attr(key, val, mapping)
          new_key = ret[0]
          new_val = ret[1]
          
          properties[new_key] = new_val
        end
      end
    }
    properties.empty? ? nil : properties
  end

  # Convert the provider properties to AIX command attributes (string)
  def self.hash2attr(hash, mapping=attribute_mapping_to)
    return "" unless hash 
    attr_list = []
    hash.each {|key, val|
      
      if ret = self.translate_attr(key, val, mapping)
        new_key = ret[0]
        new_val = ret[1]
        
        # Arrays are separated by commas
        if new_val.is_a? Array
          value = new_val.join(",")
        else
          value = new_val.to_s
        end
        
        attr_list << (new_key.to_s + "=" + value )
      end
    }
    attr_list
  end

  # Retrieve what we can about our object
  def getinfo(refresh = false)
    if @objectinfo.nil? or refresh == true
      # Execute lsuser, split all attributes and add them to a dict.
      begin
        attrs = execute(self.lscmd).split("\n")[0]
        @objectinfo = self.class.attr2hash(attrs)
      rescue Puppet::ExecutionFailure => detail
        # Print error if needed
        Puppet.debug "aix.getinfo(): Could not find #{@resource.class.name} #{@resource.name}: #{detail}" \
          unless detail.to_s.include? "User \"#{@resource.name}\" does not exist."
      end
    end
    @objectinfo
  end

  #-------------
  # Provider API
  # ------------
 
  # Clear out the cached values.
  def flush
    @property_hash.clear if @property_hash
    @object_info.clear if @object_info
  end

  # Check that the user exists
  def exists?
    !!getinfo(true) # !! => converts to bool
  end

  #- **ensure**
  #    The basic state that the object should be in.  Valid values are
  #    `present`, `absent`, `role`.
  # From ensurable: exists?, create, delete
  def ensure
    if exists?
      :present
    else
      :absent
    end
  end

  # Return all existing instances  
  # The method for returning a list of provider instances.  Note that it returns
  # providers, preferably with values already filled in, not resources.
  def self.instances
    objects = []
    execute(lscmd("ALL")).each { |entry|
      objects << new(:name => entry.split(" ")[0], :ensure => :present)
    }
    objects
  end

  def create
    if exists?
      info "already exists"
      # The object already exists
      return nil
    end

    begin
      execute(self.addcmd)
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not create #{@resource.class.name} #{@resource.name}: #{detail}"
    end
  end 

  def delete
    unless exists?
      info "already absent"
      # the object already doesn't exist
      return nil
    end

    begin
      execute(self.deletecmd)
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not delete #{@resource.class.name} #{@resource.name}: #{detail}"
    end
  end

  #--------------------------------
  # Call this method when the object is initialized, 
  # create getter/setter methods for each property our resource type supports.
  # If setter or getter already defined it will not be overwritten
  def self.mk_resource_methods
    [resource_type.validproperties, resource_type.parameters].flatten.each do |prop|
      next if prop == :ensure
      define_method(prop) { get(prop) || :absent} unless public_method_defined?(prop)
      define_method(prop.to_s + "=") { |*vals| set(prop, *vals) } unless public_method_defined?(prop.to_s + "=")
    end
  end
  #

  # Define the needed getters and setters as soon as we know the resource type
  def self.resource_type=(resource_type)
    super
    mk_resource_methods
  end
  
  # Retrieve a specific value by name.
  def get(param)
    (hash = getinfo(false)) ? hash[param] : nil
  end

  # Set a property.
  def set(param, value)
    @property_hash[symbolize(param)] = value
    # If value does not change, do not update.    
    if value == getinfo()[param.to_sym]
      return
    end
    
    #self.class.validate(param, value)
    cmd = modifycmd({param => value})
    begin
      execute(cmd)
    rescue Puppet::ExecutionFailure  => detail
      raise Puppet::Error, "Could not set #{param} on #{@resource.class.name}[#{@resource.name}]: #{detail}"
    end
    
    # Refresh de info.  
    hash = getinfo(true)
  end
 
  def initialize(resource)
    super
    @objectinfo = nil
    # FIXME: Initiallize this properly.
    self.class.ia_module="compat"
  end  

end
#end
