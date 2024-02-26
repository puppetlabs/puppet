# frozen_string_literal: true

require_relative '../../puppet/x509'

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
  def save_pem(pem, path, owner: nil, group: nil, mode: 0o644)
    Puppet::FileSystem.replace_file(path, mode) do |f|
      f.set_encoding('UTF-8')
      f.write(pem.encode('UTF-8'))
    end

    if !Puppet::Util::Platform.windows? && Puppet.features.root? && (owner || group)
      FileUtils.chown(owner, group, path)
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
end
