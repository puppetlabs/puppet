# frozen_string_literal: true

# User Puppet provider for AIX. It uses standard commands to manage users:
#  mkuser, rmuser, lsuser, chuser
#
# Notes:
# - AIX users can have expiry date defined with minute granularity,
#   but Puppet does not allow it. There is a ticket open for that (#5431)
#
# - AIX maximum password age is in WEEKs, not days
#
# See https://puppet.com/docs/puppet/latest/provider_development.html
# for more information
require_relative '../../../puppet/provider/aix_object'
require_relative '../../../puppet/util/posix'
require 'tempfile'
require 'date'

Puppet::Type.type(:user).provide :aix, :parent => Puppet::Provider::AixObject do
  desc "User management for AIX."

  defaultfor 'os.name' => :aix
  confine 'os.name' => :aix

  # Commands that manage the element
  commands :list      => "/usr/sbin/lsuser"
  commands :add       => "/usr/bin/mkuser"
  commands :delete    => "/usr/sbin/rmuser"
  commands :modify    => "/usr/bin/chuser"

  commands :chpasswd  => "/bin/chpasswd"

  # Provider features
  has_features :manages_aix_lam
  has_features :manages_homedir, :manages_passwords, :manages_shell
  has_features :manages_expiry,  :manages_password_age
  has_features :manages_local_users_and_groups

  class << self
    def group_provider
      @group_provider ||= Puppet::Type.type(:group).provider(:aix)
    end

    # Define some Puppet Property => AIX Attribute (and vice versa)
    # conversion functions here.

    def gid_to_pgrp(provider, gid)
      group = group_provider.find(gid, provider.ia_module_args)

      group[:name]
    end

    def pgrp_to_gid(provider, pgrp)
      group = group_provider.find(pgrp, provider.ia_module_args)

      group[:gid]
    end

    def expiry_to_expires(expiry)
      return '0' if expiry == "0000-00-00" || expiry.to_sym == :absent

      DateTime.parse(expiry, "%Y-%m-%d %H:%M")
              .strftime("%m%d%H%M%y")
    end

    def expires_to_expiry(provider, expires)
      return :absent if expires == '0'

      unless (match_obj = /\A(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)\z/.match(expires))
        # TRANSLATORS 'AIX' is the name of an operating system and should not be translated
        Puppet.warning(_("Could not convert AIX expires date '%{expires}' on %{class_name}[%{resource_name}]") % { expires: expires, class_name: provider.resource.class.name, resource_name: provider.resource.name })
        return :absent
      end

      month = match_obj[1]
      day = match_obj[2]
      year = match_obj[-1]
      return "20#{year}-#{month}-#{day}"
    end

    # We do some validation before-hand to ensure the value's an Array,
    # a String, etc. in the property. This routine does a final check to
    # ensure our value doesn't have whitespace before we convert it to
    # an attribute.
    def groups_property_to_attribute(groups)
      if groups =~ /\s/
        raise ArgumentError, _("Invalid value %{groups}: Groups must be comma separated!") % { groups: groups }
      end

      groups
    end

    # We do not directly use the groups attribute value because that will
    # always include the primary group, even if our user is not one of its
    # members. Instead, we retrieve our property value by parsing the etc/group file,
    # which matches what we do on our other POSIX platforms like Linux and Solaris.
    #
    # See https://www.ibm.com/support/knowledgecenter/en/ssw_aix_72/com.ibm.aix.files/group_security.htm
    def groups_attribute_to_property(provider, _groups)
      Puppet::Util::POSIX.groups_of(provider.resource[:name]).join(',')
    end
  end

  mapping puppet_property: :comment,
          aix_attribute: :gecos

  mapping puppet_property: :expiry,
          aix_attribute: :expires,
          property_to_attribute: method(:expiry_to_expires),
          attribute_to_property: method(:expires_to_expiry)

  mapping puppet_property: :gid,
          aix_attribute: :pgrp,
          property_to_attribute: method(:gid_to_pgrp),
          attribute_to_property: method(:pgrp_to_gid)

  mapping puppet_property: :groups,
          property_to_attribute: method(:groups_property_to_attribute),
          attribute_to_property: method(:groups_attribute_to_property)

  mapping puppet_property: :home
  mapping puppet_property: :shell

  numeric_mapping puppet_property: :uid,
                  aix_attribute: :id

  numeric_mapping puppet_property: :password_max_age,
                  aix_attribute: :maxage

  numeric_mapping puppet_property: :password_min_age,
                  aix_attribute: :minage

  numeric_mapping puppet_property: :password_warn_days,
                  aix_attribute: :pwdwarntime

  # Now that we have all of our mappings, let's go ahead and make
  # the resource methods (property getters + setters for our mapped
  # properties + a getter for the attributes property).
  mk_resource_methods

  # Setting the primary group (pgrp attribute) on AIX causes both the
  # current and new primary groups to be included in our user's groups,
  # which is undesirable behavior. Thus, this custom setter resets the
  # 'groups' property back to its previous value after setting the primary
  # group.
  def gid=(value)
    old_pgrp = gid
    cur_groups = groups

    set(:gid, value)

    begin
      self.groups = cur_groups
    rescue Puppet::Error => detail
      raise Puppet::Error, _("Could not reset the groups property back to %{cur_groups} after setting the primary group on %{resource}[%{name}]. This means that the previous primary group of %{old_pgrp} and the new primary group of %{new_pgrp} have been added to %{cur_groups}. You will need to manually reset the groups property if this is undesirable behavior. Detail: %{detail}") % { cur_groups: cur_groups, resource: @resource.class.name, name: @resource.name, old_pgrp: old_pgrp, new_pgrp: value, detail: detail }, detail.backtrace
    end
  end

  # Helper function that parses the password from the given
  # password filehandle. This is here to make testing easier
  # for #password since we cannot configure Mocha to mock out
  # a method and have it return a block's value, meaning we
  # cannot test #password directly (not in a simple and obvious
  # way, at least).
  # @api private
  def parse_password(f)
    # From the docs, a user stanza is formatted as (newlines are explicitly
    # stated here for clarity):
    #   <user>:\n
    #     <attribute1>=<value1>\n
    #     <attribute2>=<value2>\n
    #
    # First, find our user stanza
    stanza = f.each_line.find { |line| line =~ /\A#{@resource[:name]}:/ }
    return :absent unless stanza

    # Now find the password line, if it exists. Note our call to each_line here
    # will pick up right where we left off.
    match_obj = nil
    f.each_line.find do |line|
      # Break if we find another user stanza. This means our user
      # does not have a password.
      break if line =~ /^\S+:$/

      match_obj = /password\s+=\s+(\S+)/.match(line)
    end
    return :absent unless match_obj

    match_obj[1]
  end

  # - **password**
  #    The user's password, in whatever encrypted format the local machine
  #    requires. Be sure to enclose any value that includes a dollar sign ($)
  #    in single quotes (').  Requires features manages_passwords.
  #
  # Retrieve the password parsing the /etc/security/passwd file.
  def password
    # AIX reference indicates this file is ASCII
    # https://www.ibm.com/support/knowledgecenter/en/ssw_aix_72/com.ibm.aix.files/passwd_security.htm
    Puppet::FileSystem.open("/etc/security/passwd", nil, "r:ASCII") do |f|
      parse_password(f)
    end
  end

  def password=(value)
    user = @resource[:name]

    begin
      # Puppet execute does not support strings as input, only files.
      # The password is expected to be in an encrypted format given -e is specified:
      # https://www.ibm.com/support/knowledgecenter/ssw_aix_71/com.ibm.aix.cmds1/chpasswd.htm
      # /etc/security/passwd is specified as an ASCII file per the AIX documentation
      tempfile = nil
      tempfile = Tempfile.new("puppet_#{user}_pw", :encoding => Encoding::ASCII)
      tempfile << "#{user}:#{value}\n"
      tempfile.close()

      # Options '-e', '-c', use encrypted password and clear flags
      # Must receive "user:enc_password" as input
      # command, arguments = {:failonfail => true, :combine => true}
      # Fix for bugs #11200 and #10915
      cmd = [self.class.command(:chpasswd), *ia_module_args, '-e', '-c']
      execute_options = {
        :failonfail => false,
        :combine => true,
        :stdinfile => tempfile.path
      }
      output = execute(cmd, execute_options)

      # chpasswd can return 1, even on success (at least on AIX 6.1); empty output
      # indicates success
      if output != ""
        raise Puppet::ExecutionFailure, "chpasswd said #{output}"
      end
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not set password on #{@resource.class.name}[#{@resource.name}]: #{detail}", detail.backtrace
    ensure
      if tempfile
        # Extra close will noop. This is in case the write to our tempfile
        # fails.
        tempfile.close()
        tempfile.delete()
      end
    end
  end

  def create
    super

    # We specify the 'groups' AIX attribute in AixObject's create method
    # when creating our user. However, this does not always guarantee that
    # our 'groups' property is set to the right value. For example, the
    # primary group will always be included in the 'groups' property. This is
    # bad if we're explicitly managing the 'groups' property under inclusive
    # membership, and we are not specifying the primary group in the 'groups'
    # property value.
    #
    # Setting the groups property here a second time will ensure that our user is
    # created and in the right state. Note that this is an idempotent operation,
    # so if AixObject's create method already set it to the right value, then this
    # will noop.
    if (groups = @resource.should(:groups))
      self.groups = groups
    end

    if (password = @resource.should(:password))
      self.password = password
    end
  end

  # Lists all instances of the given object, taking in an optional set
  # of ia_module arguments. Returns an array of hashes, each hash
  # having the schema
  #   {
  #     :name => <object_name>
  #     :home => <object_home>
  #   }
  def list_all_homes(ia_module_args = [])
    cmd = [command(:list), '-c', *ia_module_args, '-a', 'home', 'ALL']
    parse_aix_objects(execute(cmd)).to_a.map do |object|
      name = object[:name]
      home = object[:attributes].delete(:home)

      { name: name, home: home }
    end
  rescue => e
    Puppet.debug("Could not list home of all users: #{e.message}")
    {}
  end

  # Deletes this instance resource
  def delete
    homedir = home
    super
    return unless @resource.managehome?

    if !Puppet::Util.absolute_path?(homedir) || File.realpath(homedir) == '/' || Puppet::FileSystem.symlink?(homedir)
      Puppet.debug("Can not remove home directory '#{homedir}' of user '#{@resource[:name]}'. Please make sure the path is not relative, symlink or '/'.")
      return
    end

    affected_home = list_all_homes.find { |info| info[:home].start_with?(File.realpath(homedir)) }
    if affected_home
      Puppet.debug("Can not remove home directory '#{homedir}' of user '#{@resource[:name]}' as it would remove the home directory '#{affected_home[:home]}' of user '#{affected_home[:name]}' also.")
      return
    end

    FileUtils.remove_entry_secure(homedir, true)
  end

  def deletecmd
    [self.class.command(:delete), '-p'] + ia_module_args + [@resource[:name]]
  end

  # UNSUPPORTED
  # - **profile_membership**
  #    Whether specified roles should be treated as the only roles
  #    of which the user is a member or whether they should merely
  #    be treated as the minimum membership list.  Valid values are
  #    `inclusive`, `minimum`.
  # UNSUPPORTED
  # - **profiles**
  #    The profiles the user has.  Multiple profiles should be
  #    specified as an array.  Requires features manages_solaris_rbac.
  # UNSUPPORTED
  # - **project**
  #    The name of the project associated with a user  Requires features
  #    manages_solaris_rbac.
  # UNSUPPORTED
  # - **role_membership**
  #    Whether specified roles should be treated as the only roles
  #    of which the user is a member or whether they should merely
  #    be treated as the minimum membership list.  Valid values are
  #    `inclusive`, `minimum`.
  # UNSUPPORTED
  # - **roles**
  #    The roles the user has.  Multiple roles should be
  #    specified as an array.  Requires features manages_roles.
  # UNSUPPORTED
  # - **key_membership**
  #    Whether specified key value pairs should be treated as the only
  #    attributes
  #    of the user or whether they should merely
  #    be treated as the minimum list.  Valid values are `inclusive`,
  #    `minimum`.
  # UNSUPPORTED
  # - **keys**
  #    Specify user attributes in an array of keyvalue pairs  Requires features
  #    manages_solaris_rbac.
  # UNSUPPORTED
  # - **allowdupe**
  #  Whether to allow duplicate UIDs.  Valid values are `true`, `false`.
  # UNSUPPORTED
  # - **auths**
  #    The auths the user has.  Multiple auths should be
  #    specified as an array.  Requires features manages_solaris_rbac.
  # UNSUPPORTED
  # - **auth_membership**
  #    Whether specified auths should be treated as the only auths
  #    of which the user is a member or whether they should merely
  #    be treated as the minimum membership list.  Valid values are
  #    `inclusive`, `minimum`.
  # UNSUPPORTED
end
