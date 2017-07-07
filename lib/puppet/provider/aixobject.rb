#
# Common code for AIX providers. This class implements basic structure for
# AIX resources.
# Author::    Hector Rivas Gandara <keymon@gmail.com>
#
class Puppet::Provider::AixObject < Puppet::Provider
  desc "Generic AIX resource provider"

  # The real provider must implement these functions.
  def lscmd( _value = @resource[:name] )
    raise Puppet::Error, "Method not defined #{@resource.class.name} #{@resource.name}: Base AixObject provider doesn't implement lscmd"
  end

  def addcmd( _extra_attrs = [] )
    raise Puppet::Error, "Method not defined #{@resource.class.name} #{@resource.name}: Base AixObject provider doesn't implement addcmd"
  end

  def modifycmd( _attributes_hash = {} )
    raise Puppet::Error, "Method not defined #{@resource.class.name} #{@resource.name}: Base AixObject provider doesn't implement modifycmd"
  end

  def deletecmd
    raise Puppet::Error, "Method not defined #{@resource.class.name} #{@resource.name}: Base AixObject provider doesn't implement deletecmd"
  end

  # Valid attributes to be managed by this provider.
  # It is a list of hashes
  #  :aix_attr      AIX command attribute name
  #  :puppet_prop   Puppet property name
  #  :to            Optional. Method name that adapts puppet property to aix command value.
  #  :from          Optional. Method to adapt aix command line value to puppet property. Optional
  class << self
    attr_accessor :attribute_mapping
  end

  # Mapping from Puppet property to AIX attribute.
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

  # Mapping from AIX attribute to Puppet property.
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
  # It returns a list with the pair [key, value]
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

  # Loads an AIX attribute (key=value) and stores it in the given hash with
  # puppet semantics. It translates the pair using the given mapping.
  #
  # This operation works with each property one by one,
  # subclasses must reimplement this if more complex operations are needed
  def load_attribute(key, value, mapping, objectinfo)
    if mapping.nil?
      objectinfo[key] = value
    elsif mapping[key].nil?
      # is not present in mapping, ignore it.
      true
    elsif mapping[key][:method].nil?
      objectinfo[mapping[key][:key]] = value
    else
      objectinfo[mapping[key][:key]] = method(mapping[key][:method]).call(value)
    end

    return objectinfo
  end

  # Gets the given command line argument for the given key and value,
  # using the given mapping to translate key and value.
  # All the objectinfo hash (@resource or @property_hash) is passed.
  #
  # This operation works with each property one by one,
  # and default behaviour is return the arguments as key=value pairs.
  # Subclasses must reimplement this if more complex operations/arguments
  # are needed
  #
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
    else
      new_key = mapping[key][:key]
      new_value = method(mapping[key][:method]).call(value)
    end

    # convert it to string
    new_value = Array(new_value).join(',')

    if new_key
      return [ "#{new_key}=#{new_value}" ]
    else
      return []
    end
  end

  # Convert the provider properties (hash) to AIX command arguments
  # (list of strings)
  # This function will translate each value/key and generate the argument using
  # the get_arguments function.
  def hash2args(hash, mapping=self.class.attribute_mapping_to)
    return "" unless hash
    arg_list = []
    hash.each {|key, val|
      arg_list += self.get_arguments(key, val, mapping, hash)
    }
    arg_list
  end

  # Parse AIX command attributes from the output of an AIX command, that
  # which format is a list of space separated of key=value pairs:
  # "uid=100 groups=a,b,c".
  # It returns a hash.
  #
  # If a mapping is provided, the keys are translated as defined in the
  # mapping hash. And only values included in mapping will be added
  #
  # NOTE: it will ignore the items not including '='
  def parse_attr_list(str, mapping=self.class.attribute_mapping_from)
    properties = {}
    attrs = []
    if str.nil? or (attrs = str.split()).empty?
      return nil
    end

    attrs.each { |i|
      if i.include? "=" # Ignore if it does not include '='
        (key_str, val) = i.split('=')
        # Check the key
        if key_str.nil? or key_str.empty?
          info _("Empty key in string 'i'?")
          continue
        end
        key_str.strip!
        key = key_str.to_sym
        val.strip! if val

        properties = self.load_attribute(key, val, mapping, properties)
      end
    }
    properties.empty? ? nil : properties
  end

  # Parse AIX command output in a colon separated list of attributes,
  # This function is useful to parse the output of commands like lsfs -c:
  #   #MountPoint:Device:Vfs:Nodename:Type:Size:Options:AutoMount:Acct
  #   /:/dev/hd4:jfs2::bootfs:557056:rw:yes:no
  #   /home:/dev/hd1:jfs2:::2129920:rw:yes:no
  #   /usr:/dev/hd2:jfs2::bootfs:9797632:rw:yes:no
  #
  # If a mapping is provided, the keys are translated as defined in the
  # mapping hash. And only values included in mapping will be added
  def parse_colon_list(str, key_list, mapping=self.class.attribute_mapping_from)
    properties = {}
    attrs = []
    if str.nil? or (attrs = str.split(':')).empty?
      return nil
    end

    attrs.each { |val|
      key = key_list.shift.to_sym
      properties = self.load_attribute(key, val, mapping, properties)
    }
    properties.empty? ? nil : properties
  end

  # Default parsing function for AIX commands.
  # It will choose the method depending of the first line.
  # For the colon separated list it will:
  #  1. Get keys from first line.
  #  2. Parse next line.
  def parse_command_output(output, mapping=self.class.attribute_mapping_from)
    lines = output.split("\n")
    # if it begins with #something:... is a colon separated list.
    if lines[0] =~ /^#.*:/
      self.parse_colon_list(lines[1], lines[0][1..-1].split(':'), mapping)
    else
      self.parse_attr_list(lines[0], mapping)
    end
  end

  # Retrieve all the information of an existing resource.
  # It will execute 'lscmd' command and parse the output, using the mapping
  # 'attribute_mapping_from' to translate the keys and values.
  def getinfo(refresh = false)
    if @objectinfo.nil? or refresh == true
      # Execute lsuser, split all attributes and add them to a dict.
      begin
        output = execute(self.lscmd)
        @objectinfo = self.parse_command_output(output)
        # All attributes without translation
        @objectosinfo = self.parse_command_output(output, nil)
      rescue Puppet::ExecutionFailure => detail
        # Print error if needed. FIXME: Do not check the user here.
        Puppet.debug "aix.getinfo(): Could not find #{@resource.class.name} #{@resource.name}: #{detail}"
      end
    end
    @objectinfo
  end

  # Like getinfo, but it will not use the mapping to translate the keys and values.
  # It might be useful to retrieve some raw information.
  def getosinfo(refresh = false)
    if @objectosinfo.nil? or refresh == true
      getinfo(refresh)
    end
    @objectosinfo || Hash.new
  end


  # List all elements of given type. It works for colon separated commands and
  # list commands.
  # It returns a list of names.
  def self.list_all
    names = []
    begin
      output = execute([self.command(:list), 'ALL'])

      output = output.split("\n").select{ |line| line != /^#/ }

      output.each do |line|
        name = line.split(/[ :]/)[0]
        names << name if not name.empty?
      end
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

  # Return all existing instances
  # The method for returning a list of provider instances.  Note that it returns
  # providers, preferably with values already filled in, not resources.
  def self.instances
    objects=[]
    list_all.each { |entry|
      objects << new(:name => entry, :ensure => :present)
    }
    objects
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

  # Create a new instance of the resource
  def create
    if exists?
      info _("already exists")
      # The object already exists
      return nil
    end

    begin
      execute(self.addcmd)
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, _("Could not create %{resource} %{name}: %{detail}") % { resource: @resource.class.name, name: @resource.name, detail: detail }, detail.backtrace
    end
  end

  # Delete this instance of the resource
  def delete
    unless exists?
      info _("already absent")
      # the object already doesn't exist
      return nil
    end

    begin
      execute(self.deletecmd)
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, _("Could not delete %{resource} %{name}: %{detail}") % { resource: @resource.class.name, name: @resource.name, detail: detail }, detail.backtrace
    end
  end

  #--------------------------------
  # Call this method when the object is initialized.
  # It creates getter/setter methods for each property our resource type supports.
  # If setter or getter already defined it will not be overwritten
  def self.mk_resource_methods
    [resource_type.validproperties, resource_type.parameters].flatten.each do |prop|
      next if prop == :ensure
      define_method(prop) { get(prop) || :absent} unless public_method_defined?(prop)
      define_method(prop.to_s + "=") { |*vals| set(prop, *vals) } unless public_method_defined?(prop.to_s + "=")
    end
  end

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
    @property_hash[param.intern] = value

    if getinfo().nil?
      # This is weird...
      raise Puppet::Error, _("Trying to update parameter '%{param}' to '%{value}' for a resource that does not exists %{resource} %{name}: %{detail}") % { param: param, value: value, resource: @resource.class.name, name: @resource.name, detail: detail }
    end
    if value == getinfo()[param.to_sym]
      return
    end

    #self.class.validate(param, value)
    if cmd = modifycmd({param =>value})
      begin
        execute(cmd)
      rescue Puppet::ExecutionFailure  => detail
        raise Puppet::Error, _("Could not set %{param} on %{resource}[%{name}]: %{detail}") % { param: param, resource: @resource.class.name, name: @resource.name, detail: detail }, detail.backtrace
      end
    end

    # Refresh de info.
    getinfo(true)
  end

  def initialize(resource)
    super
    @objectinfo = nil
    @objectosinfo = nil
  end
end
