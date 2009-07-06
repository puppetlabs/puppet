Puppet::Type.newtype(:macauthorization) do

    @doc = "Manage the Mac OS X authorization database.
            See:
            http://developer.apple.com/documentation/Security/Conceptual/Security_Overview/Security_Services/chapter_4_section_5.html for more information."

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
        begin
          Integer(value)
        rescue ArgumentError
          fail("munge_integer only takes integers")
        end
    end

    newparam(:name) do
        desc "The name of the right or rule to be managed.
        Corresponds to 'key' in Authorization Services. The key is the name
        of a rule. A key uses the same naming conventions as a right. The
        Security Server uses a rule’s key to match the rule with a right.
        Wildcard keys end with a ‘.’. The generic rule has an empty key value.
        Any rights that do not match a specific rule use the generic rule."

        isnamevar
    end

    newproperty(:auth_type) do
        desc "type - can be a 'right' or a 'rule'. 'comment' has not yet been
        implemented."

        newvalue(:right)
        newvalue(:rule)
        # newvalue(:comment)  # not yet implemented.
    end

    newproperty(:allow_root, :boolean => true) do
        desc "Corresponds to 'allow-root' in the authorization store, renamed
        due to hyphens being problematic. Specifies whether a right should be
        allowed automatically if the requesting process is running with
        uid == 0.  AuthorizationServices defaults this attribute to false if
        not specified"

        newvalue(:true)
        newvalue(:false)

        munge do |value|
            @resource.munge_boolean(value)
        end
    end

    newproperty(:authenticate_user, :boolean => true) do
        desc "Corresponds to 'authenticate-user' in the authorization store,
        renamed due to hyphens being problematic."

        newvalue(:true)
        newvalue(:false)

        munge do |value|
            @resource.munge_boolean(value)
        end
    end

    newproperty(:auth_class) do
        desc "Corresponds to 'class' in the authorization store, renamed due
        to 'class' being a reserved word."

        newvalue(:user)
        newvalue(:'evaluate-mechanisms')
        newvalue(:allow)
        newvalue(:deny)
        newvalue(:rule)
    end

    newproperty(:comment) do
        desc "The 'comment' attribute for authorization resources."
    end

    newproperty(:group) do
        desc "The user must authenticate as a member of this group. This
        attribute can be set to any one group."
    end

    newproperty(:k_of_n) do
        desc "k-of-n describes how large a subset of rule mechanisms must
        succeed for successful authentication. If there are 'n' mechanisms,
        then 'k' (the integer value of this parameter) mechanisms must succeed.
        The most common setting for this parameter is '1'. If k-of-n is not
        set, then 'n-of-n' mechanisms must succeed."
        
        munge do |value|
            @resource.munge_integer(value)
        end
    end

    newproperty(:mechanisms, :array_matching => :all) do
        desc "an array of suitable mechanisms."
    end

    newproperty(:rule, :array_matching => :all) do
        desc "The rule(s) that this right refers to."
    end

    newproperty(:session_owner, :boolean => true) do
        desc "Corresponds to 'session-owner' in the authorization store,
        renamed due to hyphens being problematic.  Whether the session owner
        automatically matches this rule or right."

        newvalue(:true)
        newvalue(:false)

        munge do |value|
            @resource.munge_boolean(value)
        end
    end

    newproperty(:shared, :boolean => true) do
        desc "If this is set to true, then the Security Server marks the
        credentials used to gain this right as shared. The Security Server
        may use any shared credentials to authorize this right. For maximum
        security, set sharing to false so credentials stored by the Security
        Server for one application may not be used by another application."

        newvalue(:true)
        newvalue(:false)

        munge do |value|
            @resource.munge_boolean(value)
        end
    end

    newproperty(:timeout) do
        desc "The credential used by this rule expires in the specified
        number of seconds. For maximum security where the user must
        authenticate every time, set the timeout to 0. For minimum security,
        remove the timeout attribute so the user authenticates only once per
        session."
        
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
