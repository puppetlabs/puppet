#
# User Puppet provider for AIX. It uses standard commands to manage users:
#  mkuser, rmuser, lsuser, chuser
#
# Notes:
# - AIX users can have expiry date defined with minute granularity,
#   but puppet does not allow it. There is a ticket open for that (#5431)
# - AIX maximum password age is in WEEKs, not days
#
# See  https://docs.puppetlabs.com/guides/provider_development.html
# for more information
#
# Author::    Hector Rivas Gandara <keymon@gmail.com>
#
require 'puppet/provider/aixobject'
require 'tempfile'
require 'date'

Puppet::Type.type(:user).provide :aix, :parent => Puppet::Provider::AixObject do
  desc "User management for AIX."

  # This will the default provider for this platform
  defaultfor :operatingsystem => :aix
  confine :operatingsystem => :aix

  # Commands that manage the element
  commands :list      => "/usr/sbin/lsuser"
  commands :add       => "/usr/bin/mkuser"
  commands :delete    => "/usr/sbin/rmuser"
  commands :modify    => "/usr/bin/chuser"

  commands :lsgroup   => "/usr/sbin/lsgroup"
  commands :chpasswd  => "/bin/chpasswd"

  # Provider features
  has_features :manages_aix_lam
  has_features :manages_homedir, :manages_passwords, :manages_shell
  has_features :manages_expiry,  :manages_password_age

  # Attribute verification (TODO)
  #verify :gid, "GID must be a string or int of a valid group" do |value|
  #  value.is_a? String || value.is_a? Integer
  #end
  #
  #verify :groups, "Groups must be comma-separated" do |value|
  #  value !~ /\s/
  #end

  # User attributes to ignore from AIX output.
  def self.attribute_ignore
    ["name"]
  end

  # AIX attributes to properties mapping.
  #
  # Valid attributes to be managed by this provider.
  # It is a list with of hash
  #  :aix_attr      AIX command attribute name
  #  :puppet_prop   Puppet propertie name
  #  :to            Method to adapt puppet property to aix command value. Optional.
  #  :from          Method to adapt aix command value to puppet property. Optional
  self.attribute_mapping = [
    {:aix_attr => :pgrp,       :puppet_prop => :gid,
                                :to => :gid_to_attr,
                                :from => :gid_from_attr },
    {:aix_attr => :id,         :puppet_prop => :uid},
    {:aix_attr => :groups,     :puppet_prop => :groups},
    {:aix_attr => :home,       :puppet_prop => :home},
    {:aix_attr => :shell,      :puppet_prop => :shell},
    {:aix_attr => :expires,    :puppet_prop => :expiry,
                                :to => :expiry_to_attr,
                                :from => :expiry_from_attr },
    {:aix_attr => :maxage,     :puppet_prop => :password_max_age},
    {:aix_attr => :minage,     :puppet_prop => :password_min_age},
    {:aix_attr => :attributes, :puppet_prop => :attributes},
    { :aix_attr => :gecos,      :puppet_prop => :comment },
  ]

  #--------------
  # Command definition

  # Return the IA module arguments based on the resource param ia_load_module
  def get_ia_module_args
    if @resource[:ia_load_module]
      ["-R", @resource[:ia_load_module].to_s]
    else
      []
    end
  end

  # List groups and Ids
  def lsgroupscmd(value=@resource[:name])
    [command(:lsgroup)] +
      self.get_ia_module_args +
      ["-a", "id", value]
  end

  def lscmd(value=@resource[:name])
    [self.class.command(:list), "-c"] + self.get_ia_module_args + [ value]
  end

  def lsallcmd()
    lscmd("ALL")
  end

  def addcmd(extra_attrs = [])
    # Here we use the @resource.to_hash to get the list of provided parameters
    # Puppet does not call to self.<parameter>= method if it does not exists.
    #
    # It gets an extra list of arguments to add to the user.
    [self.class.command(:add)] + self.get_ia_module_args +
      self.hash2args(@resource.to_hash) +
      extra_attrs + [@resource[:name]]
  end

  # Get modify command. Set translate=false if no mapping must be used.
  # Needed for special properties like "attributes"
  def modifycmd(hash = property_hash)
    args = self.hash2args(hash)
    return nil if args.empty?

    [self.class.command(:modify)] + self.get_ia_module_args +
      args + [@resource[:name]]
  end

  def deletecmd
    [self.class.command(:delete)] + self.get_ia_module_args + [@resource[:name]]
  end

  #--------------
  # We overwrite the create function to change the password after creation.
  def create
    super
    # Reset the password if needed
    self.password = @resource[:password] if @resource[:password]
  end


  def get_arguments(key, value, mapping, objectinfo)
    # In the case of attributes, return a list of key=vlaue
    if key == :attributes
      raise Puppet::Error, "Attributes must be a list of pairs key=value on #{@resource.class.name}[#{@resource.name}]" \
        unless value and value.is_a? Hash
      return value.map { |k,v| k.to_s.strip + "=" + v.to_s.strip}
    end

    super(key, value, mapping, objectinfo)
  end

  # Get the groupname from its id
  def groupname_by_id(gid)
    groupname=nil
    execute(lsgroupscmd("ALL")).each_line { |entry|
      attrs = self.parse_attr_list(entry, nil)
      if attrs and attrs.include? :id and gid == attrs[:id].to_i
        groupname = entry.split(" ")[0]
      end
    }
    groupname
  end

  # Get the groupname from its id
  def groupid_by_name(groupname)
    attrs = self.parse_attr_list(execute(lsgroupscmd(groupname)).split("\n")[0], nil)
    attrs ? attrs[:id].to_i : nil
  end

  # Check that a group exists and is valid
  def verify_group(value)
    if value.is_a? Integer or value.is_a? Fixnum
      groupname = groupname_by_id(value)
      raise ArgumentError, "AIX group must be a valid existing group" unless groupname
    else
      raise ArgumentError, "AIX group must be a valid existing group" unless groupid_by_name(value)
      groupname = value
    end
    groupname
  end

  # The user's primary group.  Can be specified numerically or by name.
  def gid_to_attr(value)
    verify_group(value)
  end

  # Get the group gid from its name
  def gid_from_attr(value)
    groupid_by_name(value)
  end

  # The expiry date for this user. Must be provided in
  # a zero padded YYYY-MM-DD HH:MM format
  def expiry_to_attr(value)
    # For chuser the expires parameter is a 10-character string in the MMDDhhmmyy format
    # that is,"%m%d%H%M%y"
    newdate = '0'
    if value.is_a? String and value!="0000-00-00"
      d = DateTime.parse(value, "%Y-%m-%d %H:%M")
      newdate = d.strftime("%m%d%H%M%y")
    end
    newdate
  end

  def expiry_from_attr(value)
    if value =~ /(..)(..)(..)(..)(..)/
      #d= DateTime.parse("20#{$5}-#{$1}-#{$2} #{$3}:#{$4}")
      #expiry_date = d.strftime("%Y-%m-%d %H:%M")
      #expiry_date = d.strftime("%Y-%m-%d")
      expiry_date = "20#{$5}-#{$1}-#{$2}"
    else
      Puppet.warn("Could not convert AIX expires date '#{value}' on #{@resource.class.name}[#{@resource.name}]") \
        unless value == '0'
      expiry_date = :absent
    end
    expiry_date
  end

  def open_security_passwd
    # helper method for tests
    File.open("/etc/security/passwd", 'r')
  end

  #--------------------------------
  # Getter and Setter
  # When the provider is initialized, create getter/setter methods for each
  # property our resource type supports.
  # If setter or getter already defined it will not be overwritten

  #- **password**
  #    The user's password, in whatever encrypted format the local machine
  #    requires. Be sure to enclose any value that includes a dollar sign ($)
  #    in single quotes (').  Requires features manages_passwords.
  #
  # Retrieve the password parsing directly the /etc/security/passwd
  def password
    password = :absent
    user = @resource[:name]
    f = open_security_passwd
    # Skip to the user
    f.each_line { |l| break if l  =~ /^#{user}:\s*$/ }
    if ! f.eof?
      f.each_line { |l|
        # If there is a new user stanza, stop
        break if l  =~ /^\S*:\s*$/
        # If the password= entry is found, return it, stripping trailing space
        if l  =~ /^\s*password\s*=\s*(\S*)\s*$/
          password = $1; break;
        end
      }
    end
    f.close()
    return password
  end

  def password=(value)
    user = @resource[:name]

    # Puppet execute does not support strings as input, only files.
    tmpfile = Tempfile.new('puppet_#{user}_pw')
    tmpfile << "#{user}:#{value}\n"
    tmpfile.close()

    # Options '-e', '-c', use encrypted password and clear flags
    # Must receive "user:enc_password" as input
    # command, arguments = {:failonfail => true, :combine => true}
    # Fix for bugs #11200 and #10915
    cmd = [self.class.command(:chpasswd), get_ia_module_args, '-e', '-c', user].flatten
    begin
      output = execute(cmd, {:failonfail => false, :combine => true, :stdinfile => tmpfile.path })
      # chpasswd can return 1, even on success (at least on AIX 6.1); empty output indicates success
      if output != ""
        raise Puppet::ExecutionFailure, "chpasswd said #{output}"
      end
    rescue Puppet::ExecutionFailure  => detail
      raise Puppet::Error, "Could not set #{param} on #{@resource.class.name}[#{@resource.name}]: #{detail}", detail.backtrace
    ensure
      tmpfile.delete()
    end
  end

  def managed_attribute_keys(hash)
    managed_attributes ||= @resource.original_parameters[:attributes] || hash.keys.map{|k| k.to_s}
    managed_attributes.map {|attr| key, value = attr.split("="); key.strip.to_sym}
  end

  def should_include?(key, managed_keys)
    !self.class.attribute_mapping_from.include?(key) and
            !self.class.attribute_ignore.include?(key) and
            managed_keys.include?(key)
  end

  def filter_attributes(hash)
    # Return only managed attributtes.
    managed_keys = managed_attribute_keys(hash)
    results = hash.select {
        |k,v| should_include?(k, managed_keys)
      }.inject({}) {
        |h, array| h[array[0]] = array[1]; h
      }
    results
  end

  def attributes
    filter_attributes(getosinfo(false))
  end

  def attributes=(attr_hash)
    #self.class.validate(param, value)
    param = :attributes
    cmd = modifycmd({param => filter_attributes(attr_hash)})
    if cmd
      begin
        execute(cmd)
      rescue Puppet::ExecutionFailure  => detail
        raise Puppet::Error, "Could not set #{param} on #{@resource.class.name}[#{@resource.name}]: #{detail}", detail.backtrace
      end
    end
  end

  # UNSUPPORTED
  #- **profile_membership**
  #    Whether specified roles should be treated as the only roles
  #    of which the user is a member or whether they should merely
  #    be treated as the minimum membership list.  Valid values are
  #    `inclusive`, `minimum`.
  # UNSUPPORTED
  #- **profiles**
  #    The profiles the user has.  Multiple profiles should be
  #    specified as an array.  Requires features manages_solaris_rbac.
  # UNSUPPORTED
  #- **project**
  #    The name of the project associated with a user  Requires features
  #    manages_solaris_rbac.
  # UNSUPPORTED
  #- **role_membership**
  #    Whether specified roles should be treated as the only roles
  #    of which the user is a member or whether they should merely
  #    be treated as the minimum membership list.  Valid values are
  #    `inclusive`, `minimum`.
  # UNSUPPORTED
  #- **roles**
  #    The roles the user has.  Multiple roles should be
  #    specified as an array.  Requires features manages_solaris_rbac.
  # UNSUPPORTED
  #- **key_membership**
  #    Whether specified key value pairs should be treated as the only
  #    attributes
  #    of the user or whether they should merely
  #    be treated as the minimum list.  Valid values are `inclusive`,
  #    `minimum`.
  # UNSUPPORTED
  #- **keys**
  #    Specify user attributes in an array of keyvalue pairs  Requires features
  #    manages_solaris_rbac.
  # UNSUPPORTED
  #- **allowdupe**
  #  Whether to allow duplicate UIDs.  Valid values are `true`, `false`.
  # UNSUPPORTED
  #- **auths**
  #    The auths the user has.  Multiple auths should be
  #    specified as an array.  Requires features manages_solaris_rbac.
  # UNSUPPORTED
  #- **auth_membership**
  #    Whether specified auths should be treated as the only auths
  #    of which the user is a member or whether they should merely
  #    be treated as the minimum membership list.  Valid values are
  #    `inclusive`, `minimum`.
  # UNSUPPORTED

end
