require 'puppet/x509'

# Methods for managing PEM encoded files. While PEM encoded strings are
# always ASCII, the files may contain user specified comments, so they are
# UTF-8 encoded.
#
# @api private
module Puppet::X509::PemStore
  # Load a pem encoded object.
  #
  # @param path [String] file path
  # @return [String, nil] The PEM encoded object or nil if the
  #  path does not exist
  # @raise [Errno::EACCES] if permission is denied
  # @api private
  def load_pem(path)
    Puppet::FileSystem.read(path, encoding: 'UTF-8')
  rescue Errno::ENOENT
    nil
  end

  # Save pem encoded content to a file. If the file doesn't exist, it
  # will be created. Otherwise, the file will be overwritten. In both
  # cases the contents will be overwritten atomically so other
  # processes don't see a partially written file.
  #
  # @param pem [String] The PEM encoded object to write
  # @param path [String] The file path to write to
  # @raise [Errno::EACCES] if permission is denied
  # @raise [Errno::EPERM] if the operation cannot be completed
  # @api private
  def save_pem(pem, path)
    if Puppet::Util::Platform.windows?
      save_pem_win32(pem, path)
    else
      save_pem_posix(pem, path)
    end
  end

  # Delete a pem encoded object, if it exists.
  #
  # @param path [String] The file path to delete
  # @return [Boolean] Returns true if the file was deleted, false otherwise
  # @raise [Errno::EACCES] if permission is denied
  # @api private
  def delete_pem(path)
    Puppet::FileSystem.unlink(path)
    true
  rescue Errno::ENOENT
    false
  end

  private

  def save_pem_posix(pem, path)
    Puppet::Util.replace_file(path, 0644) do |f|
      f.set_encoding('UTF-8')
      f.write(pem.encode('UTF-8'))
    end
  end

  # https://docs.microsoft.com/en-us/windows/desktop/debug/system-error-codes--0-499-
  ACCESS_DENIED = 5
  SHARING_VIOLATION = 32
  LOCK_VIOLATION = 33

  def save_pem_win32(pem, path)
    # Puppet::Util.replace_file should be implemented in Puppet::FileSystem
    # and raise Errno-based exceptions
    save_pem_posix(pem, path)
  rescue Puppet::Util::Windows::Error => e
    case e.code
    when ACCESS_DENIED, SHARING_VIOLATION, LOCK_VIOLATION
      raise Errno::EACCES.new(path, e)
    else
      raise SystemCallError.new(e.message, e)
    end
  end
end
