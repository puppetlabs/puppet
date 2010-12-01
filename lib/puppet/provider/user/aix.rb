#
# User Puppet provider for AIX. It uses standar commands to manage users:
#  mkuser, rmuser, lsuser, chuser
#
# Notes:
# - AIX users can have expiry date defined with minute granularity,
#   but puppet does not allow it. There is a ticket open for that (#5431)
# - AIX maximum password age is in WEEKs, not days
# - I force the compat IA module. 
#
# See  http://projects.puppetlabs.com/projects/puppet/wiki/Development_Provider_Development
# for more information
#
# Author::    Hector Rivas Gandara <keymon@gmail.com>
#
# TODO::
#  - Add new AIX specific attributes, specilly registry and SYSTEM.
#  
require 'puppet/provider/aixobject'
require 'tempfile'
require 'date'

Puppet::Type.type(:user).provide :aix, :parent => Puppet::Provider::AixObject do
  desc "User management for AIX! Users are managed with mkuser, rmuser, chuser, lsuser"

  # Constants
  # Default extra attributes to add when element is created
  # registry=compat SYSTEM=compat: Needed if you are using LDAP by default.
  @DEFAULT_EXTRA_ATTRS = [ "registry=compat", " SYSTEM=compat" ]

  # This will the the default provider for this platform
  defaultfor :operatingsystem => :aix
  confine :operatingsystem => :aix

  # Commands that manage the element
  commands :lsgroup    => "/usr/sbin/lsgroup"
  
  commands :list      => "/usr/sbin/lsuser"
  commands :add       => "/usr/bin/mkuser"
  commands :delete    => "/usr/sbin/rmuser"
  commands :modify    => "/usr/bin/chuser"
  commands :chpasswd  => "/bin/chpasswd"

  # Provider features
  has_features :manages_homedir, :manages_passwords, :manages_expiry, :manages_password_age

  # Attribute verification (TODO)
  #verify :gid, "GID must be an string or int of a valid group" do |value|
  #  value.is_a? String || value.is_a? Integer
  #end
  #
  #verify :groups, "Groups must be comma-separated" do |value|
  #  value !~ /\s/
  #end

  # AIX attributes to properties mapping.
  # 
  # Valid attributes to be managed by this provider.
  # It is a list with of hash
  #  :aix_attr      AIX command attribute name
  #  :puppet_prop   Puppet propertie name
  #  :to            Method to adapt puppet property to aix command value. Optional.
  #  :from            Method to adapt aix command value to puppet property. Optional
  self.attribute_mapping = [
    #:name => :name,
    {:aix_attr => :pgrp,     :puppet_prop => :gid,
        :to => :gid_to_attr, :from => :gid_from_attr},
    {:aix_attr => :id,       :puppet_prop => :uid},
    {:aix_attr => :groups,   :puppet_prop => :groups},
    {:aix_attr => :home,     :puppet_prop => :home},
    {:aix_attr => :shell,    :puppet_prop => :shell},
    {:aix_attr => :expires,  :puppet_prop => :expiry,
        :to => :expiry_to_attr, :from => :expiry_from_attr},
    {:aix_attr => :maxage,   :puppet_prop => :password_max_age},
    {:aix_attr => :minage,   :puppet_prop => :password_min_age},
  ]
  
  #--------------
  # Command lines
  
  def self.lsgroupscmd(value=@resource[:name])
    [command(:lsgroup),"-R", ia_module, "-a", "id", value]
  end

  def lscmd(value=@resource[:name])
    [self.class.command(:list), "-R", self.class.ia_module , value]
  end

  def addcmd(extra_attrs = [])
    # Here we use the @resource.to_hash to get the list of provided parameters
    # Puppet does not call to self.<parameter>= method if it does not exists.
    #
    # It gets an extra list of arguments to add to the user.
    [self.class.command(:add), "-R", self.class.ia_module  ]+
      self.class.hash2attr(@resource.to_hash) +
      extra_attrs + [@resource[:name]]
  end

  def modifycmd(hash = property_hash)
    [self.class.command(:modify), "-R", self.class.ia_module ]+
      self.class.hash2attr(hash) + [@resource[:name]]
  end

  def deletecmd
    [self.class.command(:delete),"-R", self.class.ia_module, @resource[:name]]
  end

  #--------------
  # We overwrite the create function to change the password after creation.
  def create
    super
    # Reset the password if needed
    self.password = @resource[:password] if @resource[:password]
  end 

  
  # Get the groupname from its id
  def self.groupname_by_id(gid)
    groupname=nil
    execute(lsgroupscmd("ALL")).each { |entry|
      attrs = attr2hash(entry, nil)
      if attrs and attrs.include? :id and gid == attrs[:id].to_i
        groupname = entry.split(" ")[0]
      end
    }
    groupname
  end

  # Get the groupname from its id
  def self.groupid_by_name(groupname)
    attrs = attr2hash(execute(lsgroupscmd(groupname)).split("\n")[0], nil)
    attrs ? attrs[:id].to_i : nil
  end

  # Check that a group exists and is valid
  def self.verify_group(value)
    if value.is_a? Integer or value.is_a? Fixnum  
      groupname = self.groupname_by_id(value)
      raise ArgumentError, "AIX group must be a valid existing group" unless groupname
    else 
      raise ArgumentError, "AIX group must be a valid existing group" unless groupid_by_name(value)
      groupname = value
    end
    groupname
  end
  
  # The user's primary group.  Can be specified numerically or by name.
  def self.gid_to_attr(value)
    verify_group(value)
  end

  def self.gid_from_attr(value)
    groupid_by_name(value)
  end

  # The expiry date for this user. Must be provided in
  # a zero padded YYYY-MM-DD HH:MM format 
  def self.expiry_to_attr(value)
    # For chuser the expires parameter is a 10-character string in the MMDDhhmmyy format
    # that is,"%m%d%H%M%y"
    newdate = '0'
    if value.is_a? String and value!="0000-00-00"
      d = DateTime.parse(value, "%Y-%m-%d %H:%M")
      newdate = d.strftime("%m%d%H%M%y")
    end
    newdate
  end
  
  def self.expiry_from_attr(value)
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
    f = File.open("/etc/security/passwd", 'r')
    # Skip to the user
    f.each { |l| break if l  =~ /^#{user}:\s*$/ }
    if ! f.eof?
      f.each { |l|
        # If there is a new user stanza, stop
        break if l  =~ /^\S*:\s*$/ 
        # If the password= entry is found, return it
        if l  =~ /^\s*password\s*=\s*(.*)$/
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
    # Must receibe "user:enc_password" as input
    # command, arguments = {:failonfail => true, :combine => true}
    cmd = [self.class.command(:chpasswd),"-R", ia_module,
           '-e', '-c', user]
    begin
      execute(cmd, {:failonfail => true, :combine => true, :stdinfile => tmpfile.path })
    rescue Puppet::ExecutionFailure  => detail
      raise Puppet::Error, "Could not set #{param} on #{@resource.class.name}[#{@resource.name}]: #{detail}"
    ensure
      tmpfile.delete()
    end
  end 

  #- **comment**
  #    A description of the user.  Generally is a user's full name.
  #def comment=(value)
  #end
  #
  #def comment
  #end
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
