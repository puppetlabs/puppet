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

  # The real provider must implement these functions.
  def lscmd(value=@resource[:name])
    raise Puppet::Error, "Method not defined #{@resource.class.name} #{@resource.name}: #{detail}"
  end

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


  # Valid attributes to be managed by this provider.
  # It is a list of hashes
  #  :aix_attr      AIX command attribute name
  #  :puppet_prop   Puppet propertie name
  #  :to            Optional. Method name that adapts puppet property to aix command value. 
  #  :from          Optional. Method to adapt aix command line value to puppet property. Optional
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
  def translate_attr(key, value, mapping)
    return [key, value] unless mapping
    return nil unless mapping[key]
    
    if mapping[key][:method]
      new_value = method(mapping[key][:method]).call(value)
    else
      new_value = value
    end
    [mapping[key][:key], new_value]
  end

  # Gets the given command line argument for the given key, value and mapping.
  def get_arg(key, value, mapping)
    arg = nil
    if ret = self.translate_attr(key, val, mapping)
      new_key = ret[0]
      new_val = ret[1]
      
      # Arrays are separated by commas
      if new_val.is_a? Array
        value = new_val.join(",")
      else
        value = new_val.to_s
      end
      
      # Get the needed argument
      if mapping[key][:to_arg]
        arg = method(mapping[key][:to_arg]).call(new_key, value)
      else
        arg = (new_key.to_s + "=" + value )
      end
    end
    return arg
  end
  
  
  # Reads and attribute.
  # Here we implement the default behaviour.
  # Subclasses must reimplement this.
  def load_attribute(key, value, mapping, objectinfo)
    if mapping.nil?
      objectinfo[key] = value
    elsif mapping[key].nil?
      # is not present in mapping, ignore it.
      true
    elsif mapping[key][:method].nil?
      objectinfo[mapping[key][:key]] = value
    elsif 
      objectinfo[mapping[key][:key]] = method(mapping[key][:method]).call(value)
    end
    
    return objectinfo
  end
  
  def get_arguments(key, value, mapping, objectinfo)
    if mapping.nil?
      new_key = key
      new_value = value
    elsif mapping[key].nil?
      # is not present in mapping, ignore it.
      new_key = nil
      new_value = nil
    elsif mapping[key][:method].nil?
      new_key = mapping[key][:key]
      new_value = value
    elsif 
      new_key = mapping[key][:key]
      new_value = method(mapping[key][:method]).call(value)
    end

    # convert it to string
    if new_val.is_a? Array
      new_val = new_val.join(",")
    else
      new_val = new_val.to_s
    end

    if new_key?
      return [ "#{new_key}=#{new_value}" ] 
    else
      return []
    end
  end
  
  # Convert the provider properties to AIX command arguments (string)
  # This function will translate each value/key and generate the argument.
  # By default, arguments are created as aix_key=aix_value
  def hash2args(hash, mapping=self.class.attribute_mapping_to)
    return "" unless hash 
    arg_list = []
    hash.each {|key, val|
      arg_list += self.get_arguments(key, val, mapping, hash)
    }
    arg_list
  end

  # Parse AIX command attributes in a format of space separated of key=value
  # pairs: "uid=100 groups=a,b,c"
  # It returns and return provider hash.
  #
  # If a mapping is provided, the keys are translated as defined in the
  # mapping hash. Only values included in mapping will be added
  # NOTE: it will ignore the items not including '='
  def parse_attr_list(str, mapping=self.class.attribute_mapping_from)
    properties = {}
    attrs = []
    if !str or (attrs = str.split()).empty?
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
        key = key_str.downcase.to_sym
       
        properties = self.load_attribute(key, val, mapping, properties)
      end
    }
    properties.empty? ? nil : properties
  end

  # Parse AIX colon separated list of attributes, using given list of keys
  # to name the attributes. This function is useful to parse the output
  # of commands like lsfs -c:
  #   #MountPoint:Device:Vfs:Nodename:Type:Size:Options:AutoMount:Acct
  #   /:/dev/hd4:jfs2::bootfs:557056:rw:yes:no
  #   /home:/dev/hd1:jfs2:::2129920:rw:yes:no
  #   /usr:/dev/hd2:jfs2::bootfs:9797632:rw:yes:no
  #
  # If a mapping is provided, the keys are translated as defined in the
  # mapping hash. Only values included in mapping will be added
  # NOTE: it will ignore the items not including '='
  def parse_colon_list(str, key_list, mapping=self.class.attribute_mapping_from)
    properties = {}
    attrs = []
    if !str or (attrs = str.split(':')).empty?
      return nil
    end 

    attrs.each { |val|
      key = key_list.shift.downcase.to_sym
      properties = self.load_attribute(key, val, mapping, properties)
    }
    properties.empty? ? nil : properties
    
  end
  
  # Default parsing function for colon separated list or attributte list
  # (key=val pairs). It will choose the method depending of the first line.
  # For the colon separated list it will:
  #  1. Get keys from first line.
  #  2. Parse next line.
  def parse_command_output(output)
    lines = output.split("\n")
    # if it begins with #something:... is a colon separated list.
    if lines[0] =~ /^#.*:/ 
      self.parse_colon_list(lines[1], lines[0][1..-1].split(':'))
    else
      self.parse_attr_list(lines[0])
    end
  end

  # Retrieve what we can about our object
  def getinfo(refresh = false)
    if @objectinfo.nil? or refresh == true
      # Execute lsuser, split all attributes and add them to a dict.
      begin
        @objectinfo = self.parse_command_output(execute(self.lscmd))
      rescue Puppet::ExecutionFailure => detail
        # Print error if needed. FIXME: Do not check the user here.
        Puppet.debug "aix.getinfo(): Could not find #{@resource.class.name} #{@resource.name}: #{detail}" 
      end
    end
    @objectinfo
  end

  # List all elements of given type. It works for colon separated commands and
  # list commands. 
  def list_all
    names = []
    begin
      output = execute(self.lsallcmd()).split('\n')
      (output.select{ |l| l != /^#/ }).each { |v|
        name = v.split(/[ :]/)
        names << name if not name.empty?
      }
    rescue Puppet::ExecutionFailure => detail
      # Print error if needed
      Puppet.debug "aix.list_all(): Could not get all resources of type #{@resource.class.name}: #{detail}" 
    end
    names
  end


  #-------------
  # Provider API
  # ------------
 
  # Clear out the cached values.
  def flush
    @property_hash.clear if @property_hash
    @objectinfo.clear if @objectinfo
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
    objects=[]
    self.list_all().each { |entry|
      objects << new(:name => entry, :ensure => :present)
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
    
    if getinfo().nil?
      # This is weird...
      raise Puppet::Error, "Trying to update parameter '#{param}' to '#{value}' for a resource that does not exists #{@resource.class.name} #{@resource.name}: #{detail}"
    end
    if value == getinfo()[param.to_sym]
      return
    end
    
    #self.class.validate(param, value)
    
    if cmd = modifycmd({param =>value})
      begin
        execute(cmd)
      rescue Puppet::ExecutionFailure  => detail
        raise Puppet::Error, "Could not set #{param} on #{@resource.class.name}[#{@resource.name}]: #{detail}"
      end
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
