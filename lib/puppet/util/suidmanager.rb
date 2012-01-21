require 'puppet/util/warnings'
require 'forwardable'

module Puppet::Util::SUIDManager
  include Puppet::Util::Warnings
  extend Forwardable

  # Note groups= is handled specially due to a bug in OS X 10.6, 10.7,
  # and probably upcoming releases...
  to_delegate_to_process = [ :euid=, :euid, :egid=, :egid, :uid=, :uid, :gid=, :gid, :groups ]

  to_delegate_to_process.each do |method|
    def_delegator Process, method
    module_function method
  end

  def osx_maj_ver
    return @osx_maj_ver unless @osx_maj_ver.nil?
    require 'facter'
    # 'kernel' is available without explicitly loading all facts
    if Facter.value('kernel') != 'Darwin'
      @osx_maj_ver = false
      return @osx_maj_ver
    end
    # But 'macosx_productversion_major' requires it.
    Facter.loadfacts
    @osx_maj_ver = Facter.value('macosx_productversion_major')
  end
  module_function :osx_maj_ver

  def groups=(grouplist)
    begin
      return Process.groups = grouplist
    rescue Errno::EINVAL => e
      #We catch Errno::EINVAL as some operating systems (OS X in particular) can
      # cause troubles when using Process#groups= to change *this* user / process
      # list of supplementary groups membership.  This is done via Ruby's function
      # "static VALUE proc_setgroups(VALUE obj, VALUE ary)" which is effectively
      # a wrapper for "int setgroups(size_t size, const gid_t *list)" (part of SVr4
      # and 4.3BSD but not in POSIX.1-2001) that fails and sets errno to EINVAL.
      #
      # This does not appear to be a problem with Ruby but rather an issue on the
      # operating system side.  Therefore we catch the exception and look whether
      # we run under OS X or not -- if so, then we acknowledge the problem and
      # re-throw the exception otherwise.
      if osx_maj_ver and not osx_maj_ver.empty?
        return true
      else
        raise e
      end
    end
  end
  module_function :groups=

  def self.root?
    return Process.uid == 0 unless Puppet.features.microsoft_windows?

    require 'sys/admin'
    require 'win32/security'
    require 'facter'

    majversion = Facter.value(:kernelmajversion)
    return false unless majversion

    # if Vista or later, check for unrestricted process token
    return Win32::Security.elevated_security? unless majversion.to_f < 6.0

    group = Sys::Admin.get_group("Administrators", :sid => Win32::Security::SID::BuiltinAdministrators)
    group and group.members.index(Sys::Admin.get_login) != nil
  end

  # Runs block setting uid and gid if provided then restoring original ids
  def asuser(new_uid=nil, new_gid=nil)
    return yield if Puppet.features.microsoft_windows? or !root?

    old_euid, old_egid = self.euid, self.egid
    begin
      change_group(new_gid) if new_gid
      change_user(new_uid) if new_uid

      yield
    ensure
      change_group(old_egid)
      change_user(old_euid)
    end
  end
  module_function :asuser

  def change_group(group, permanently=false)
    gid = convert_xid(:gid, group)
    raise Puppet::Error, "No such group #{group}" unless gid

    if permanently
      begin
        Process::GID.change_privilege(gid)
      rescue NotImplementedError
        Process.egid = gid
        Process.gid  = gid
      end
    else
      Process.egid = gid
    end
  end
  module_function :change_group

  def change_user(user, permanently=false)
    uid = convert_xid(:uid, user)
    raise Puppet::Error, "No such user #{user}" unless uid

    if permanently
      begin
        Process::UID.change_privilege(uid)
      rescue NotImplementedError
        # If changing uid, we must be root. So initgroups first here.
        initgroups(uid)
        Process.euid = uid
        Process.uid  = uid
      end
    else
      # If we're already root, initgroups before changing euid. If we're not,
      # change euid (to root) first.
      if Process.euid == 0
        initgroups(uid)
        Process.euid = uid
      else
        Process.euid = uid
        initgroups(uid)
      end
    end
  end
  module_function :change_user

  # Make sure the passed argument is a number.
  def convert_xid(type, id)
    map = {:gid => :group, :uid => :user}
    raise ArgumentError, "Invalid id type #{type}" unless map.include?(type)
    ret = Puppet::Util.send(type, id)
    if ret == nil
      raise Puppet::Error, "Invalid #{map[type]}: #{id}"
    end
    ret
  end
  module_function :convert_xid

  # Initialize supplementary groups
  def initgroups(user)
    require 'etc'
    Process.initgroups(Etc.getpwuid(user).name, Process.gid)
  end

  module_function :initgroups

  def run_and_capture(command, new_uid=nil, new_gid=nil)
    output = Puppet::Util.execute(command, :failonfail => false, :combine => true, :uid => new_uid, :gid => new_gid)
    [output, $CHILD_STATUS.dup]
  end
  module_function :run_and_capture

  def system(command, new_uid=nil, new_gid=nil)
    status = nil
    asuser(new_uid, new_gid) do
      Kernel.system(command)
      status = $CHILD_STATUS.dup
    end
    status
  end
  module_function :system
end
