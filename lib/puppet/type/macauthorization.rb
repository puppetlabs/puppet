require 'ruby-debug'

Puppet::Type.newtype(:macauthorization) do
    
    @doc = "Manage authorization databases"
    
    ensurable
    
    autorequire(:file) do
        ["/etc/authorization"]
    end
    
    # This probably shouldn't be necessary for properties that have declared
    # themselves to be booleans already.
    def munge_boolean(value)
        case value
        when true, "true", :true:
            :true
        when false, "false", :false
            :false
        else
            raise Puppet::Error("munge_boolean only takes booleans")
        end
    end
    
    newparam(:name) do
        desc "The name of the right or rule to be managed."
        isnamevar
    end
    
    newproperty(:auth_type) do
        desc "type - can be a right a rule or a comment"
        newvalue(:right)
        newvalue(:rule)
        newvalue(:comment)
    end
    
    newproperty(:allow_root, :boolean => true) do
        desc "Corresponds to 'allow-root' in the authorization store. hyphens not allowed..."
        newvalue(:true)
        newvalue(:false)
        
        munge do |value|
            @resource.munge_boolean(value)
        end
    end
    
    newproperty(:authenticate_user, :boolean => true) do
        desc "authenticate-user"
        newvalue(:true)
        newvalue(:false)
        
        munge do |value|
            @resource.munge_boolean(value)
        end
    end

    newproperty(:auth_class) do
        desc "Corresponds to 'class' in the authorization store. class is
        a reserved word in Puppet syntax, so we use 'authclass'."
        newvalue(:user)
        newvalue(:'evaluate-mechanisms')
    end
    
    newproperty(:comment) do
        desc "Comment. simple enough eh?"
    end
    
    newproperty(:group) do
        desc "group"
    end
    
    newproperty(:k_of_n) do
        desc "k-of-n. odd."
    end
    
    newproperty(:mechanisms, :array_match => :all) do
        desc "mechanisms"
    end
    
    newproperty(:rule, :array_match => :all) do
        desc "rule"
    end    
    
    newproperty(:shared, :boolean => true) do
        desc "shared"
        newvalue(:true)
        newvalue(:false)
        
        munge do |value|
            @resource.munge_boolean(value)
        end
    end
    
end
