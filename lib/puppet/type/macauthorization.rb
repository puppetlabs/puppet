Puppet::Type.newtype(:macauthorization) do

  @doc = "Manage the Mac OS X authorization database. See the
    [Apple developer site](https://developer.apple.com/library/content/documentation/Security/Conceptual/Security_Overview/AuthenticationAndAuthorization/AuthenticationAndAuthorization.html)
    for more information.

    Note that authorization store directives with hyphens in their names have
    been renamed to use underscores, as Puppet does not react well to hyphens
    in identifiers.

    **Autorequires:** If Puppet is managing the `/etc/authorization` file, each
    macauthorization resource will autorequire it."

  ensurable

  autorequire(:file) do
    ["/etc/authorization"]
  end

  def munge_boolean(value)
    case value
    when true, "true", :true
      :true
    when false, "false", :false
      :false
    else
      fail("munge_boolean only takes booleans")
    end
  end

  def munge_integer(value)
      Integer(value)
  rescue ArgumentError
      fail _("munge_integer only takes integers")
  end

  newparam(:name) do
    desc "The name of the right or rule to be managed.
    Corresponds to `key` in Authorization Services. The key is the name
    of a rule. A key uses the same naming conventions as a right. The
    Security Server uses a rule's key to match the rule with a right.
    Wildcard keys end with a '.'. The generic rule has an empty key value.
    Any rights that do not match a specific rule use the generic rule."

    isnamevar
  end

  newproperty(:auth_type) do
    desc "Type --- this can be a `right` or a `rule`. The `comment` type has
    not yet been implemented."

    newvalue(:right)
    newvalue(:rule)
    # newvalue(:comment)  # not yet implemented.
  end

  newproperty(:allow_root, :boolean => true) do
    desc "Corresponds to `allow-root` in the authorization store. Specifies
    whether a right should be allowed automatically if the requesting process
    is running with `uid == 0`.  AuthorizationServices defaults this attribute
    to false if not specified."

    newvalue(:true)
    newvalue(:false)

    munge do |value|
      @resource.munge_boolean(value)
    end
  end

  newproperty(:authenticate_user, :boolean => true) do
    desc "Corresponds to `authenticate-user` in the authorization store."

    newvalue(:true)
    newvalue(:false)

    munge do |value|
      @resource.munge_boolean(value)
    end
  end

  newproperty(:auth_class) do
    desc "Corresponds to `class` in the authorization store; renamed due
    to 'class' being a reserved word in Puppet."

    newvalue(:user)
    newvalue(:'evaluate-mechanisms')
    newvalue(:allow)
    newvalue(:deny)
    newvalue(:rule)
  end

  newproperty(:comment) do
    desc "The `comment` attribute for authorization resources."
  end

  newproperty(:group) do
    desc "A group which the user must authenticate as a member of. This
    must be a single group."
  end

  newproperty(:k_of_n) do
    desc "How large a subset of rule mechanisms must succeed for successful
    authentication. If there are 'n' mechanisms, then 'k' (the integer value
    of this parameter) mechanisms must succeed. The most common setting for
    this parameter is `1`. If `k-of-n` is not set, then every mechanism ---
    that is, 'n-of-n' --- must succeed."

    munge do |value|
      @resource.munge_integer(value)
    end
  end

  newproperty(:mechanisms, :array_matching => :all) do
    desc "An array of suitable mechanisms."
  end

  newproperty(:rule, :array_matching => :all) do
    desc "The rule(s) that this right refers to."
  end

  newproperty(:session_owner, :boolean => true) do
    desc "Whether the session owner automatically matches this rule or right.
    Corresponds to `session-owner` in the authorization store."

    newvalue(:true)
    newvalue(:false)

    munge do |value|
      @resource.munge_boolean(value)
    end
  end

  newproperty(:shared, :boolean => true) do
    desc "Whether the Security Server should mark the credentials used to gain
    this right as shared. The Security Server may use any shared credentials
    to authorize this right. For maximum security, set sharing to false so
    credentials stored by the Security Server for one application may not be
    used by another application."

    newvalue(:true)
    newvalue(:false)

    munge do |value|
      @resource.munge_boolean(value)
    end
  end

  newproperty(:timeout) do
    desc "The number of seconds in which the credential used by this rule will
    expire. For maximum security where the user must authenticate every time,
    set the timeout to 0. For minimum security, remove the timeout attribute
    so the user authenticates only once per session."

    munge do |value|
      @resource.munge_integer(value)
    end
  end

  newproperty(:tries) do
    desc "The number of tries allowed."
    munge do |value|
      @resource.munge_integer(value)
    end
  end

end
