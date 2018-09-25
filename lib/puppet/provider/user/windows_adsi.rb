require 'puppet/util/windows'

Puppet::Type.type(:user).provide :windows_adsi do
  desc "Local user management for Windows."

  defaultfor :operatingsystem => :windows
  confine    :operatingsystem => :windows

  has_features :manages_homedir,
               :manages_passwords,
               :manages_attributes

  class << self
    # We only manage a subset of the available Windows attributes.
    # These attributes are stored in the managed_attributes hash below.
    # Each key represents an attribute that we can manage. Each value
    # is a hash consisting of the following schema:
    #    {
    #      :getter => A lambda that retrieves the attribute value from
    #                 the provider instance. This should always return
    #                 a string, because it is what the attributes property
    #                 expects.
    #
    #                 Interface is lambda { |provider| ... }
    #
    #      :setter => A lambda that sets the attribute value on the
    #                 provider instance. It should accept a string
    #                 because this is what the attributes property will
    #                 pass-in.
    #
    #                 Interface is lambda { |provider, value| ... }
    #    }
    #
    attr_reader :managed_attributes
    
    # Adds a new attribute to the managed_attributes hash. The info
    # must include:
    #
    #   * :name   -- The attribute's name
    #   * :getter -- The attribute's getter
    #   * :setter -- The attribute's setter
    #
    def attribute(info)
      name = info.delete(:name)

      # Wrap any useful errors raised by the setter.
      #
      # NOTE: We can apply a similar pattern to wrap any
      # errors raised by the getter.
      setter = info.delete(:setter)
      info[:setter] = lambda do |provider, value|
        begin
          setter.call(provider, value)
        rescue WIN32OLERuntimeError, ArgumentError => detail
          raise Puppet::Error, _("Failed to set the %{attribute} attribute's value to %{value}: %{detail}") % { attribute: name, value: value, detail: detail }, detail.backtrace
        end
      end

      @managed_attributes ||= {} 
      @managed_attributes[name] = info
    end

    # Adds a new attribute that directly maps to an ADSI User property.
    # The info hash must include:
    #
    #   * :name     -- The attribute's name
    #
    #   * :property -- The ADS User property that the attribute maps to
    #
    #   * :munge    -- A lambda that munges the raw ADSI property value
    #                  to the attribute value. Defaults to munge_string.
    #
    #   * :unmunge  -- A lambda that unmunges the attribute value to the
    #                  raw ADSI property value. Defaults to unmunge_string.
    #
    # NOTE: We could possibly re-use the mapping concept in the AixObject
    # class here. See PUP-9082.
    def adsi_property_attribute(info = {})
      info[:munge] ||= method(:munge_string)
      info[:unmunge] ||= method(:unmunge_string)

      property = info.delete(:property)
      munge = info.delete(:munge)
      unmunge = info.delete(:unmunge)

      getter = lambda do |provider|
        munge.call(provider.user[property])
      end
      setter = lambda do |provider, value|
        provider.user[property] = unmunge.call(value)
      end

      info = info.merge(getter: getter, setter: setter)

      attribute(info)
    end

    # Adds a new attribute that directly maps to an ADS User flag. The info
    # hash must include:
    #
    #   * :name -- The attribute's name
    #   * :flag -- The ADS User flag that the attribute maps to
    #
    def userflag_attribute(info = {})
      flag = info.delete(:flag)

      getter = lambda do |provider|
        provider.user.userflag_set?(flag).to_s
      end
      setter = lambda do |provider, set_flag|
        unless set_flag == 'true' || set_flag == 'false'
          raise ArgumentError, _("'%{set_flag}' is not a Boolean value! Boolean values are 'true' or 'false'") % { set_flag: set_flag }
        end

        if set_flag == 'true'
          provider.user.set_userflags(flag)
        else
          provider.user.unset_userflags(flag)
        end
      end

      info = info.merge(
        getter: getter,
        setter: setter
      )

      attribute(info)
    end

    def munge_string(value)
      value
    end

    def unmunge_string(value)
      # WIN32OLE will throw an unreadable error message if we try
      # to set the attribute value to the empty string, so we check
      # for this case and throw a more readable one here.
      if value.empty?
        raise ArgumentError, "The empty string is not an allowable attribute value!"
      end

      value
    end

    def munge_bit(value)
      return 'true' if value == 1
      return 'false' if value == 0
      raise ArgumentError, _("'%{value}' is not a bit value! Bit values are 0 or 1") % { value: value }
    end

    def unmunge_bit(value)
      return 1 if value == 'true'
      return 0 if value == 'false'
      raise ArgumentError, _("'%{value}' is not a Boolean value! Boolean values are 'true' or 'false'") % { value: value }
    end
  end

  # We can also manage many more attributes than what's listed here. All of
  # the userflags can probably be individually managed. See
  #   https://docs.microsoft.com/en-us/windows/desktop/api/iads/ne-iads-ads_user_flag
  #
  # We can also manage the AccountExpirationDate, and possibly some of the
  # properties in https://docs.microsoft.com/en-us/windows/desktop/ADSI/winnt-custom-user-properties

  adsi_property_attribute name: :full_name,
                          property: 'FullName'

  adsi_property_attribute name: :password_change_required,
                          property: 'PasswordExpired',
                          munge: method(:munge_bit),
                          unmunge: method(:unmunge_bit)

  userflag_attribute name: :disabled,
                     flag: :ADS_UF_ACCOUNTDISABLE

  userflag_attribute name: :password_change_not_allowed,
                     flag: :ADS_UF_PASSWD_CANT_CHANGE

  userflag_attribute name: :password_never_expires,
                     flag: :ADS_UF_DONT_EXPIRE_PASSWD

  def managed_attributes
    self.class.managed_attributes
  end

  def initialize(value={})
    super(value)
    @deleted = false
  end

  def user
    @user ||= Puppet::Util::Windows::ADSI::User.new(@resource[:name])
  end

  def groups
    @groups ||= Puppet::Util::Windows::ADSI::Group.name_sid_hash(user.groups)
    @groups.keys
  end

  def groups=(groups)
    user.set_groups(groups, @resource[:membership] == :minimum)
  end

  def groups_insync?(current, should)
    return false unless current

    # By comparing account SIDs we don't have to worry about case
    # sensitivity, or canonicalization of account names.

    # Cannot use munge of the group property to canonicalize @should
    # since the default array_matching comparison is not commutative

    # dupes automatically weeded out when hashes built
    current_groups = Puppet::Util::Windows::ADSI::Group.name_sid_hash(current)
    specified_groups = Puppet::Util::Windows::ADSI::Group.name_sid_hash(should)

    current_sids = current_groups.keys.to_a
    specified_sids = specified_groups.keys.to_a

    if @resource[:membership] == :inclusive
      current_sids.sort == specified_sids.sort
    else
      (specified_sids & current_sids) == specified_sids
    end
  end

  def groups_to_s(groups)
    return '' if groups.nil? || !groups.kind_of?(Array)
    groups = groups.map do |group_name|
      sid = Puppet::Util::Windows::SID.name_to_principal(group_name)
      if sid.account =~ /\\/
        account, _ = Puppet::Util::Windows::ADSI::Group.parse_name(sid.account)
      else
        account = sid.account
      end
      resource.debug("#{sid.domain}\\#{account} (#{sid.sid})")
      "#{sid.domain}\\#{account}"
    end
    return groups.join(',')
  end

  def create
    @user = Puppet::Util::Windows::ADSI::User.create(@resource[:name])
    set_password(@resource[:password], false)

    [:comment, :home, :groups, :attributes].each do |prop|
      send("#{prop}=", @resource[prop]) if @resource[prop]
    end

    if @resource.managehome?
      Puppet::Util::Windows::User.load_profile(@resource[:name], @resource[:password])
    end
  end

  def exists?
    Puppet::Util::Windows::ADSI::User.exists?(@resource[:name])
  end

  def delete
    # lookup sid before we delete account
    sid = uid if @resource.managehome?

    Puppet::Util::Windows::ADSI::User.delete(@resource[:name])

    if sid
      Puppet::Util::Windows::ADSI::UserProfile.delete(sid)
    end

    @deleted = true
  end

  def flush
    return unless @sync_password

    # The reason we need to sync the password here is because of the
    # 'password_change_required' and 'disabled' attributes. We want
    # to sync. the password based on the _final_ state of these
    # attributes, which is determined after the attributes property is
    # synced.
    debug _("Setting the password ...")
    set_password(@resource[:password], true)
  ensure
    # Only commit if we created or modified a user, not deleted
    @user.commit if @user && !@deleted
  end

  def comment
    user['Description']
  end

  def comment=(value)
    user['Description'] = value
  end

  def home
    user['HomeDirectory']
  end

  def home=(value)
    user['HomeDirectory'] = value
  end

  def password
    # avoid a LogonUserW style password check when the resource is not yet
    # populated with a password (as is the case with `puppet resource user`)
    return nil if @resource[:password].nil?
    user.password_is?( @resource[:password] ) ? @resource[:password] : nil
  end

  # Sets the user's password.
  #
  # @api private
  def set_password(password, existing_user)
    if existing_user
      # We always want to set a new user's password. However for
      # an existing user, we need to check if changing their
      # password makes sense

      # Do NOT attempt to retrieve a new user's attributes. Doing so
      # will raise an exception because the user's ADSI property values
      # (some of which correspond to their attributes) are only loaded
      # into the property cache _after_ they've been committed.
      current_attributes = attributes

      if current_attributes[:password_change_required] == 'true'
        warning _("The account '%{name}' requires the user to change their password on the next sign-in; Puppet will not reset the password. If you still wish to reset the user's password, then set password_change_required to false in the attributes property and re-run Puppet.") % { name: name }
        return
      end
  
      if current_attributes[:disabled] == 'true'
        warning _("The user account '%s' is disabled; Puppet will not reset the password. If you still wish to reset the user's password, then set disabled to false in the attributes property and re-run Puppet." % @resource[:name])
        return
      end
  
      if user.locked_out?
        warning _("The user account '%s' is locked out; Puppet will not reset the password" % @resource[:name])
        return
      end
  
      if user.expired?
        warning _("The user account '%s' is expired; Puppet will not reset the password" % @resource[:name])
        return
      end
    end

    user.password = password

    # The user's been committed. Thus, it is safe to retrieve
    # their attributes.

    if (attributes_prop = @resource.property(:attributes))
      specified_attributes = attributes_prop.hashify_should
      unless specified_attributes.key?(:password_never_expires)
        warning _("The attributes property did not specify the 'password_never_expires' attribute, which is currently set to %{password_never_expires} on the system. If this is undesirable behavior, then please specify a value for the 'password_never_expires' attribute, and re-run Puppet.") % { password_never_expires: attributes[:password_never_expires] }
      end

      return
    end

    # The attributes property isn't being managed. Thus, we set the password
    # to never expire by default for backwards compatibility.
    begin
      self.attributes = {
        password_never_expires: 'true'
      }

      user.commit
    rescue Puppet::Error => detail
      raise Puppet::Error, _("Could not set the new password to never expire by default. You will have to manually do this by passing in '{ password_never_expires => true }' to the attributes property of the User resource, and then re-running Puppet. Detail: %{detail}.") % { detail: detail }, detail.backtrace
    end
  end

  def password=(value)
    unless @resource[:attributes]
      set_password(value, true)
      return
    end

    # If the attributes property is managed, then it must be syncd
    # before the password. There is no programmatic way in Puppet to
    # specify that 'Property A' must be syncd. before 'Property B',
    # aside from defining 'Property A' before 'Property B' in the
    # type definition. Thus, we will sync. the password in #flush.
    debug _("The attributes property is being managed, so we will sync. the password later in the #flush method.")
    @sync_password = true
  end

  def uid
    Puppet::Util::Windows::SID.name_to_sid(@resource[:name])
  end

  def uid=(value)
    fail "uid is read-only"
  end

  def attributes
    attributes_hash = {}
    managed_attributes.each do |attribute, info|
      attributes_hash[attribute] = info[:getter].call(self) 
    end

    attributes_hash
  end

  def validate_attributes(new_attributes)
    # Check for any unmanaged attributes

    unmanaged_attributes = new_attributes.keys.reject do |attribute|
      managed_attributes.keys.include?(attribute)
    end

    unless unmanaged_attributes.empty?
      raise ArgumentError, _("Cannot manage the %{unmanaged_attributes} attributes. The manageable attributes are %{managed_attributes}.") % { unmanaged_attributes: unmanaged_attributes.join(', '), managed_attributes: managed_attributes.keys.join(', ') }
    end

    # Check for any invalid attribute combinations

    if new_attributes[:password_change_not_allowed] == 'true' &&
       new_attributes[:password_change_required]    == 'true'
      raise ArgumentError, _("Cannot have password_change_not_allowed == true and password_change_required == true. Reason: Disallowing the user to change their password while also requiring them to change it the next time they log-in is a contradiction!")
    end

    if new_attributes[:password_change_required] == 'true' &&
       new_attributes[:password_never_expires]   == 'true'
      raise ArgumentError, _("Cannot have password_change_required == true and password_never_expires == true! Reason: password_change_required is enforced by immediately expiring the password. For a password that never expires, Windows will throw an 'Access Denied' error when you try to change the password upon the first login.")
    end
  end

  def attributes=(new_attributes)
    # Validate the new attributes
    validate_attributes(new_attributes)

    # Set them on the system
    new_attributes.each do |attribute, value|
      info = managed_attributes[attribute]
      next if info[:getter].call(self) == value

      info[:setter].call(self, value)
    end
  rescue ArgumentError, Puppet::Error => detail
    raise Puppet::Error, _("Could not set the attributes property on %{resource}[%{name}]: %{detail}") % { resource: @resource.class.name, name: @resource.name, detail: detail }, detail.backtrace
  end

  [:gid, :shell].each do |prop|
    define_method(prop) { nil }
    define_method("#{prop}=") do |v|
      fail "No support for managing property #{prop} of user #{@resource[:name]} on Windows"
    end
  end

  def self.instances
    Puppet::Util::Windows::ADSI::User.map { |u| new(:ensure => :present, :name => u.name) }
  end
end
