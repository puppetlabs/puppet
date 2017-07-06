require 'facter'
require 'puppet/util/plist' if Puppet.features.cfpropertylist?
require 'puppet'
require 'tempfile'

Puppet::Type.type(:macauthorization).provide :macauthorization, :parent => Puppet::Provider do

  desc "Manage Mac OS X authorization database rules and rights.

  "

  commands :security => "/usr/bin/security"

  confine :operatingsystem => :darwin
  confine :feature         => :cfpropertylist

  defaultfor :operatingsystem => :darwin

  AuthDB = "/etc/authorization"

  @rights = {}
  @rules = {}
  @parsed_auth_db = {}
  @comment = ""  # Not implemented yet. Is there any real need to?

  # This map exists due to the use of hyphens and reserved words in
  # the authorization schema.
  PuppetToNativeAttributeMap = {  :allow_root => "allow-root",
    :authenticate_user => "authenticate-user",
    :auth_class => "class",
    :k_of_n => "k-of-n",
    :session_owner => "session-owner", }

  class << self
    attr_accessor :parsed_auth_db
    attr_accessor :rights
    attr_accessor :rules
    attr_accessor :comments  # Not implemented yet.

    def prefetch(resources)
      self.populate_rules_rights
    end

    def instances
      if self.parsed_auth_db == {}
        self.prefetch(nil)
      end
      self.parsed_auth_db.collect do |k,v|
        new(:name => k)
      end
    end

    def populate_rules_rights
      auth_plist = Puppet::Util::Plist.parse_plist(AuthDB)
      raise Puppet::Error.new("Cannot parse: #{AuthDB}") if not auth_plist
      self.rights = auth_plist["rights"].dup
      self.rules = auth_plist["rules"].dup
      self.parsed_auth_db = self.rights.dup
      self.parsed_auth_db.merge!(self.rules.dup)
    end

  end

  # standard required provider instance methods

  def initialize(resource)
    if self.class.parsed_auth_db == {}
      self.class.prefetch(resource)
    end
    super
  end


  def create
    # we just fill the @property_hash in here and let the flush method
    # deal with it rather than repeating code.
    new_values = {}
    validprops = Puppet::Type.type(resource.class.name).validproperties
    validprops.each do |prop|
      next if prop == :ensure
      if value = resource.should(prop) and value != ""
        new_values[prop] = value
      end
    end
    @property_hash = new_values.dup
  end

  def destroy
    # We explicitly delete here rather than in the flush method.
    case resource[:auth_type]
    when :right
      destroy_right
    when :rule
      destroy_rule
    else
      raise Puppet::Error.new("Must specify auth_type when destroying.")
    end
  end

  def exists?
    !!self.class.parsed_auth_db.has_key?(resource[:name])
  end


  def flush
    # deletion happens in the destroy methods
    if resource[:ensure] != :absent
      case resource[:auth_type]
      when :right
        flush_right
      when :rule
        flush_rule
      else
        raise Puppet::Error.new("flush requested for unknown type.")
      end
      @property_hash.clear
    end
  end


  # utility methods below

  def destroy_right
    security "authorizationdb", :remove, resource[:name]
  end

  def destroy_rule
    authdb = Puppet::Util::Plist.parse_plist(AuthDB)
    authdb_rules = authdb["rules"].dup
    if authdb_rules[resource[:name]]
      begin
        authdb["rules"].delete(resource[:name])
        Puppet::Util::Plist.write_plist_file(authdb, AuthDB)
      rescue Errno::EACCES => e
        raise Puppet::Error.new("Error saving #{AuthDB}: #{e}", e)
      end
    end
  end

  def flush_right
    # first we re-read the right just to make sure we're in sync for
    # values that weren't specified in the manifest. As we're supplying
    # the whole plist when specifying the right it seems safest to be
    # paranoid given the low cost of querying the db once more.
    cmds = []
    cmds << :security << "authorizationdb" << "read" << resource[:name]
    output = execute(cmds, :failonfail => false, :combine => false)
    current_values = Puppet::Util::Plist.parse_plist(output)
    current_values ||= {}
    specified_values = convert_plist_to_native_attributes(@property_hash)

    # take the current values, merge the specified values to obtain a
    # complete description of the new values.
    new_values = current_values.merge(specified_values)
    set_right(resource[:name], new_values)
  end

  def flush_rule
    authdb = Puppet::Util::Plist.parse_plist(AuthDB)
    authdb_rules = authdb["rules"].dup
    current_values = {}
    current_values = authdb_rules[resource[:name]] if authdb_rules[resource[:name]]
    specified_values = convert_plist_to_native_attributes(@property_hash)
    new_values = current_values.merge(specified_values)
    set_rule(resource[:name], new_values)
  end

  def set_right(name, values)
    # Both creates and modifies rights as it simply overwrites them.
    # The security binary only allows for writes using stdin, so we
    # dump the values to a tempfile.
    values = convert_plist_to_native_attributes(values)
    tmp = Tempfile.new('puppet_macauthorization')
    begin
      Puppet::Util::Plist.write_plist_file(values, tmp.path)
      cmds = []
      cmds << :security << "authorizationdb" << "write" << name
      execute(cmds, :failonfail => false, :combine => false, :stdinfile => tmp.path.to_s)
    rescue Errno::EACCES => e
      raise Puppet::Error.new("Cannot save right to #{tmp.path}: #{e}", e)
    ensure
      tmp.close
      tmp.unlink
    end
  end

  def set_rule(name, values)
    # Both creates and modifies rules as it overwrites the entry in the
    # rules dictionary.  Unfortunately the security binary doesn't
    # support modifying rules at all so we have to twiddle the whole
    # plist... :( See Apple Bug #6386000
    values = convert_plist_to_native_attributes(values)
    authdb = Puppet::Util::Plist.parse_plist(AuthDB)
    authdb["rules"][name] = values

    begin
      Puppet::Util::Plist.write_plist_file(authdb, AuthDB)
    rescue
      raise Puppet::Error.new("Error writing to: #{AuthDB}")
    end
  end

  def convert_plist_to_native_attributes(propertylist)
    # This mainly converts the keys from the puppet attributes to the
    # 'native' ones, but also enforces that the keys are all Strings
    # rather than Symbols so that any merges of the resultant Hash are
    # sane. The exception is booleans, where we coerce to a proper bool
    # if they come in as a symbol.
    newplist = {}
    propertylist.each_pair do |key, value|
      next if key == :ensure     # not part of the auth db schema.
      next if key == :auth_type  # not part of the auth db schema.
      case value
      when true, :true
        value = true
      when false, :false
        value = false
      end
      new_key = key
      if PuppetToNativeAttributeMap.has_key?(key)
        new_key = PuppetToNativeAttributeMap[key].to_s
      elsif not key.is_a?(String)
        new_key = key.to_s
      end
      newplist[new_key] = value
    end
    newplist
  end

  def retrieve_value(resource_name, attribute)
    # We set boolean values to symbols when retrieving values
    raise Puppet::Error.new("Cannot find #{resource_name} in auth db") if not self.class.parsed_auth_db.has_key?(resource_name)

    if PuppetToNativeAttributeMap.has_key?(attribute)
      native_attribute = PuppetToNativeAttributeMap[attribute]
    else
      native_attribute = attribute.to_s
    end

    if self.class.parsed_auth_db[resource_name].has_key?(native_attribute)
      value = self.class.parsed_auth_db[resource_name][native_attribute]
      case value
      when true, :true
        value = :true
      when false, :false
        value = :false
      end

      @property_hash[attribute] = value
      return value
    else
      @property_hash.delete(attribute)
      return ""  # so ralsh doesn't display it.
    end
  end


  # property methods below
  #
  # We define them all dynamically apart from auth_type which is a special
  # case due to not being in the actual authorization db schema.

  properties = [  :allow_root, :authenticate_user, :auth_class, :comment,
    :group, :k_of_n, :mechanisms, :rule, :session_owner,
    :shared, :timeout, :tries ]

  properties.each do |field|
    define_method(field.to_s) do
      retrieve_value(resource[:name], field)
    end

    define_method(field.to_s + "=") do |value|
      @property_hash[field] = value
    end
  end

  def auth_type
    if resource.should(:auth_type) != nil
      return resource.should(:auth_type)
    elsif self.exists?
      # this is here just for ralsh, so it can work out what type it is.
      if self.class.rights.has_key?(resource[:name])
        return :right
      elsif self.class.rules.has_key?(resource[:name])
        return :rule
      else
        raise Puppet::Error.new("#{resource[:name]} is unknown type.")
      end
    else
      raise Puppet::Error.new("auth_type required for new resources.")
    end
  end

  def auth_type=(value)
    @property_hash[:auth_type] = value
  end

end
