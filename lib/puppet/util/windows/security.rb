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
#   parent. See http://support.microsoft.com/kb/238018. But on Unix,
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
# * On Unix, the owner and group can be modified without changing the
#   mode. But on Windows, an access control entry specifies which SID
#   it applies to. As a result, the set_owner and set_group methods
#   automatically rebuild the access control list based on the new
#   (and different) owner or group.

require 'puppet/util/windows'

require 'win32/security'

require 'windows/file'
require 'windows/handle'
require 'windows/security'
require 'windows/process'
require 'windows/memory'

module Puppet::Util::Windows::Security
  include Windows::File
  include Windows::Handle
  include Windows::Security
  include Windows::Process
  include Windows::Memory
  include Windows::MSVCRT::Buffer

  extend Puppet::Util::Windows::Security

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
  S_IEXTRA = 02000000  # represents an extra ace

  # constants that are missing from Windows::Security
  PROTECTED_DACL_SECURITY_INFORMATION   = 0x80000000
  UNPROTECTED_DACL_SECURITY_INFORMATION = 0x20000000
  NO_INHERITANCE = 0x0

  # Set the owner of the object referenced by +path+ to the specified
  # +owner_sid+.  The owner sid should be of the form "S-1-5-32-544"
  # and can either be a user or group.  Only a user with the
  # SE_RESTORE_NAME privilege in their process token can overwrite the
  # object's owner to something other than the current user.
  def set_owner(owner_sid, path)
    old_sid = get_owner(path)

    change_sid(old_sid, owner_sid, OWNER_SECURITY_INFORMATION, path)
  end

  # Get the owner of the object referenced by +path+.  The returned
  # value is a SID string, e.g. "S-1-5-32-544".  Any user with read
  # access to an object can get the owner. Only a user with the
  # SE_BACKUP_NAME privilege in their process token can get the owner
  # for objects they do not have read access to.
  def get_owner(path)
    get_sid(OWNER_SECURITY_INFORMATION, path)
  end

  # Set the owner of the object referenced by +path+ to the specified
  # +group_sid+.  The group sid should be of the form "S-1-5-32-544"
  # and can either be a user or group.  Any user with WRITE_OWNER
  # access to the object can change the group (regardless of whether
  # the current user belongs to that group or not).
  def set_group(group_sid, path)
    old_sid = get_group(path)

    change_sid(old_sid, group_sid, GROUP_SECURITY_INFORMATION, path)
  end

  # Get the group of the object referenced by +path+.  The returned
  # value is a SID string, e.g. "S-1-5-32-544".  Any user with read
  # access to an object can get the group. Only a user with the
  # SE_BACKUP_NAME privilege in their process token can get the group
  # for objects they do not have read access to.
  def get_group(path)
    get_sid(GROUP_SECURITY_INFORMATION, path)
  end

  def change_sid(old_sid, new_sid, info, path)
    if old_sid != new_sid
      mode = get_mode(path)

      string_to_sid_ptr(new_sid) do |psid|
        with_privilege(SE_RESTORE_NAME) do
          open_file(path, WRITE_OWNER) do |handle|
            set_security_info(handle, info, psid)
          end
        end
      end

      # rebuild dacl now that sid has changed
      set_mode(mode, path)
    end
  end

  def get_sid(info, path)
    with_privilege(SE_BACKUP_NAME) do
      open_file(path, READ_CONTROL) do |handle|
        get_security_info(handle, info)
      end
    end
  end

  def get_attributes(path)
    attributes = GetFileAttributes(path)

    raise Puppet::Util::Windows::Error.new("Failed to get file attributes") if attributes == INVALID_FILE_ATTRIBUTES

    attributes
  end

  def add_attributes(path, flags)
    set_attributes(path, get_attributes(path) | flags)
  end

  def remove_attributes(path, flags)
    set_attributes(path, get_attributes(path) & ~flags)
  end

  def set_attributes(path, flags)
    raise Puppet::Util::Windows::Error.new("Failed to set file attributes") if SetFileAttributes(path, flags) == 0
  end

  MASK_TO_MODE = {
    FILE_GENERIC_READ => S_IROTH,
    FILE_GENERIC_WRITE => S_IWOTH,
    (FILE_GENERIC_EXECUTE & ~FILE_READ_ATTRIBUTES) => S_IXOTH
  }

  # Get the mode of the object referenced by +path+.  The returned
  # integer value represents the POSIX-style read, write, and execute
  # modes for the user, group, and other classes, e.g. 0640.  Other
  # modes, e.g. S_ISVTX, are not supported.  Any user with read access
  # to an object can get the mode. Only a user with the SE_BACKUP_NAME
  # privilege in their process token can get the mode for objects they
  # do not have read access to.
  def get_mode(path)
    owner_sid = get_owner(path)
    group_sid = get_group(path)
    well_known_world_sid = Win32::Security::SID::Everyone

    with_privilege(SE_BACKUP_NAME) do
      open_file(path, READ_CONTROL) do |handle|
        mode = 0

        get_dacl(handle).each do |ace|
          case ace[:sid]
          when owner_sid
            MASK_TO_MODE.each_pair do |k,v|
              if (ace[:mask] & k) == k
                mode |= (v << 6)
              end
            end
          when group_sid
            MASK_TO_MODE.each_pair do |k,v|
              if (ace[:mask] & k) == k
                mode |= (v << 3)
              end
            end
          when well_known_world_sid
            MASK_TO_MODE.each_pair do |k,v|
              if (ace[:mask] & k) == k
                mode |= (v << 6) | (v << 3) | v
              end
            end
          else
            #puts "Warning, unable to map SID into POSIX mode: #{ace[:sid]}"
            mode |= S_IEXTRA
          end

          # if owner and group the same, then user and group modes are the OR of both
          if owner_sid == group_sid
            mode |= ((mode & S_IRWXG) << 3) | ((mode & S_IRWXU) >> 3)
            #puts "owner: #{group_sid}, 0x#{ace[:mask].to_s(16)}, #{mode.to_s(8)}"
          end
        end

        #puts "get_mode: #{mode.to_s(8)}"
        mode
      end
    end
  end

  MODE_TO_MASK = {
    S_IROTH => FILE_GENERIC_READ,
    S_IWOTH => FILE_GENERIC_WRITE,
    S_IXOTH => (FILE_GENERIC_EXECUTE & ~FILE_READ_ATTRIBUTES),
    (S_IWOTH | S_IXOTH) => FILE_DELETE_CHILD,
  }

  # Set the mode of the object referenced by +path+ to the specified
  # +mode+.  The mode should be specified as POSIX-stye read, write,
  # and execute modes for the user, group, and other classes,
  # e.g. 0640. Other modes, e.g. S_ISVTX, are not supported. By
  # default, the DACL is set to protected, meaning it does not inherit
  # access control entries from parent objects. This can be changed by
  # setting +protected+ to false. The owner of the object (with
  # READ_CONTROL and WRITE_DACL access) can always change the
  # mode. Only a user with the SE_BACKUP_NAME and SE_RESTORE_NAME
  # privileges in their process token can change the mode for objects
  # that they do not have read and write access to.
  def set_mode(mode, path, protected = true)
    owner_sid = get_owner(path)
    group_sid = get_group(path)
    well_known_world_sid = Win32::Security::SID::Everyone

    owner_allow = STANDARD_RIGHTS_ALL  | FILE_READ_ATTRIBUTES | FILE_WRITE_ATTRIBUTES
    group_allow = STANDARD_RIGHTS_READ | FILE_READ_ATTRIBUTES | SYNCHRONIZE
    other_allow = STANDARD_RIGHTS_READ | FILE_READ_ATTRIBUTES | SYNCHRONIZE

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

    # if owner and group the same, then map group permissions to the one owner ACE
    isownergroup = owner_sid == group_sid
    if isownergroup
      owner_allow |= group_allow
    end

    set_acl(path, protected) do |acl|
      #puts "ace: owner #{owner_sid}, mask 0x#{owner_allow.to_s(16)}"
      add_access_allowed_ace(acl, owner_allow, owner_sid)

      unless isownergroup
        #puts "ace: group #{group_sid}, mask 0x#{group_allow.to_s(16)}"
        add_access_allowed_ace(acl, group_allow, group_sid)
      end

      #puts "ace: other #{well_known_world_sid}, mask 0x#{other_allow.to_s(16)}"
      add_access_allowed_ace(acl, other_allow, well_known_world_sid)

      # add inheritable aces for child dirs and files that are created within the dir
      if File.directory?(path)
        inherit = INHERIT_ONLY_ACE | OBJECT_INHERIT_ACE | CONTAINER_INHERIT_ACE

        add_access_allowed_ace(acl, owner_allow, Win32::Security::SID::CreatorOwner, inherit)
        add_access_allowed_ace(acl, group_allow, Win32::Security::SID::CreatorGroup, inherit)
        add_access_allowed_ace(acl, other_allow, well_known_world_sid, inherit)
      end
    end

    # if any ACE allows write, then clear readonly bit
    if ((owner_allow | group_allow | other_allow ) & FILE_WRITE_DATA) == FILE_WRITE_DATA
      remove_attributes(path, FILE_ATTRIBUTE_READONLY)
    end

    nil
  end

  # setting DACL requires both READ_CONTROL and WRITE_DACL access rights,
  # and their respective privileges, SE_BACKUP_NAME and SE_RESTORE_NAME.
  def set_acl(path, protected = true)
    with_privilege(SE_BACKUP_NAME) do
      with_privilege(SE_RESTORE_NAME) do
        open_file(path, READ_CONTROL | WRITE_DAC) do |handle|
          acl = 0.chr * 1024 # This can be increased later as needed

          unless InitializeAcl(acl, acl.size, ACL_REVISION)
            raise Puppet::Util::Windows::Error.new("Failed to initialize ACL")
          end

          raise Puppet::Util::Windows::Error.new("Invalid DACL") if IsValidAcl(acl) == 0

          yield acl

          # protected means the object does not inherit aces from its parent
          info = DACL_SECURITY_INFORMATION
          info |= protected ? PROTECTED_DACL_SECURITY_INFORMATION : UNPROTECTED_DACL_SECURITY_INFORMATION

          # set the DACL
          set_security_info(handle, info, acl)
        end
      end
    end
  end

  def add_access_allowed_ace(acl, mask, sid, inherit = NO_INHERITANCE)
    string_to_sid_ptr(sid) do |sid_ptr|
      raise Puppet::Util::Windows::Error.new("Invalid SID") if IsValidSid(sid_ptr) == 0

      if AddAccessAllowedAceEx(acl, ACL_REVISION, inherit, mask, sid_ptr) == 0
        raise Puppet::Util::Windows::Error.new("Failed to add access control entry")
      end
    end
  end

  def add_access_denied_ace(acl, mask, sid)
    string_to_sid_ptr(sid) do |sid_ptr|
      raise Puppet::Util::Windows::Error.new("Invalid SID") if IsValidSid(sid_ptr) == 0

      if AddAccessDeniedAce(acl, ACL_REVISION, mask, sid_ptr) == 0
        raise Puppet::Util::Windows::Error.new("Failed to add access control entry")
      end
    end
  end

  def get_dacl(handle)
    get_dacl_ptr(handle) do |dacl_ptr|
      # REMIND: need to handle NULL DACL
      raise Puppet::Util::Windows::Error.new("Invalid DACL") if IsValidAcl(dacl_ptr) == 0

      # ACL structure, size and count are the important parts. The
      # size includes both the ACL structure and all the ACEs.
      #
      # BYTE AclRevision
      # BYTE Padding1
      # WORD AclSize
      # WORD AceCount
      # WORD Padding2
      acl_buf = 0.chr * 8
      memcpy(acl_buf, dacl_ptr, acl_buf.size)
      ace_count = acl_buf.unpack('CCSSS')[3]

      dacl = []

      # deny all
      return dacl if ace_count == 0

      0.upto(ace_count - 1) do |i|
        ace_ptr = [0].pack('L')
        next if GetAce(dacl_ptr, i, ace_ptr) == 0

        # ACE structures vary depending on the type. All structures
        # begin with an ACE header, which specifies the type, flags
        # and size of what follows. We are only concerned with
        # ACCESS_ALLOWED_ACE and ACCESS_DENIED_ACEs, which have the
        # same structure:
        #
        # BYTE  C AceType
        # BYTE  C AceFlags
        # WORD  S AceSize
        # DWORD L ACCESS_MASK
        # DWORD L Sid
        # ..      ...
        # DWORD L Sid

        ace_buf = 0.chr * 8
        memcpy(ace_buf, ace_ptr.unpack('L')[0], ace_buf.size)

        ace_type, ace_flags, size, mask = ace_buf.unpack('CCSL')

        # skip aces that only serve to propagate inheritance
        next if (ace_flags & INHERIT_ONLY_ACE).nonzero?

        case ace_type
        when ACCESS_ALLOWED_ACE_TYPE
          sid_ptr = ace_ptr.unpack('L')[0] + 8 # address of ace_ptr->SidStart
          raise Puppet::Util::Windows::Error.new("Failed to read DACL, invalid SID") unless IsValidSid(sid_ptr)
          sid = sid_ptr_to_string(sid_ptr)
          dacl << {:sid => sid, :type => ace_type, :mask => mask}
        else
          Puppet.warning "Unsupported access control entry type: 0x#{ace_type.to_s(16)}"
        end
      end

      dacl
    end
  end

  def get_dacl_ptr(handle)
    dacl = [0].pack('L')
    sd = [0].pack('L')

    rv = GetSecurityInfo(
         handle,
         SE_FILE_OBJECT,
         DACL_SECURITY_INFORMATION,
         nil,
         nil,
         dacl, #dacl
         nil, #sacl
         sd) #sec desc
    raise Puppet::Util::Windows::Error.new("Failed to get DACL") unless rv == ERROR_SUCCESS
    begin
      yield dacl.unpack('L')[0]
    ensure
      LocalFree(sd.unpack('L')[0])
    end
  end

  # Set the security info on the specified handle.
  def set_security_info(handle, info, ptr)
    rv = SetSecurityInfo(
         handle,
         SE_FILE_OBJECT,
         info,
         (info & OWNER_SECURITY_INFORMATION) == OWNER_SECURITY_INFORMATION ? ptr : nil,
         (info & GROUP_SECURITY_INFORMATION) == GROUP_SECURITY_INFORMATION ? ptr : nil,
         (info & DACL_SECURITY_INFORMATION) == DACL_SECURITY_INFORMATION ? ptr : nil,
         nil)
    raise Puppet::Util::Windows::Error.new("Failed to set security information") unless rv == ERROR_SUCCESS
  end

  # Get the SID string, e.g. "S-1-5-32-544", for the specified handle
  # and type of information (owner, group).
  def get_security_info(handle, info)
    sid = [0].pack('L')
    sd = [0].pack('L')

    rv = GetSecurityInfo(
         handle,
         SE_FILE_OBJECT,
         info, # security info
         info == OWNER_SECURITY_INFORMATION ? sid : nil,
         info == GROUP_SECURITY_INFORMATION ? sid : nil,
         nil, #dacl
         nil, #sacl
         sd) #sec desc
    raise Puppet::Util::Windows::Error.new("Failed to get security information") unless rv == ERROR_SUCCESS

    begin
      return sid_ptr_to_string(sid.unpack('L')[0])
    ensure
      LocalFree(sd.unpack('L')[0])
    end
  end

  # Convert a SID pointer to a string, e.g. "S-1-5-32-544".
  def sid_ptr_to_string(psid)
    sid_buf = 0.chr * 256
    str_ptr = 0.chr * 4

    raise Puppet::Util::Windows::Error.new("Invalid SID") if IsValidSid(psid) == 0

    raise Puppet::Util::Windows::Error.new("Failed to convert binary SID") if ConvertSidToStringSid(psid, str_ptr) == 0

    begin
      strncpy(sid_buf, str_ptr.unpack('L')[0], sid_buf.size - 1)
      sid_buf[sid_buf.size - 1] = 0.chr
      return sid_buf.strip
    ensure
      LocalFree(str_ptr.unpack('L')[0])
    end
  end

  # Convert a SID string, e.g. "S-1-5-32-544" to a pointer (containing the
  # address of the binary SID structure). The returned value can be used in
  # Win32 APIs that expect a PSID, e.g. IsValidSid.
  def string_to_sid_ptr(string)
    sid_buf = 0.chr * 80
    string_addr = [string].pack('p*').unpack('L')[0]

    raise Puppet::Util::Windows::Error.new("Failed to convert string SID: #{string}") unless ConvertStringSidToSid(string_addr, sid_buf)

    sid_ptr = sid_buf.unpack('L')[0]
    begin
      if block_given?
        yield sid_ptr
      else
        true
      end
    ensure
      LocalFree(sid_ptr)
    end
  end

  # Open an existing file with the specified access mode, and execute a
  # block with the opened file HANDLE.
  def open_file(path, access)
    handle = CreateFile(
             path,
             access,
             FILE_SHARE_READ | FILE_SHARE_WRITE,
             0, # security_attributes
             OPEN_EXISTING,
             FILE_FLAG_BACKUP_SEMANTICS,
             0) # template
    raise Puppet::Util::Windows::Error.new("Failed to open '#{path}'") if handle == INVALID_HANDLE_VALUE
    begin
      yield handle
    ensure
      CloseHandle(handle)
    end
  end

  # Execute a block with the specified privilege enabled
  def with_privilege(privilege)
    set_privilege(privilege, true)
    yield
  ensure
    set_privilege(privilege, false)
  end

  # Enable or disable a privilege. Note this doesn't add any privileges the
  # user doesn't already has, it just enables privileges that are disabled.
  def set_privilege(privilege, enable)
    return unless Puppet.features.root?

    with_process_token(TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY) do |token|
      tmpLuid = 0.chr * 8

      # Get the LUID for specified privilege.
      if LookupPrivilegeValue("", privilege, tmpLuid) == 0
        raise Puppet::Util::Windows::Error.new("Failed to lookup privilege")
      end

      # DWORD + [LUID + DWORD]
      tkp = [1].pack('L') + tmpLuid + [enable ? SE_PRIVILEGE_ENABLED : 0].pack('L')

      if AdjustTokenPrivileges(token, 0, tkp, tkp.length , nil, nil) == 0
        raise Puppet::Util::Windows::Error.new("Failed to adjust process privileges")
      end
    end
  end

  # Execute a block with the current process token
  def with_process_token(access)
    token = 0.chr * 4

    if OpenProcessToken(GetCurrentProcess(), access, token) == 0
      raise Puppet::Util::Windows::Error.new("Failed to open process token")
    end
    begin
      token = token.unpack('L')[0]

      yield token
    ensure
      CloseHandle(token)
    end
  end
end
