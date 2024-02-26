# frozen_string_literal: true

require_relative '../../puppet/file_system/posix'
require_relative '../../puppet/util/windows'

class Puppet::FileSystem::Windows < Puppet::FileSystem::Posix
  FULL_CONTROL = Puppet::Util::Windows::File::FILE_ALL_ACCESS
  FILE_READ = Puppet::Util::Windows::File::FILE_GENERIC_READ

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
    return string_path unless string_path.index('~')

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
    return false unless Puppet.features.manages_symlinks?

    Puppet::Util::Windows::File.symlink?(path)
  end

  def readlink(path)
    raise_if_symlinks_unsupported
    Puppet::Util::Windows::File.readlink(path)
  end

  def unlink(*file_names)
    unless Puppet.features.manages_symlinks?
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
    unless Puppet.features.manages_symlinks?
      return Puppet::Util::Windows::File.stat(path)
    end

    Puppet::Util::Windows::File.lstat(path)
  end

  def chmod(mode, path)
    Puppet::Util::Windows::Security.set_mode(mode, path.to_s)
  end

  def read_preserve_line_endings(path)
    contents = path.read(:mode => 'rb', :encoding => 'bom|utf-8')
    contents = path.read(:mode => 'rb', :encoding => "bom|#{Encoding.default_external.name}") unless contents.valid_encoding?
    contents = path.read unless contents.valid_encoding?

    contents
  end

  # https://docs.microsoft.com/en-us/windows/desktop/debug/system-error-codes--0-499-
  FILE_NOT_FOUND = 2
  ACCESS_DENIED = 5
  SHARING_VIOLATION = 32
  LOCK_VIOLATION = 33

  def replace_file(path, mode = nil)
    if directory?(path)
      raise Errno::EISDIR, _("Is a directory: %{directory}") % { directory: path }
    end

    current_sid = Puppet::Util::Windows::SID.name_to_sid(Puppet::Util::Windows::ADSI::User.current_user_name)
    current_sid ||= Puppet::Util::Windows::SID.name_to_sid(Puppet::Util::Windows::ADSI::User.current_sam_compatible_user_name)

    dacl = case mode
           when 0o644
             dacl = secure_dacl(current_sid)
             dacl.allow(Puppet::Util::Windows::SID::BuiltinUsers, FILE_READ)
             dacl
           when 0o660, 0o640, 0o600, 0o440
             secure_dacl(current_sid)
           when nil
             get_dacl_from_file(path) || secure_dacl(current_sid)
           else
             raise ArgumentError, "#{mode} is invalid: Only modes 0644, 0640, 0660, and 0440 are allowed"
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
      ::File.rename(tempfile.path, path_string(path))
    ensure
      tempfile.close!
    end
  rescue Puppet::Util::Windows::Error => e
    case e.code
    when ACCESS_DENIED, SHARING_VIOLATION, LOCK_VIOLATION
      raise Errno::EACCES.new(path_string(path), e)
    else
      raise SystemCallError.new(e.message)
    end
  end

  private

  def set_dacl(path, dacl)
    sd = Puppet::Util::Windows::Security.get_security_descriptor(path)
    new_sd = Puppet::Util::Windows::SecurityDescriptor.new(sd.owner, sd.group, dacl, true)
    Puppet::Util::Windows::Security.set_security_descriptor(path, new_sd)
  end

  def secure_dacl(current_sid)
    dacl = Puppet::Util::Windows::AccessControlList.new
    [
      Puppet::Util::Windows::SID::LocalSystem,
      Puppet::Util::Windows::SID::BuiltinAdministrators,
      current_sid
    ].uniq.map do |sid|
      dacl.allow(sid, FULL_CONTROL)
    end
    dacl
  end

  def get_dacl_from_file(path)
    sd = Puppet::Util::Windows::Security.get_security_descriptor(path_string(path))
    sd.dacl
  rescue Puppet::Util::Windows::Error => e
    raise e unless e.code == FILE_NOT_FOUND
  end

  def raise_if_symlinks_unsupported
    unless Puppet.features.manages_symlinks?
      msg = _("This version of Windows does not support symlinks.  Windows Vista / 2008 or higher is required.")
      raise Puppet::Util::Windows::Error.new(msg)
    end

    unless Puppet::Util::Windows::Process.process_privilege_symlink?
      Puppet.warning _("The current user does not have the necessary permission to manage symlinks.")
    end
  end
end
