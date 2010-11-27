require 'puppet'

# This is the parent class of all NSS classes.  They're very different in
# their backend, but they're pretty similar on the front-end.  This class
# provides a way for them all to be as similar as possible.
class Puppet::Provider::NameService < Puppet::Provider
  class << self
    def autogen_default(param)
      defined?(@autogen_defaults) ? @autogen_defaults[symbolize(param)] : nil
    end

    def autogen_defaults(hash)
      @autogen_defaults ||= {}
      hash.each do |param, value|
        @autogen_defaults[symbolize(param)] = value
      end
    end

    def initvars
      @checks = {}
      super
    end

    def instances
      objects = []
      listbyname do |name|
        objects << new(:name => name, :ensure => :present)
      end

      objects
    end

    def option(name, option)
      name = name.intern if name.is_a? String
      (defined?(@options) and @options.include? name and @options[name].include? option) ? @options[name][option] : nil
    end

    def options(name, hash)
      raise Puppet::DevError, "#{name} is not a valid attribute for #{resource_type.name}" unless resource_type.valid_parameter?(name)
      @options ||= {}
      @options[name] ||= {}

      # Set options individually, so we can call the options method
      # multiple times.
      hash.each do |param, value|
        @options[name][param] = value
      end
    end

    # List everything out by name.  Abstracted a bit so that it works
    # for both users and groups.
    def listbyname
      names = []
      Etc.send("set#{section()}ent")
      begin
        while ent = Etc.send("get#{section()}ent")
          names << ent.name
          yield ent.name if block_given?
        end
      ensure
        Etc.send("end#{section()}ent")
      end

      names
    end

    def resource_type=(resource_type)
      super
      @resource_type.validproperties.each do |prop|
        next if prop == :ensure
        define_method(prop) { get(prop) || :absent} unless public_method_defined?(prop)
        define_method(prop.to_s + "=") { |*vals| set(prop, *vals) } unless public_method_defined?(prop.to_s + "=")
      end
    end

    # This is annoying, but there really aren't that many options,
    # and this *is* built into Ruby.
    def section
      unless defined?(@resource_type)
        raise Puppet::DevError,
          "Cannot determine Etc section without a resource type"

      end

      if @resource_type.name == :group
        "gr"
      else
        "pw"
      end
    end

    def validate(name, value)
      name = name.intern if name.is_a? String
      if @checks.include? name
        block = @checks[name][:block]
        raise ArgumentError, "Invalid value #{value}: #{@checks[name][:error]}" unless block.call(value)
      end
    end

    def verify(name, error, &block)
      name = name.intern if name.is_a? String
      @checks[name] = {:error => error, :block => block}
    end

    private

    def op(property)
      @ops[property.name] || ("-#{property.name}")
    end
  end

  # Autogenerate a value.  Mostly used for uid/gid, but also used heavily
  # with DirectoryServices, because DirectoryServices is stupid.
  def autogen(field)
    field = symbolize(field)
    id_generators = {:user => :uid, :group => :gid}
    if id_generators[@resource.class.name] == field
      return autogen_id(field)
    else
      if value = self.class.autogen_default(field)
        return value
      elsif respond_to?("autogen_#{field}")
        return send("autogen_#{field}")
      else
        return nil
      end
    end
  end

  # Autogenerate either a uid or a gid.  This is hard-coded: we can only
  # generate one field type per class.
  def autogen_id(field)
    highest = 0

    group = method = nil
    case @resource.class.name
    when :user; group = :passwd; method = :uid
    when :group; group = :group; method = :gid
    else
      raise Puppet::DevError, "Invalid resource name #{resource}"
    end

    # Make sure we don't use the same value multiple times
    if defined?(@@prevauto)
      @@prevauto += 1
    else
      Etc.send(group) { |obj|
        if obj.gid > highest
          highest = obj.send(method) unless obj.send(method) > 65000
        end
      }

      @@prevauto = highest + 1
    end

    @@prevauto
  end

  def create
    if exists?
      info "already exists"
      # The object already exists
      return nil
    end

    begin
      execute(self.addcmd)
      if feature?(:manages_password_age) && (cmd = passcmd)
        execute(cmd)
      end
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

  def ensure
    if exists?
      :present
    else
      :absent
    end
  end

  # Does our object exist?
  def exists?
    !!getinfo(true)
  end

  # Retrieve a specific value by name.
  def get(param)
    (hash = getinfo(false)) ? hash[param] : nil
  end

  # Retrieve what we can about our object
  def getinfo(refresh)
    if @objectinfo.nil? or refresh == true
      @etcmethod ||= ("get" + self.class.section.to_s + "nam").intern
      begin
        @objectinfo = Etc.send(@etcmethod, @resource[:name])
      rescue ArgumentError => detail
        @objectinfo = nil
      end
    end

    # Now convert our Etc struct into a hash.
    @objectinfo ? info2hash(@objectinfo) : nil
  end

  # The list of all groups the user is a member of.  Different
  # user mgmt systems will need to override this method.
  def groups
    groups = []

    # Reset our group list
    Etc.setgrent

    user = @resource[:name]

    # Now iterate across all of the groups, adding each one our
    # user is a member of
    while group = Etc.getgrent
      members = group.mem

      groups << group.name if members.include? user
    end

    # We have to close the file, so each listing is a separate
    # reading of the file.
    Etc.endgrent

    groups.join(",")
  end

  # Convert the Etc struct into a hash.
  def info2hash(info)
    hash = {}
    self.class.resource_type.validproperties.each do |param|
      method = posixmethod(param)
      hash[param] = info.send(posixmethod(param)) if info.respond_to? method
    end

    hash
  end

  def initialize(resource)
    super

    @objectinfo = nil
  end

  def set(param, value)
    self.class.validate(param, value)
    cmd = modifycmd(param, value)
    raise Puppet::DevError, "Nameservice command must be an array" unless cmd.is_a?(Array)
    begin
      execute(cmd)
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not set #{param} on #{@resource.class.name}[#{@resource.name}]: #{detail}"
    end
  end
end

