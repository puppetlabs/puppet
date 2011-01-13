require 'puppet/property/list'
require 'puppet/property/keyvalue'

module Puppet
  newtype(:project) do

    @doc = "Manages projects in `/etc/project`.  Projects are used in Solaris
      to control resource usage for collections of processes."

    ensurable

    newparam(:name) do
      desc "The name of the project.  The name must be a string of
        alphanumeric characters, underlines, hyphens and periods."

      isnamevar

      validate do |value|
        raise Puppet::Error, "#{value} is an invalid project name" unless value =~ /^[A-Za-z0-9_\.-]+$/
      end

    end

    newproperty(:projid) do
      desc "The unique id of the project."

      validate do |value|
        raise Puppet::Error, "projid has to be numeric, not #{value}" unless value =~ /^[0-9]+$/
        raise Puppet::Error, "projid #{value} out of range (0-#{2**31-1})" unless (0...2**31).include?(Integer(value))
      end
    end

    newproperty(:comment) do
      desc "Description of the project."

      validate do |value|
        raise Puppet::Error, "comment must not contain a colon: #{value}" if value.include?(':')
      end
    end

    newproperty(:users, :parent => Puppet::Property::List) do
      desc "A list of usernames that are allowed to use the project. Multiple
        users have to be specified as an array."

      validate do |value|
        raise Puppet::Error, 'multiple users have to be specified as an array, not a comma separated list' if value.include?(',')
      end

      def membership
        :user_membership
      end
    end

    newproperty(:groups, :parent => Puppet::Property::List) do
      desc "A list of groupnames that are allowed to use the project. Multiple
        groups have to be specified as an array."

      validate do |value|
        raise Puppet::Error, 'multiple groups have to be specified as an array, not a comma separated list' if value.include?(',')
      end

      def membership
        :group_membership
      end
    end

    newproperty(:attributes, :parent => Puppet::Property::KeyValue) do
      desc "A list of attributes for the project.  A single attribute must be of the form key[=value] where value
        can be optional.  Multiple key-value pairs have to be specified as an array."

      validate do |value|
        raise Puppet::Error, 'multiple attributes have to be specified as an array, not a comma separated list' if value.include?(';')
      end

      def membership
        :attribute_membership
      end

      # The following overwrites are ugly but the KeyValue property has a weired default
      # behaviour (because it looks like it is designed for a single usecase: usermod)

      # If the user specified inclusive we dont have to merge the is value and the should
      # value, so we just merge should with an empty hash.  If inclusive is false we
      # merge current and should
      def process_current_hash(current)
        return {} if current == :absent or inclusive?
        current
      end

      # turn a string array into a hash where the value part itself can
      # include multiple equal signes
      def hashify(key_value_array)
        key_value_array.inject({}) do |hash, assignment|
          (k,v) = assignment.split('=',2)
          hash[k.intern] = v
          hash
        end
      end

    end

    newparam(:user_membership) do
      desc "Whether the specified users should be treated as the only
        ones or whether they should merely be treated as the minimum
        membership list."

      newvalues :inclusive, :minimum

      defaultto :minimum
    end

    newparam(:group_membership) do
      desc "Whether the specified groups should be treated as the only
        ones or whether they should merely be treated as the minimum
        membership list."

      newvalues :inclusive, :minimum

      defaultto :minimum
    end

    newparam(:attribute_membership) do
      desc "Whether the specified attributes should be treated as
        the only attributes of the project or whether they should
        merely be treated as the minimum list."

      newvalues :inclusive, :minimum

      defaultto :minimum
    end

    autorequire(:user) do
      # Puppet::Property::List.should joins our Array,
      # so we have to split again.
      req = []
      if user_list = self[:users]
        req += user_list.split(',')
      end
      req
    end

    autorequire(:group) do
      # Puppet::Property::List.should joins our Array,
      # so we have to split again.
      req = []
      if group_list = self[:groups]
        req += group_list.split(',')
      end
      req
    end

  end
end
