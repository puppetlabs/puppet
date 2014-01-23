require 'puppet'

# This is the parent class of all NSS classes.  They're very different in
# their backend, but they're pretty similar on the front-end.  This class
# provides a way for them all to be as similar as possible.
class Puppet::Provider::NameService < Puppet::Provider
  class << self
    def autogen_default(param)
      defined?(@autogen_defaults) ? @autogen_defaults[param.intern] : nil
    end

    def autogen_defaults(hash)
      @autogen_defaults ||= {}
      hash.each do |param, value|
        @autogen_defaults[param.intern] = value
      end
    end

    def initvars
      @checks = {}
      @options = {}
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
      unless resource_type
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
    field = field.intern
    id_generators = {:user => :uid, :group => :gid}
    if id_generators[@resource.class.name] == field
      return self.class.autogen_id(field, @resource.class.name)
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

  # Autogenerate either a uid or a gid.  This is not very flexible: we can
  # only generate one field type per class, and get kind of confused if asked
  # for both.
  def self.autogen_id(field, resource_type)
    # Figure out what sort of value we want to generate.
    case resource_type
    when :user;   database = :passwd;  method = :uid
    when :group;  database = :group;   method = :gid
    else
      raise Puppet::DevError, "Invalid resource name #{resource}"
    end

    # Initialize from the data set, if needed.
    unless @prevauto
      # Sadly, Etc doesn't return an enumerator, it just invokes the block
      # given, or returns the first record from the database.  There is no
      # other, more convenient enumerator for these, so we fake one with this
      # loop.  Thanks, Ruby, for your awesome abstractions. --daniel 2012-03-23
      highest = []
      Etc.send(database) {|entry| highest << entry.send(method) }
      highest = highest.reject {|x| x > 65000 }.max

      @prevauto = highest || 1000
    end

    # ...and finally increment and return the next value.
    @prevauto += 1
  end

  def create
    if exists?
      info "already exists"
      # The object already exists
      return nil
    end

    begin
      execute(self.addcmd, {:failonfail => true, :combine => true, :custom_environment => @custom_environment})
      if feature?(:manages_password_age) && (cmd = passcmd)
        execute(cmd)
      end
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not create #{@resource.class.name} #{@resource.name}: #{detail}", detail.backtrace
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
      raise Puppet::Error, "Could not delete #{@resource.class.name} #{@resource.name}: #{detail}", detail.backtrace
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
    (hash = getinfo(false)) ? unmunge(param, hash[param]) : nil
  end

  def munge(name, value)
    if block = self.class.option(name, :munge) and block.is_a? Proc
      block.call(value)
    else
      value
    end
  end

  def unmunge(name, value)
    if block = self.class.option(name, :unmunge) and block.is_a? Proc
      block.call(value)
    else
      value
    end
  end

  # Retrieve what we can about our object
  def getinfo(refresh)
    if @objectinfo.nil? or refresh == true
      @etcmethod ||= ("get" + self.class.section.to_s + "nam").intern
      begin
        @objectinfo = Etc.send(@etcmethod, @resource[:name])
      rescue ArgumentError
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
    @custom_environment = {}
    @objectinfo = nil
  end

  def set(param, value)
    self.class.validate(param, value)
    cmd = modifycmd(param, munge(param, value))
    raise Puppet::DevError, "Nameservice command must be an array" unless cmd.is_a?(Array)
    begin
      execute(cmd)
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not set #{param} on #{@resource.class.name}[#{@resource.name}]: #{detail}", detail.backtrace
    end
  end
end

