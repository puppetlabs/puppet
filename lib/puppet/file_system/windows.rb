require 'puppet/file_system/posix'
require 'puppet/util/windows'

class Puppet::FileSystem::Windows < Puppet::FileSystem::Posix
  FULL_CONTROL = Puppet::Util::Windows::File::FILE_ALL_ACCESS
  FILE_READ = Puppet::Util::Windows::File::FILE_GENERIC_READ
  FILE_WRITE = Puppet::Util::Windows::File::FILE_GENERIC_WRITE
  FILE_RW = (FILE_READ | FILE_WRITE)

  def open(path, mode, options, &block)
    # PUP-6959 mode is explicitly ignored until it can be implemented
    # Ruby on Windows uses mode for setting file attributes like read-only and
    # archived, not for setting permissions like POSIX
    raise TypeError.new('mode must be specified as an Integer') if mode && !mode.is_a?(Numeric)
    ::File.open(path, options, nil, &block)
  end

  def expand_path(path, dir_string = nil)
    # ensure `nil` values behave like underlying File.expand_path
    string_path = ::File.expand_path(path.nil? ? nil : path_string(path), dir_string)
    # if no tildes, nothing to expand, no need to call Windows API, return original string
    return string_path if !string_path.index('~')

    begin
      # no need to do existence check up front as GetLongPathName implies that check is performed
      # and it should be the exception that files aren't actually present
      string_path = Puppet::Util::Windows::File.get_long_pathname(string_path)
    rescue Puppet::Util::Windows::Error => e
      # preserve original File.expand_path behavior for file / path not found by returning string
      raise if (e.code != Puppet::Util::Windows::File::ERROR_FILE_NOT_FOUND &&
        e.code != Puppet::Util::Windows::File::ERROR_PATH_NOT_FOUND)
    end

    string_path
  end

  def exist?(path)
    return Puppet::Util::Windows::File.exist?(path)
  end

  def symlink(path, dest, options = {})
    raise_if_symlinks_unsupported

    dest_exists = exist?(dest) # returns false on dangling symlink
    dest_stat = Puppet::Util::Windows::File.stat(dest) if dest_exists

    # silent fail to preserve semantics of original FileUtils
    return 0 if dest_exists && dest_stat.ftype == 'directory'

    if dest_exists && dest_stat.ftype == 'file' && options[:force] != true
      raise(Errno::EEXIST, _("%{dest} already exists and the :force option was not specified") % { dest: dest })
    end

    if options[:noop] != true
      ::File.delete(dest) if dest_exists # can only be file
      Puppet::Util::Windows::File.symlink(path, dest)
    end

    0
  end

  def symlink?(path)
    return false if ! Puppet.features.manages_symlinks?
    Puppet::Util::Windows::File.symlink?(path)
  end

  def readlink(path)
    raise_if_symlinks_unsupported
    Puppet::Util::Windows::File.readlink(path)
  end

  def unlink(*file_names)
    if ! Puppet.features.manages_symlinks?
      return ::File.unlink(*file_names)
    end

    file_names.each do |file_name|
      file_name = file_name.to_s # handle PathName
      stat = Puppet::Util::Windows::File.stat(file_name) rescue nil

      # sigh, Ruby + Windows :(
      if !stat
        ::File.unlink(file_name) rescue Dir.rmdir(file_name)
      elsif stat.ftype == 'directory'
        if Puppet::Util::Windows::File.symlink?(file_name)
          Dir.rmdir(file_name)
        else
          raise Errno::EPERM.new(file_name)
        end
      else
        ::File.unlink(file_name)
      end
    end

    file_names.length
  end

  def stat(path)
    Puppet::Util::Windows::File.stat(path)
  end

  def lstat(path)
    if ! Puppet.features.manages_symlinks?
      return Puppet::Util::Windows::File.stat(path)
    end
    Puppet::Util::Windows::File.lstat(path)
  end

  def chmod(mode, path)
    Puppet::Util::Windows::Security.set_mode(mode, path.to_s)
  end

  def read_preserve_line_endings(path)
    contents = path.read( :mode => 'rb', :encoding => Encoding::UTF_8)
    contents = path.read( :mode => 'rb', :encoding => Encoding::default_external) unless contents.valid_encoding?
    contents = path.read unless contents.valid_encoding?

    contents
  end

  # https://docs.microsoft.com/en-us/windows/desktop/debug/system-error-codes--0-499-
  FILE_NOT_FOUND = 2
  ACCESS_DENIED = 5
  SHARING_VIOLATION = 32
  LOCK_VIOLATION = 33

  def replace_file(path, mode = nil)
    # This method should only be used for internal file handling, as BuiltInAdministrators is added
    # as a right to any files created which is probably not desired for the "file:" provider.

    if Puppet::FileSystem.directory?(path)
      raise Errno::EISDIR, _("Is a directory: %{directory}") % { directory: path }
    end

    # Case through the provided mode and apply matching Windows rights.
    # Note mode 6 is set to READ/WRITE rather than FULL_CONTROL

    current_sid = Puppet::Util::Windows::SID.name_to_sid(Puppet::Util::Windows::ADSI::User.current_user_name)
    dacl = case mode
           when 0644
             dacl = secure_dacl(current_sid, FILE_RW, FILE_READ)
             dacl.allow(Puppet::Util::Windows::SID::BuiltinUsers, FILE_READ)
             dacl.allow(Puppet::Util::Windows::SID::Everyone, FILE_READ)
             dacl
           when 0640, 0600 # Setting both of these with Group Read Access
             dacl = secure_dacl(current_sid, FILE_RW, FILE_READ)
             dacl
           when 0660
             dacl = secure_dacl(current_sid, FILE_RW, FILE_RW)
             dacl
           when 0664
             dacl = secure_dacl(current_sid, FILE_RW, FILE_RW)
             dacl.allow(Puppet::Util::Windows::SID::BuiltinUsers, FILE_READ)
             dacl.allow(Puppet::Util::Windows::SID::Everyone, FILE_READ)
             dacl
           when 0666
             dacl = secure_dacl(current_sid, FILE_RW, FILE_RW)
             dacl.allow(Puppet::Util::Windows::SID::BuiltinUsers, FILE_RW)
             dacl.allow(Puppet::Util::Windows::SID::Everyone, FILE_RW)
             dacl
           when 0444
             dacl = secure_dacl(current_sid, FILE_READ, FILE_READ)
             dacl.allow(Puppet::Util::Windows::SID::BuiltinUsers, FILE_READ)
             dacl.allow(Puppet::Util::Windows::SID::Everyone, FILE_READ)
             dacl
           when 0440
             dacl = secure_dacl(current_sid, FILE_READ, FILE_READ)
             dacl
            when nil
             get_dacl_from_file(path) || secure_dacl(current_sid)
           else
             raise ArgumentError, "#{mode} is invalid: Only modes 0644, 0640, 0660, 0666, 0600 and 0440 are allowed"
           end

    tempfile = Puppet::FileSystem::Uniquefile.new(Puppet::FileSystem.basename_string(path), Puppet::FileSystem.dir_string(path))
    begin
      tempdacl = Puppet::Util::Windows::AccessControlList.new
      tempdacl.allow(current_sid, FULL_CONTROL)
      set_dacl(tempfile.path, tempdacl)

      begin
        yield tempfile
        tempfile.flush
        tempfile.fsync
      ensure
        tempfile.close
      end

      set_dacl(tempfile.path, dacl) if dacl
      File.rename(tempfile.path, Puppet::FileSystem.path_string(path))
    ensure
      tempfile.close!
    end
  rescue Puppet::Util::Windows::Error => e
    case e.code
    when ACCESS_DENIED, SHARING_VIOLATION, LOCK_VIOLATION
      raise Errno::EACCES.new(Puppet::FileSystem.path_string(path), e)
    else
      raise SystemCallError.new(e.message)
    end
  end

  private

  def set_dacl(path, dacl)
    # Set the DACL
    # This has a "special case" - if both Owner and Group are SYSTEM, then the Group field
    # is set to BuiltinAdministrators (PUP-9719). This is needed to ensure that if Puppet Agent
    # is run under SYSTEM/SYSTEM (e.g. under AWS services), that all internally managed Puppet files
    # are are still writeable from the Administrator account
    sd = Puppet::Util::Windows::Security.get_security_descriptor(path)
    sd_group = sd.group
    sd_owner = sd.owner

    if sd_group == sd_owner && sd_group == Puppet::Util::Windows::SID::LocalSystem
      sd_group = Puppet::Util::Windows::SID::BuiltinAdministrators
    end

    new_sd = Puppet::Util::Windows::SecurityDescriptor.new(sd_owner, sd_group, dacl, true)
    Puppet::Util::Windows::Security.set_security_descriptor(path, new_sd)
  end

  def secure_dacl(current_sid, owner_permission = FULL_CONTROL, group_permission = FULL_CONTROL)
    dacl = Puppet::Util::Windows::AccessControlList.new
    [
     Puppet::Util::Windows::SID::LocalSystem,
     Puppet::Util::Windows::SID::BuiltinAdministrators,
     current_sid
    ].uniq.map do |sid|
        permission = case sid
                     when Puppet::Util::Windows::SID::LocalSystem
                       owner_permission
                     when Puppet::Util::Windows::SID::BuiltinAdministrators
                       group_permission
                     else
                       owner_permission
                     end
        dacl.allow(sid, permission)
    end
    dacl
  end

  def get_dacl_from_file(path)
    sd = Puppet::Util::Windows::Security.get_security_descriptor(Puppet::FileSystem.path_string(path))
    sd.dacl
  rescue Puppet::Util::Windows::Error => e
    raise e unless e.code == FILE_NOT_FOUND
  end

  def raise_if_symlinks_unsupported
    if ! Puppet.features.manages_symlinks?
      msg = _("This version of Windows does not support symlinks.  Windows Vista / 2008 or higher is required.")
      raise Puppet::Util::Windows::Error.new(msg)
    end

    if ! Puppet::Util::Windows::Process.process_privilege_symlink?
      Puppet.warning _("The current user does not have the necessary permission to manage symlinks.")
    end
  end

end
