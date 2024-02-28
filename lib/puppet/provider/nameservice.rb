# frozen_string_literal: true

require_relative '../../puppet'

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
      begin
        method = Puppet::Etc.method(:"get#{section}ent")
        while ent = method.call # rubocop:disable Lint/AssignmentInCondition
          objects << new(:name => ent.name, :canonical_name => ent.canonical_name, :ensure => :present)
        end
      ensure
        Puppet::Etc.send("end#{section}ent")
      end
      objects
    end

    def option(name, option)
      name = name.intern if name.is_a? String
      (defined?(@options) and @options.include? name and @options[name].include? option) ? @options[name][option] : nil
    end

    def options(name, hash)
      unless resource_type.valid_parameter?(name)
        raise Puppet::DevError, _("%{name} is not a valid attribute for %{resource_type}") % { name: name, resource_type: resource_type.name }
      end

      @options ||= {}
      @options[name] ||= {}

      # Set options individually, so we can call the options method
      # multiple times.
      hash.each do |param, value|
        @options[name][param] = value
      end
    end

    def resource_type=(resource_type)
      super
      @resource_type.validproperties.each do |prop|
        next if prop == :ensure

        define_method(prop) { get(prop) || :absent } unless public_method_defined?(prop)
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
        raise ArgumentError, _("Invalid value %{value}: %{error}") % { value: value, error: @checks[name][:error] } unless block.call(value)
      end
    end

    def verify(name, error, &block)
      name = name.intern if name.is_a? String
      @checks[name] = { :error => error, :block => block }
    end

    private

    def op(property)
      @ops[property.name] || ("-#{property.name}")
    end
  end

  # Autogenerate a value.  Mostly used for uid/gid, but also used heavily
  # with DirectoryServices
  def autogen(field)
    field = field.intern
    id_generators = { :user => :uid, :group => :gid }
    if id_generators[@resource.class.name] == field
      return self.class.autogen_id(field, @resource.class.name)
    else
      value = self.class.autogen_default(field)
      if value
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
      # TRANSLATORS "autogen_id()" is a method name and should not be translated
      raise Puppet::DevError, _("autogen_id() does not support auto generation of id for resource type %{resource_type}") % { resource_type: resource_type }
    end

    # Initialize from the data set, if needed.
    unless @prevauto
      # Sadly, Etc doesn't return an enumerator, it just invokes the block
      # given, or returns the first record from the database.  There is no
      # other, more convenient enumerator for these, so we fake one with this
      # loop.  Thanks, Ruby, for your awesome abstractions. --daniel 2012-03-23
      highest = []
      Puppet::Etc.send(database) { |entry| highest << entry.send(method) }
      highest = highest.reject { |x| x > 65_000 }.max

      @prevauto = highest || 1000
    end

    # ...and finally increment and return the next value.
    @prevauto += 1
  end

  def create
    if exists?
      info _("already exists")
      # The object already exists
      return nil
    end

    begin
      sensitive = has_sensitive_data?
      execute(self.addcmd, { :failonfail => true, :combine => true, :custom_environment => @custom_environment, :sensitive => sensitive })
      if feature?(:manages_password_age) && (cmd = passcmd)
        execute(cmd, { :failonfail => true, :combine => true, :custom_environment => @custom_environment, :sensitive => sensitive })
      end
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, _("Could not create %{resource} %{name}: %{detail}") % { resource: @resource.class.name, name: @resource.name, detail: detail }, detail.backtrace
    end
  end

  def delete
    unless exists?
      info _("already absent")
      # the object already doesn't exist
      return nil
    end

    begin
      execute(self.deletecmd, { :failonfail => true, :combine => true, :custom_environment => @custom_environment })
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, _("Could not delete %{resource} %{name}: %{detail}") % { resource: @resource.class.name, name: @resource.name, detail: detail }, detail.backtrace
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
    block = self.class.option(name, :munge)
    if block and block.is_a? Proc
      block.call(value)
    else
      value
    end
  end

  def unmunge(name, value)
    block = self.class.option(name, :unmunge)
    if block and block.is_a? Proc
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
        @objectinfo = Puppet::Etc.send(@etcmethod, @canonical_name)
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
    Puppet::Util::POSIX.groups_of(@resource[:name]).join(',')
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
    if resource.is_a?(Hash) && !resource[:canonical_name].nil?
      @canonical_name = resource[:canonical_name]
    else
      @canonical_name = resource[:name]
    end
  end

  def set(param, value)
    self.class.validate(param, value)
    cmd = modifycmd(param, munge(param, value))
    raise Puppet::DevError, _("Nameservice command must be an array") unless cmd.is_a?(Array)

    sensitive = has_sensitive_data?(param)
    begin
      execute(cmd, { :failonfail => true, :combine => true, :custom_environment => @custom_environment, :sensitive => sensitive })
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, _("Could not set %{param} on %{resource}[%{name}]: %{detail}") % { param: param, resource: @resource.class.name, name: @resource.name, detail: detail }, detail.backtrace
    end
  end

  # Derived classes can override to declare sensitive data so a flag can be passed to execute
  def has_sensitive_data?(property = nil)
    false
  end

  # From overriding Puppet::Property#insync? Ruby Etc::getpwnam < 2.1.0 always
  # returns a struct with binary encoded string values, and >= 2.1.0 will return
  # binary encoded strings for values incompatible with current locale charset,
  # or Encoding.default_external if compatible. Compare a "should" value with
  # encoding of "current" value, to avoid unnecessary property syncs and
  # comparison of strings with different encodings. (PUP-6777)
  #
  # return basic string comparison after re-encoding (same as
  # Puppet::Property#property_matches)
  def comments_insync?(current, should)
    # we're only doing comparison here so don't mutate the string
    desired = should[0].to_s.dup
    current == desired.force_encoding(current.encoding)
  end
end
