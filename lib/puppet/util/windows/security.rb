# This class maps POSIX owner, group, and modes to the Windows
# security model, and back.
#
# The primary goal of this mapping is to ensure that owner, group, and
# modes can be round-tripped in a consistent and deterministic
# way. Otherwise, Puppet might think file resources are out-of-sync
# every time it runs. A secondary goal is to provide equivalent
# permissions for common use-cases. For example, setting the owner to
# "Administrators", group to "Users", and mode to 750 (which also
# denies access to everyone else.
#
# There are some well-known problems mapping windows and POSIX
# permissions due to differences between the two security
# models. Search for "POSIX permission mapping leak". In POSIX, access
# to a file is determined solely based on the most specific class
# (user, group, other). So a mode of 460 would deny write access to
# the owner even if they are a member of the group. But in Windows,
# the entire access control list is walked until the user is
# explicitly denied or allowed (denied take precedence, and if neither
# occurs they are denied). As a result, a user could be allowed access
# based on their group membership. To solve this problem, other people
# have used deny access control entries to more closely model POSIX,
# but this introduces a lot of complexity.
#
# In general, this implementation only supports "typical" permissions,
# where group permissions are a subset of user, and other permissions
# are a subset of group, e.g. 754, but not 467.  However, there are
# some Windows quirks to be aware of.
#
# * The owner can be either a user or group SID, and most system files
#   are owned by the Administrators group.
# * The group can be either a user or group SID.
# * Unexpected results can occur if the owner and group are the
#   same, but the user and group classes are different, e.g. 750. In
#   this case, it is not possible to allow write access to the owner,
#   but not the group. As a result, the actual permissions set on the
#   file would be 770.
# * In general, only privileged users can set the owner, group, or
#   change the mode for files they do not own. In 2003, the user must
#   be a member of the Administrators group. In Vista/2008, the user
#   must be running with elevated privileges.
# * A file/dir can be deleted by anyone with the DELETE access right
#   OR by anyone that has the FILE_DELETE_CHILD access right for the
#   parent. See https://support.microsoft.com/kb/238018. But on Unix,
#   the user must have write access to the file/dir AND execute access
#   to all of the parent path components.
# * Many access control entries are inherited from parent directories,
#   and it is common for file/dirs to have more than 3 entries,
#   e.g. Users, Power Users, Administrators, SYSTEM, etc, which cannot
#   be mapped into the 3 class POSIX model. The get_mode method will
#   set the S_IEXTRA bit flag indicating that an access control entry
#   was found whose SID is neither the owner, group, or other. This
#   enables Puppet to detect when file/dirs are out-of-sync,
#   especially those that Puppet did not create, but is attempting
#   to manage.
# * A special case of this is S_ISYSTEM_MISSING, which is set when the
#   SYSTEM permissions are *not* present on the DACL.
# * On Unix, the owner and group can be modified without changing the
#   mode. But on Windows, an access control entry specifies which SID
#   it applies to. As a result, the set_owner and set_group methods
#   automatically rebuild the access control list based on the new
#   (and different) owner or group.

require 'puppet/util/windows'
require 'pathname'
require 'ffi'

module Puppet::Util::Windows::Security
  include Puppet::Util::Windows::String

  extend Puppet::Util::Windows::Security
  extend FFI::Library

  # file modes
  S_IRUSR = 0000400
  S_IRGRP = 0000040
  S_IROTH = 0000004
  S_IWUSR = 0000200
  S_IWGRP = 0000020
  S_IWOTH = 0000002
  S_IXUSR = 0000100
  S_IXGRP = 0000010
  S_IXOTH = 0000001
  S_IRWXU = 0000700
  S_IRWXG = 0000070
  S_IRWXO = 0000007
  S_ISVTX = 0001000
  S_IEXTRA = 02000000  # represents an extra ace
  S_ISYSTEM_MISSING = 04000000

  # constants that are missing from Windows::Security
  PROTECTED_DACL_SECURITY_INFORMATION   = 0x80000000
  UNPROTECTED_DACL_SECURITY_INFORMATION = 0x20000000
  NO_INHERITANCE = 0x0
  SE_DACL_PROTECTED = 0x1000

  FILE = Puppet::Util::Windows::File

  SE_BACKUP_NAME              = 'SeBackupPrivilege'
  SE_RESTORE_NAME             = 'SeRestorePrivilege'

  DELETE                      = 0x00010000
  READ_CONTROL                = 0x20000
  WRITE_DAC                   = 0x40000
  WRITE_OWNER                 = 0x80000

  OWNER_SECURITY_INFORMATION  = 1
  GROUP_SECURITY_INFORMATION  = 2
  DACL_SECURITY_INFORMATION   = 4

  # Set the owner of the object referenced by +path+ to the specified
  # +owner_sid+.  The owner sid should be of the form "S-1-5-32-544"
  # and can either be a user or group.  Only a user with the
  # SE_RESTORE_NAME privilege in their process token can overwrite the
  # object's owner to something other than the current user.
  def set_owner(owner_sid, path)
    sd = get_security_descriptor(path)

    if owner_sid != sd.owner
      sd.owner = owner_sid
      set_security_descriptor(path, sd)
    end
  end

  # Get the owner of the object referenced by +path+.  The returned
  # value is a SID string, e.g. "S-1-5-32-544".  Any user with read
  # access to an object can get the owner. Only a user with the
  # SE_BACKUP_NAME privilege in their process token can get the owner
  # for objects they do not have read access to.
  def get_owner(path)
    return unless supports_acl?(path)

    get_security_descriptor(path).owner
  end

  # Set the owner of the object referenced by +path+ to the specified
  # +group_sid+.  The group sid should be of the form "S-1-5-32-544"
  # and can either be a user or group.  Any user with WRITE_OWNER
  # access to the object can change the group (regardless of whether
  # the current user belongs to that group or not).
  def set_group(group_sid, path)
    sd = get_security_descriptor(path)

    if group_sid != sd.group
      sd.group = group_sid
      set_security_descriptor(path, sd)
    end
  end

  # Get the group of the object referenced by +path+.  The returned
  # value is a SID string, e.g. "S-1-5-32-544".  Any user with read
  # access to an object can get the group. Only a user with the
  # SE_BACKUP_NAME privilege in their process token can get the group
  # for objects they do not have read access to.
  def get_group(path)
    return unless supports_acl?(path)

    get_security_descriptor(path).group
  end

  FILE_PERSISTENT_ACLS           = 0x00000008

  def supports_acl?(path)
    supported = false
    root = Pathname.new(path).enum_for(:ascend).to_a.last.to_s
    # 'A trailing backslash is required'
    root = "#{root}\\" unless root =~ /[\/\\]$/

    FFI::MemoryPointer.new(:pointer, 1) do |flags_ptr|
      if GetVolumeInformationW(wide_string(root), FFI::Pointer::NULL, 0,
          FFI::Pointer::NULL, FFI::Pointer::NULL,
          flags_ptr, FFI::Pointer::NULL, 0) == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new("Failed to get volume information")
      end
      supported = flags_ptr.read_dword & FILE_PERSISTENT_ACLS == FILE_PERSISTENT_ACLS
    end

    supported
  end

  MASK_TO_MODE = {
    FILE::FILE_GENERIC_READ => S_IROTH,
    FILE::FILE_GENERIC_WRITE => S_IWOTH,
    (FILE::FILE_GENERIC_EXECUTE & ~FILE::FILE_READ_ATTRIBUTES) => S_IXOTH
  }

  def get_aces_for_path_by_sid(path, sid)
    get_security_descriptor(path).dacl.select { |ace| ace.sid == sid }
  end

  # Get the mode of the object referenced by +path+.  The returned
  # integer value represents the POSIX-style read, write, and execute
  # modes for the user, group, and other classes, e.g. 0640.  Any user
  # with read access to an object can get the mode. Only a user with
  # the SE_BACKUP_NAME privilege in their process token can get the
  # mode for objects they do not have read access to.
  def get_mode(path)
    return unless supports_acl?(path)

    well_known_world_sid = Puppet::Util::Windows::SID::Everyone
    well_known_nobody_sid = Puppet::Util::Windows::SID::Nobody
    well_known_system_sid = Puppet::Util::Windows::SID::LocalSystem

    mode = S_ISYSTEM_MISSING

    sd = get_security_descriptor(path)
    sd.dacl.each do |ace|
      next if ace.inherit_only?

      case ace.sid
      when sd.owner
        MASK_TO_MODE.each_pair do |k,v|
          if (ace.mask & k) == k
            mode |= (v << 6)
          end
        end
      when sd.group
        MASK_TO_MODE.each_pair do |k,v|
          if (ace.mask & k) == k
            mode |= (v << 3)
          end
        end
      when well_known_world_sid
        MASK_TO_MODE.each_pair do |k,v|
          if (ace.mask & k) == k
            mode |= (v << 6) | (v << 3) | v
          end
        end
        if File.directory?(path) &&
          (ace.mask & (FILE::FILE_WRITE_DATA | FILE::FILE_EXECUTE | FILE::FILE_DELETE_CHILD)) == (FILE::FILE_WRITE_DATA | FILE::FILE_EXECUTE)
          mode |= S_ISVTX;
        end
      when well_known_nobody_sid
        if (ace.mask & FILE::FILE_APPEND_DATA).nonzero?
          mode |= S_ISVTX
        end
      when well_known_system_sid
      else
        #puts "Warning, unable to map SID into POSIX mode: #{ace.sid}"
        mode |= S_IEXTRA
      end

      if ace.sid == well_known_system_sid
        mode &= ~S_ISYSTEM_MISSING
      end

      # if owner and group the same, then user and group modes are the OR of both
      if sd.owner == sd.group
        mode |= ((mode & S_IRWXG) << 3) | ((mode & S_IRWXU) >> 3)
        #puts "owner: #{sd.group}, 0x#{ace.mask.to_s(16)}, #{mode.to_s(8)}"
      end
    end

    #puts "get_mode: #{mode.to_s(8)}"
    mode
  end

  MODE_TO_MASK = {
    S_IROTH => FILE::FILE_GENERIC_READ,
    S_IWOTH => FILE::FILE_GENERIC_WRITE,
    S_IXOTH => (FILE::FILE_GENERIC_EXECUTE & ~FILE::FILE_READ_ATTRIBUTES),
  }

  # Set the mode of the object referenced by +path+ to the specified
  # +mode+.  The mode should be specified as POSIX-stye read, write,
  # and execute modes for the user, group, and other classes,
  # e.g. 0640. The sticky bit, S_ISVTX, is supported, but is only
  # meaningful for directories. If set, group and others are not
  # allowed to delete child objects for which they are not the owner.
  # By default, the DACL is set to protected, meaning it does not
  # inherit access control entries from parent objects. This can be
  # changed by setting +protected+ to false. The owner of the object
  # (with READ_CONTROL and WRITE_DACL access) can always change the
  # mode. Only a user with the SE_BACKUP_NAME and SE_RESTORE_NAME
  # privileges in their process token can change the mode for objects
  # that they do not have read and write access to.
  def set_mode(mode, path, protected = true)
    sd = get_security_descriptor(path)
    well_known_world_sid = Puppet::Util::Windows::SID::Everyone
    well_known_nobody_sid = Puppet::Util::Windows::SID::Nobody
    well_known_system_sid = Puppet::Util::Windows::SID::LocalSystem

    owner_allow = FILE::STANDARD_RIGHTS_ALL  |
      FILE::FILE_READ_ATTRIBUTES |
      FILE::FILE_WRITE_ATTRIBUTES
    group_allow = FILE::STANDARD_RIGHTS_READ |
      FILE::FILE_READ_ATTRIBUTES |
      FILE::SYNCHRONIZE
    other_allow = FILE::STANDARD_RIGHTS_READ |
      FILE::FILE_READ_ATTRIBUTES |
      FILE::SYNCHRONIZE
    nobody_allow = 0
    system_allow = 0

    MODE_TO_MASK.each do |k,v|
      if ((mode >> 6) & k) == k
        owner_allow |= v
      end
      if ((mode >> 3) & k) == k
        group_allow |= v
      end
      if (mode & k) == k
        other_allow |= v
      end
    end

    if (mode & S_ISVTX).nonzero?
      nobody_allow |= FILE::FILE_APPEND_DATA;
    end

    # caller is NOT managing SYSTEM by using group or owner, so set to FULL
    if ! [sd.owner, sd.group].include? well_known_system_sid
      # we don't check S_ISYSTEM_MISSING bit, but automatically carry over existing SYSTEM perms
      # by default set SYSTEM perms to full
      system_allow = FILE::FILE_ALL_ACCESS
    end

    isdir = File.directory?(path)

    if isdir
      if (mode & (S_IWUSR | S_IXUSR)) == (S_IWUSR | S_IXUSR)
        owner_allow |= FILE::FILE_DELETE_CHILD
      end
      if (mode & (S_IWGRP | S_IXGRP)) == (S_IWGRP | S_IXGRP) && (mode & S_ISVTX) == 0
        group_allow |= FILE::FILE_DELETE_CHILD
      end
      if (mode & (S_IWOTH | S_IXOTH)) == (S_IWOTH | S_IXOTH) && (mode & S_ISVTX) == 0
        other_allow |= FILE::FILE_DELETE_CHILD
      end
    end

    # if owner and group the same, then map group permissions to the one owner ACE
    isownergroup = sd.owner == sd.group
    if isownergroup
      owner_allow |= group_allow
    end

    # if any ACE allows write, then clear readonly bit, but do this before we overwrite
    # the DACl and lose our ability to set the attribute
    if ((owner_allow | group_allow | other_allow ) & FILE::FILE_WRITE_DATA) == FILE::FILE_WRITE_DATA
      FILE.remove_attributes(path, FILE::FILE_ATTRIBUTE_READONLY)
    end

    dacl = Puppet::Util::Windows::AccessControlList.new
    dacl.allow(sd.owner, owner_allow)
    unless isownergroup
      dacl.allow(sd.group, group_allow)
    end
    dacl.allow(well_known_world_sid, other_allow)
    dacl.allow(well_known_nobody_sid, nobody_allow)

    # TODO: system should be first?
    flags = !isdir ? 0 :
      Puppet::Util::Windows::AccessControlEntry::CONTAINER_INHERIT_ACE |
      Puppet::Util::Windows::AccessControlEntry::OBJECT_INHERIT_ACE
    dacl.allow(well_known_system_sid, system_allow, flags)

    # add inherit-only aces for child dirs and files that are created within the dir
    inherit_only = Puppet::Util::Windows::AccessControlEntry::INHERIT_ONLY_ACE
    if isdir
      inherit = inherit_only | Puppet::Util::Windows::AccessControlEntry::CONTAINER_INHERIT_ACE
      dacl.allow(Puppet::Util::Windows::SID::CreatorOwner, owner_allow, inherit)
      dacl.allow(Puppet::Util::Windows::SID::CreatorGroup, group_allow, inherit)

      inherit = inherit_only | Puppet::Util::Windows::AccessControlEntry::OBJECT_INHERIT_ACE
      dacl.allow(Puppet::Util::Windows::SID::CreatorOwner, owner_allow & ~FILE::FILE_EXECUTE, inherit)
      dacl.allow(Puppet::Util::Windows::SID::CreatorGroup, group_allow & ~FILE::FILE_EXECUTE, inherit)
    end

    new_sd = Puppet::Util::Windows::SecurityDescriptor.new(sd.owner, sd.group, dacl, protected)
    set_security_descriptor(path, new_sd)

    nil
  end

  ACL_REVISION                   = 2

  def add_access_allowed_ace(acl, mask, sid, inherit = nil)
    inherit ||= NO_INHERITANCE

    Puppet::Util::Windows::SID.string_to_sid_ptr(sid) do |sid_ptr|
      if Puppet::Util::Windows::SID.IsValidSid(sid_ptr) == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new("Invalid SID")
      end

      if AddAccessAllowedAceEx(acl, ACL_REVISION, inherit, mask, sid_ptr) == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new("Failed to add access control entry")
      end
    end

    # ensure this method is void if it doesn't raise
    nil
  end

  def add_access_denied_ace(acl, mask, sid, inherit = nil)
    inherit ||= NO_INHERITANCE

    Puppet::Util::Windows::SID.string_to_sid_ptr(sid) do |sid_ptr|
      if Puppet::Util::Windows::SID.IsValidSid(sid_ptr) == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new("Invalid SID")
      end

      if AddAccessDeniedAceEx(acl, ACL_REVISION, inherit, mask, sid_ptr) == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new("Failed to add access control entry")
      end
    end

    # ensure this method is void if it doesn't raise
    nil
  end

  def parse_dacl(dacl_ptr)
    # REMIND: need to handle NULL DACL
    if IsValidAcl(dacl_ptr) == FFI::WIN32_FALSE
      raise Puppet::Util::Windows::Error.new("Invalid DACL")
    end

    dacl_struct = ACL.new(dacl_ptr)
    ace_count = dacl_struct[:AceCount]

    dacl = Puppet::Util::Windows::AccessControlList.new

    # deny all
    return dacl if ace_count == 0

    0.upto(ace_count - 1) do |i|
      FFI::MemoryPointer.new(:pointer, 1) do |ace_ptr|

        next if GetAce(dacl_ptr, i, ace_ptr) == FFI::WIN32_FALSE

        # ACE structures vary depending on the type. We are only concerned with
        # ACCESS_ALLOWED_ACE and ACCESS_DENIED_ACEs, which have the same layout
        ace = GENERIC_ACCESS_ACE.new(ace_ptr.get_pointer(0)) #deref LPVOID *

        ace_type = ace[:Header][:AceType]
        if ace_type != Puppet::Util::Windows::AccessControlEntry::ACCESS_ALLOWED_ACE_TYPE &&
          ace_type != Puppet::Util::Windows::AccessControlEntry::ACCESS_DENIED_ACE_TYPE
          Puppet.warning "Unsupported access control entry type: 0x#{ace_type.to_s(16)}"
          next
        end

        # using pointer addition gives the FFI::Pointer a size, but that's OK here
        sid = Puppet::Util::Windows::SID.sid_ptr_to_string(ace.pointer + GENERIC_ACCESS_ACE.offset_of(:SidStart))
        mask = ace[:Mask]
        ace_flags = ace[:Header][:AceFlags]

        case ace_type
        when Puppet::Util::Windows::AccessControlEntry::ACCESS_ALLOWED_ACE_TYPE
          dacl.allow(sid, mask, ace_flags)
        when Puppet::Util::Windows::AccessControlEntry::ACCESS_DENIED_ACE_TYPE
          dacl.deny(sid, mask, ace_flags)
        end
      end
    end

    dacl
  end

  # Open an existing file with the specified access mode, and execute a
  # block with the opened file HANDLE.
  def open_file(path, access, &block)
    handle = CreateFileW(
             wide_string(path),
             access,
             FILE::FILE_SHARE_READ | FILE::FILE_SHARE_WRITE,
             FFI::Pointer::NULL, # security_attributes
             FILE::OPEN_EXISTING,
             FILE::FILE_FLAG_OPEN_REPARSE_POINT | FILE::FILE_FLAG_BACKUP_SEMANTICS,
             FFI::Pointer::NULL_HANDLE) # template

    if handle == Puppet::Util::Windows::File::INVALID_HANDLE_VALUE
      raise Puppet::Util::Windows::Error.new("Failed to open '#{path}'")
    end

    begin
      yield handle
    ensure
      FFI::WIN32.CloseHandle(handle) if handle
    end

    # handle has already had CloseHandle called against it, nothing to return
    nil
  end

  # Execute a block with the specified privilege enabled
  def with_privilege(privilege, &block)
    set_privilege(privilege, true)
    yield
  ensure
    set_privilege(privilege, false)
  end

  SE_PRIVILEGE_ENABLED    = 0x00000002
  TOKEN_ADJUST_PRIVILEGES = 0x0020

  # Enable or disable a privilege. Note this doesn't add any privileges the
  # user doesn't already has, it just enables privileges that are disabled.
  def set_privilege(privilege, enable)
    return unless Puppet.features.root?

    Puppet::Util::Windows::Process.with_process_token(TOKEN_ADJUST_PRIVILEGES) do |token|
      Puppet::Util::Windows::Process.lookup_privilege_value(privilege) do |luid|
        FFI::MemoryPointer.new(Puppet::Util::Windows::Process::LUID_AND_ATTRIBUTES.size) do |luid_and_attributes_ptr|
          # allocate unmanaged memory for structs that we clean up afterwards
          luid_and_attributes = Puppet::Util::Windows::Process::LUID_AND_ATTRIBUTES.new(luid_and_attributes_ptr)
          luid_and_attributes[:Luid] = luid
          luid_and_attributes[:Attributes] = enable ? SE_PRIVILEGE_ENABLED : 0

          FFI::MemoryPointer.new(Puppet::Util::Windows::Process::TOKEN_PRIVILEGES.size) do |token_privileges_ptr|
            token_privileges = Puppet::Util::Windows::Process::TOKEN_PRIVILEGES.new(token_privileges_ptr)
            token_privileges[:PrivilegeCount] = 1
            token_privileges[:Privileges][0] = luid_and_attributes

            # size is correct given we only have 1 LUID, otherwise would be:
            # [:PrivilegeCount].size + [:PrivilegeCount] * LUID_AND_ATTRIBUTES.size
            if AdjustTokenPrivileges(token, FFI::WIN32_FALSE,
                token_privileges, token_privileges.size,
                FFI::MemoryPointer::NULL, FFI::MemoryPointer::NULL) == FFI::WIN32_FALSE
              raise Puppet::Util::Windows::Error.new("Failed to adjust process privileges")
            end
          end
        end
      end
    end

    # token / luid structs freed by this point, so return true as nothing raised
    true
  end

  def get_security_descriptor(path)
    sd = nil

    with_privilege(SE_BACKUP_NAME) do
      open_file(path, READ_CONTROL) do |handle|
        FFI::MemoryPointer.new(:pointer, 1) do |owner_sid_ptr_ptr|
          FFI::MemoryPointer.new(:pointer, 1) do |group_sid_ptr_ptr|
            FFI::MemoryPointer.new(:pointer, 1) do |dacl_ptr_ptr|
              FFI::MemoryPointer.new(:pointer, 1) do |sd_ptr_ptr|

                rv = GetSecurityInfo(
                  handle,
                  :SE_FILE_OBJECT,
                  OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION,
                  owner_sid_ptr_ptr,
                  group_sid_ptr_ptr,
                  dacl_ptr_ptr,
                  FFI::Pointer::NULL, #sacl
                  sd_ptr_ptr) #sec desc
                raise Puppet::Util::Windows::Error.new("Failed to get security information") if rv != FFI::ERROR_SUCCESS

                # these 2 convenience params are not freed since they point inside sd_ptr
                owner = Puppet::Util::Windows::SID.sid_ptr_to_string(owner_sid_ptr_ptr.get_pointer(0))
                group = Puppet::Util::Windows::SID.sid_ptr_to_string(group_sid_ptr_ptr.get_pointer(0))

                FFI::MemoryPointer.new(:word, 1) do |control|
                  FFI::MemoryPointer.new(:dword, 1) do |revision|
                    sd_ptr_ptr.read_win32_local_pointer do |sd_ptr|

                      if GetSecurityDescriptorControl(sd_ptr, control, revision) == FFI::WIN32_FALSE
                        raise Puppet::Util::Windows::Error.new("Failed to get security descriptor control")
                      end

                      protect = (control.read_word & SE_DACL_PROTECTED) == SE_DACL_PROTECTED
                      dacl = parse_dacl(dacl_ptr_ptr.get_pointer(0))
                      sd = Puppet::Util::Windows::SecurityDescriptor.new(owner, group, dacl, protect)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    sd
  end

  def get_max_generic_acl_size(ace_count)
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa378853(v=vs.85).aspx
    # To calculate the initial size of an ACL, add the following together, and then align the result to the nearest DWORD:
    # * Size of the ACL structure.
    # * Size of each ACE structure that the ACL is to contain minus the SidStart member (DWORD) of the ACE.
    # * Length of the SID that each ACE is to contain.
    ACL.size + ace_count * MAXIMUM_GENERIC_ACE_SIZE
  end

  # setting DACL requires both READ_CONTROL and WRITE_DACL access rights,
  # and their respective privileges, SE_BACKUP_NAME and SE_RESTORE_NAME.
  def set_security_descriptor(path, sd)
    FFI::MemoryPointer.new(:byte, get_max_generic_acl_size(sd.dacl.count)) do |acl_ptr|
      if InitializeAcl(acl_ptr, acl_ptr.size, ACL_REVISION) == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new("Failed to initialize ACL")
      end

      if IsValidAcl(acl_ptr) == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new("Invalid DACL")
      end

      with_privilege(SE_BACKUP_NAME) do
        with_privilege(SE_RESTORE_NAME) do
          open_file(path, READ_CONTROL | WRITE_DAC | WRITE_OWNER) do |handle|
            Puppet::Util::Windows::SID.string_to_sid_ptr(sd.owner) do |owner_sid_ptr|
              Puppet::Util::Windows::SID.string_to_sid_ptr(sd.group) do |group_sid_ptr|
                sd.dacl.each do |ace|
                  case ace.type
                  when Puppet::Util::Windows::AccessControlEntry::ACCESS_ALLOWED_ACE_TYPE
                    #puts "ace: allow, sid #{Puppet::Util::Windows::SID.sid_to_name(ace.sid)}, mask 0x#{ace.mask.to_s(16)}"
                    add_access_allowed_ace(acl_ptr, ace.mask, ace.sid, ace.flags)
                  when Puppet::Util::Windows::AccessControlEntry::ACCESS_DENIED_ACE_TYPE
                    #puts "ace: deny, sid #{Puppet::Util::Windows::SID.sid_to_name(ace.sid)}, mask 0x#{ace.mask.to_s(16)}"
                    add_access_denied_ace(acl_ptr, ace.mask, ace.sid, ace.flags)
                  else
                    raise "We should never get here"
                    # TODO: this should have been a warning in an earlier commit
                  end
                end

                # protected means the object does not inherit aces from its parent
                flags = OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION
                flags |= sd.protect ? PROTECTED_DACL_SECURITY_INFORMATION : UNPROTECTED_DACL_SECURITY_INFORMATION

                rv = SetSecurityInfo(handle,
                                     :SE_FILE_OBJECT,
                                     flags,
                                     owner_sid_ptr,
                                     group_sid_ptr,
                                     acl_ptr,
                                     FFI::MemoryPointer::NULL)

                if rv != FFI::ERROR_SUCCESS
                  raise Puppet::Util::Windows::Error.new("Failed to set security information")
                end
              end
            end
          end
        end
      end
    end
  end

  ffi_convention :stdcall

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa363858(v=vs.85).aspx
  # HANDLE WINAPI CreateFile(
  #   _In_      LPCTSTR lpFileName,
  #   _In_      DWORD dwDesiredAccess,
  #   _In_      DWORD dwShareMode,
  #   _In_opt_  LPSECURITY_ATTRIBUTES lpSecurityAttributes,
  #   _In_      DWORD dwCreationDisposition,
  #   _In_      DWORD dwFlagsAndAttributes,
  #   _In_opt_  HANDLE hTemplateFile
  # );
  ffi_lib :kernel32
  attach_function_private :CreateFileW,
    [:lpcwstr, :dword, :dword, :pointer, :dword, :dword, :handle], :handle

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa364993(v=vs.85).aspx
  # BOOL WINAPI GetVolumeInformation(
  #   _In_opt_   LPCTSTR lpRootPathName,
  #   _Out_opt_  LPTSTR lpVolumeNameBuffer,
  #   _In_       DWORD nVolumeNameSize,
  #   _Out_opt_  LPDWORD lpVolumeSerialNumber,
  #   _Out_opt_  LPDWORD lpMaximumComponentLength,
  #   _Out_opt_  LPDWORD lpFileSystemFlags,
  #   _Out_opt_  LPTSTR lpFileSystemNameBuffer,
  #   _In_       DWORD nFileSystemNameSize
  # );
  ffi_lib :kernel32
  attach_function_private :GetVolumeInformationW,
    [:lpcwstr, :lpwstr, :dword, :lpdword, :lpdword, :lpdword, :lpwstr, :dword], :win32_bool

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa374951(v=vs.85).aspx
  # BOOL WINAPI AddAccessAllowedAceEx(
  #   _Inout_  PACL pAcl,
  #   _In_     DWORD dwAceRevision,
  #   _In_     DWORD AceFlags,
  #   _In_     DWORD AccessMask,
  #   _In_     PSID pSid
  # );
  ffi_lib :advapi32
  attach_function_private :AddAccessAllowedAceEx,
    [:pointer, :dword, :dword, :dword, :pointer], :win32_bool

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa374964(v=vs.85).aspx
  # BOOL WINAPI AddAccessDeniedAceEx(
  #   _Inout_  PACL pAcl,
  #   _In_     DWORD dwAceRevision,
  #   _In_     DWORD AceFlags,
  #   _In_     DWORD AccessMask,
  #   _In_     PSID pSid
  # );
  ffi_lib :advapi32
  attach_function_private :AddAccessDeniedAceEx,
    [:pointer, :dword, :dword, :dword, :pointer], :win32_bool

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa374931(v=vs.85).aspx
  # typedef struct _ACL {
  #   BYTE AclRevision;
  #   BYTE Sbz1;
  #   WORD AclSize;
  #   WORD AceCount;
  #   WORD Sbz2;
  # } ACL, *PACL;
  class ACL < FFI::Struct
    layout :AclRevision, :byte,
           :Sbz1, :byte,
           :AclSize, :word,
           :AceCount, :word,
           :Sbz2, :word
  end

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa374912(v=vs.85).aspx
  # ACE types
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa374919(v=vs.85).aspx
  # typedef struct _ACE_HEADER {
  #   BYTE AceType;
  #   BYTE AceFlags;
  #   WORD AceSize;
  # } ACE_HEADER, *PACE_HEADER;
  class ACE_HEADER < FFI::Struct
    layout :AceType, :byte,
           :AceFlags, :byte,
           :AceSize,  :word
  end

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa374892(v=vs.85).aspx
  # ACCESS_MASK

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa374847(v=vs.85).aspx
  # typedef struct _ACCESS_ALLOWED_ACE {
  #   ACE_HEADER  Header;
  #   ACCESS_MASK Mask;
  #   DWORD       SidStart;
  # } ACCESS_ALLOWED_ACE, *PACCESS_ALLOWED_ACE;
  #
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa374879(v=vs.85).aspx
  # typedef struct _ACCESS_DENIED_ACE {
  #   ACE_HEADER  Header;
  #   ACCESS_MASK Mask;
  #   DWORD       SidStart;
  # } ACCESS_DENIED_ACE, *PACCESS_DENIED_ACE;
  class GENERIC_ACCESS_ACE < FFI::Struct
    # ACE structures must be aligned on DWORD boundaries. All Windows
    # memory-management functions return DWORD-aligned handles to memory
    pack 4
    layout :Header, ACE_HEADER,
           :Mask, :dword,
           :SidStart, :dword
  end

  # https://stackoverflow.com/a/1792930
  MAXIMUM_SID_BYTES_LENGTH = 68
  MAXIMUM_GENERIC_ACE_SIZE = GENERIC_ACCESS_ACE.offset_of(:SidStart) +
    MAXIMUM_SID_BYTES_LENGTH

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446634(v=vs.85).aspx
  # BOOL WINAPI GetAce(
  #   _In_   PACL pAcl,
  #   _In_   DWORD dwAceIndex,
  #   _Out_  LPVOID *pAce
  # );
  ffi_lib :advapi32
  attach_function_private :GetAce,
    [:pointer, :dword, :pointer], :win32_bool

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa375202(v=vs.85).aspx
  # BOOL WINAPI AdjustTokenPrivileges(
  #   _In_       HANDLE TokenHandle,
  #   _In_       BOOL DisableAllPrivileges,
  #   _In_opt_   PTOKEN_PRIVILEGES NewState,
  #   _In_       DWORD BufferLength,
  #   _Out_opt_  PTOKEN_PRIVILEGES PreviousState,
  #   _Out_opt_  PDWORD ReturnLength
  # );
  ffi_lib :advapi32
  attach_function_private :AdjustTokenPrivileges,
    [:handle, :win32_bool, :pointer, :dword, :pointer, :pdword], :win32_bool

  # https://msdn.microsoft.com/en-us/library/windows/hardware/ff556610(v=vs.85).aspx
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379561(v=vs.85).aspx
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446647(v=vs.85).aspx
  # typedef WORD SECURITY_DESCRIPTOR_CONTROL, *PSECURITY_DESCRIPTOR_CONTROL;
  # BOOL WINAPI GetSecurityDescriptorControl(
  #   _In_   PSECURITY_DESCRIPTOR pSecurityDescriptor,
  #   _Out_  PSECURITY_DESCRIPTOR_CONTROL pControl,
  #   _Out_  LPDWORD lpdwRevision
  # );
  ffi_lib :advapi32
  attach_function_private :GetSecurityDescriptorControl,
    [:pointer, :lpword, :lpdword], :win32_bool

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa378853(v=vs.85).aspx
  # BOOL WINAPI InitializeAcl(
  #   _Out_  PACL pAcl,
  #   _In_   DWORD nAclLength,
  #   _In_   DWORD dwAclRevision
  # );
  ffi_lib :advapi32
  attach_function_private :InitializeAcl,
    [:pointer, :dword, :dword], :win32_bool

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379142(v=vs.85).aspx
  # BOOL WINAPI IsValidAcl(
  #   _In_  PACL pAcl
  # );
  ffi_lib :advapi32
  attach_function_private :IsValidAcl,
    [:pointer], :win32_bool

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379593(v=vs.85).aspx
  SE_OBJECT_TYPE = enum(
    :SE_UNKNOWN_OBJECT_TYPE, 0,
    :SE_FILE_OBJECT,
    :SE_SERVICE,
    :SE_PRINTER,
    :SE_REGISTRY_KEY,
    :SE_LMSHARE,
    :SE_KERNEL_OBJECT,
    :SE_WINDOW_OBJECT,
    :SE_DS_OBJECT,
    :SE_DS_OBJECT_ALL,
    :SE_PROVIDER_DEFINED_OBJECT,
    :SE_WMIGUID_OBJECT,
    :SE_REGISTRY_WOW64_32KEY
  )

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446654(v=vs.85).aspx
  # DWORD WINAPI GetSecurityInfo(
  #   _In_       HANDLE handle,
  #   _In_       SE_OBJECT_TYPE ObjectType,
  #   _In_       SECURITY_INFORMATION SecurityInfo,
  #   _Out_opt_  PSID *ppsidOwner,
  #   _Out_opt_  PSID *ppsidGroup,
  #   _Out_opt_  PACL *ppDacl,
  #   _Out_opt_  PACL *ppSacl,
  #   _Out_opt_  PSECURITY_DESCRIPTOR *ppSecurityDescriptor
  # );
  ffi_lib :advapi32
  attach_function_private :GetSecurityInfo,
    [:handle, SE_OBJECT_TYPE, :dword, :pointer, :pointer, :pointer, :pointer, :pointer], :dword

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379588(v=vs.85).aspx
  # DWORD WINAPI SetSecurityInfo(
  #   _In_      HANDLE handle,
  #   _In_      SE_OBJECT_TYPE ObjectType,
  #   _In_      SECURITY_INFORMATION SecurityInfo,
  #   _In_opt_  PSID psidOwner,
  #   _In_opt_  PSID psidGroup,
  #   _In_opt_  PACL pDacl,
  #   _In_opt_  PACL pSacl
  # );
  ffi_lib :advapi32
  # TODO: SECURITY_INFORMATION is actually a bitmask the size of a DWORD
  attach_function_private :SetSecurityInfo,
    [:handle, SE_OBJECT_TYPE, :dword, :pointer, :pointer, :pointer, :pointer], :dword
end
