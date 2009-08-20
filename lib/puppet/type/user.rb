require 'etc'
require 'facter'
require 'puppet/property/list'
require 'puppet/property/ordered_list'
require 'puppet/property/keyvalue'

module Puppet
    newtype(:user) do
        @doc = "Manage users.  This type is mostly built to manage system
            users, so it is lacking some features useful for managing normal
            users.

            This resource type uses the prescribed native tools for creating
            groups and generally uses POSIX APIs for retrieving information
            about them.  It does not directly modify /etc/passwd or anything."

        feature :allows_duplicates,
            "The provider supports duplicate users with the same UID."

        feature :manages_homedir,
            "The provider can create and remove home directories."

        feature :manages_passwords,
            "The provider can modify user passwords, by accepting a password
            hash."

        feature :manages_solaris_rbac,
            "The provider can manage roles and normal users"

        newproperty(:ensure, :parent => Puppet::Property::Ensure) do
            newvalue(:present, :event => :user_created) do
                provider.create
            end

            newvalue(:absent, :event => :user_removed) do
                provider.delete
            end

            newvalue(:role, :event => :role_created, :required_features => :manages_solaris_rbac) do
                provider.create_role
            end

            desc "The basic state that the object should be in."

            # If they're talking about the thing at all, they generally want to
            # say it should exist.
            defaultto do
                if @resource.managed?
                    :present
                else
                    nil
                end
            end

            def retrieve
                if provider.exists?
                    if provider.respond_to?(:is_role?) and provider.is_role?
                        return :role
                    else
                        return :present
                    end
                else
                    return :absent
                end
            end
        end

        newproperty(:uid) do
            desc "The user ID.  Must be specified numerically.  For new users
                being created, if no user ID is specified then one will be
                chosen automatically, which will likely result in the same user
                having different IDs on different systems, which is not
                recommended.  This is especially noteworthy if you use Puppet
                to manage the same user on both Darwin and other platforms,
                since Puppet does the ID generation for you on Darwin, but the
                tools do so on other platforms."

            munge do |value|
                case value
                when String
                    if value =~ /^[-0-9]+$/
                        value = Integer(value)
                    end
                end

                return value
            end
        end

        newproperty(:gid) do
            desc "The user's primary group.  Can be specified numerically or
                by name."

            munge do |value|
                if value.is_a?(String) and value =~ /^[-0-9]+$/
                    Integer(value)
                else
                    value
                end
            end

            def insync?(is)
                return true unless self.should

                # We know the 'is' is a number, so we need to convert the 'should' to a number,
                # too.
                @should.each do |value|
                    return true if number = Puppet::Util.gid(value) and is == number
                end

                return false
            end

            def sync
                found = false
                @should.each do |value|
                    if number = Puppet::Util.gid(value)
                        provider.gid = number
                        found = true
                        break
                    end
                end

                fail "Could not find group(s) %s" % @should.join(",") unless found

                # Use the default event.
            end
        end

        newproperty(:comment) do
            desc "A description of the user.  Generally is a user's full name."
        end

        newproperty(:home) do
            desc "The home directory of the user.  The directory must be created
                separately and is not currently checked for existence."
        end

        newproperty(:shell) do
            desc "The user's login shell.  The shell must exist and be
                executable."
        end

        newproperty(:password, :required_features => :manages_passwords) do
            desc "The user's password, in whatever encrypted format the local machine requires. Be sure to enclose any value that includes a dollar sign ($) in single quotes (\')."

            validate do |value|
                raise ArgumentError, "Passwords cannot include ':'" if value.is_a?(String) and value.include?(":")
            end

            def change_to_s(currentvalue, newvalue)
                if currentvalue == :absent
                  return "created password"
                else
                  return "changed password"
                end
            end
        end


        newproperty(:groups, :parent => Puppet::Property::List) do
            desc "The groups of which the user is a member.  The primary
                group should not be listed.  Multiple groups should be
                specified as an array."

            validate do |value|
                if value =~ /^\d+$/
                    raise ArgumentError, "Group names must be provided, not numbers"
                end
                if value.include?(",")
                    raise ArgumentError, "Group names must be provided as an array, not a comma-separated list"
                end
            end
        end

        newparam(:name) do
            desc "User name.  While limitations are determined for
                each operating system, it is generally a good idea to keep to
                the degenerate 8 characters, beginning with a letter."
            isnamevar
        end

        newparam(:membership) do
            desc "Whether specified groups should be treated as the only groups
                of which the user is a member or whether they should merely
                be treated as the minimum membership list."

            newvalues(:inclusive, :minimum)

            defaultto :minimum
        end

        newparam(:allowdupe, :boolean => true) do
            desc "Whether to allow duplicate UIDs."

            newvalues(:true, :false)

            defaultto false
        end

        newparam(:managehome, :boolean => true) do
            desc "Whether to manage the home directory when managing the user."

            newvalues(:true, :false)

            defaultto false

            validate do |val|
                if val.to_s == "true"
                    unless provider.class.manages_homedir?
                        raise ArgumentError, "User provider %s can not manage home directories" % provider.class.name
                    end
                end
            end
        end

        # Autorequire the group, if it's around
        autorequire(:group) do
            autos = []

            if obj = @parameters[:gid] and groups = obj.shouldorig
                groups = groups.collect { |group|
                    if group =~ /^\d+$/
                        Integer(group)
                    else
                        group
                    end
                }
                groups.each { |group|
                    case group
                    when Integer
                        if resource = catalog.resources.find { |r| r.is_a?(Puppet::Type.type(:group)) and r.should(:gid) == group }
                            autos << resource
                        end
                    else
                        autos << group
                    end
                }
            end

            if obj = @parameters[:groups] and groups = obj.should
                autos += groups.split(",")
            end

            autos
        end

        # Provide an external hook.  Yay breaking out of APIs.
        def exists?
            provider.exists?
        end

        def retrieve
            absent = false
            properties().inject({}) { |prophash, property|
                current_value = :absent

                if absent
                    prophash[property] = :absent
                else
                    current_value = property.retrieve
                    prophash[property] = current_value
                end

                if property.name == :ensure and current_value == :absent
                    absent = true
                end
                prophash
            }
        end

        newproperty(:roles, :parent => Puppet::Property::List, :required_features => :manages_solaris_rbac) do
            desc "The roles the user has.  Multiple roles should be
                specified as an array."

            def membership
                :role_membership
            end

            validate do |value|
                if value =~ /^\d+$/
                    raise ArgumentError, "Role names must be provided, not numbers"
                end
                if value.include?(",")
                    raise ArgumentError, "Role names must be provided as an array, not a comma-separated list"
                end
            end
        end

        #autorequire the roles that the user has
        autorequire(:user) do
            reqs = []

            if roles_property = @parameters[:roles] and roles = roles_property.should
                reqs += roles.split(',')
            end

            reqs
        end

        newparam(:role_membership) do
            desc "Whether specified roles should be treated as the only roles
                of which the user is a member or whether they should merely
                be treated as the minimum membership list."

            newvalues(:inclusive, :minimum)

            defaultto :minimum
        end

        newproperty(:auths, :parent => Puppet::Property::List, :required_features => :manages_solaris_rbac) do
            desc "The auths the user has.  Multiple auths should be
                specified as an array."

            def membership
                :auth_membership
            end

            validate do |value|
                if value =~ /^\d+$/
                    raise ArgumentError, "Auth names must be provided, not numbers"
                end
                if value.include?(",")
                    raise ArgumentError, "Auth names must be provided as an array, not a comma-separated list"
                end
            end
        end

        newparam(:auth_membership) do
            desc "Whether specified auths should be treated as the only auths
                of which the user is a member or whether they should merely
                be treated as the minimum membership list."

            newvalues(:inclusive, :minimum)

            defaultto :minimum
        end

        newproperty(:profiles, :parent => Puppet::Property::OrderedList, :required_features => :manages_solaris_rbac) do
            desc "The profiles the user has.  Multiple profiles should be
                specified as an array."

            def membership
                :profile_membership
            end

            validate do |value|
                if value =~ /^\d+$/
                    raise ArgumentError, "Profile names must be provided, not numbers"
                end
                if value.include?(",")
                    raise ArgumentError, "Profile names must be provided as an array, not a comma-separated list"
                end
            end
        end

        newparam(:profile_membership) do
            desc "Whether specified roles should be treated as the only roles
                of which the user is a member or whether they should merely
                be treated as the minimum membership list."

            newvalues(:inclusive, :minimum)

            defaultto :minimum
        end

        newproperty(:keys, :parent => Puppet::Property::KeyValue, :required_features => :manages_solaris_rbac) do
            desc "Specify user attributes in an array of keyvalue pairs"

            def membership
                :key_membership
            end

            validate do |value|
                unless value.include?("=")
                    raise ArgumentError, "key value pairs must be seperated by an ="
                end
            end
        end

        newparam(:key_membership) do
            desc "Whether specified key value pairs should be treated as the only attributes
                of the user or whether they should merely
                be treated as the minimum list."

            newvalues(:inclusive, :minimum)

            defaultto :minimum
        end

        newproperty(:project, :required_features => :manages_solaris_rbac) do
            desc "The name of the project associated with a user"
        end
    end
end

