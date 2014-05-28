# This class provides a simple API for managing a lock file
# whose contents are an (optional) String.  In addition
# to querying the basic state (#locked?) of the lock, managing
# the lock (#lock, #unlock), the contents can be retrieved at
# any time while the lock is held (#lock_data).  This can be
# used to store pids, messages, etc.
#
# @see Puppet::Util::JsonLockfile
class Puppet::Util::Lockfile
  attr_reader :file_path

  def initialize(file_path)
    @file_path = file_path
  end

  # Lock the lockfile.  You may optionally pass a data object, which will be
  # retrievable for the duration of time during which the file is locked.
  #
  # @param [String] lock_data an optional String data object to associate
  #   with the lock.  This may be used to store pids, descriptive messages,
  #   etc.  The data may be retrieved at any time while the lock is held by
  #   calling the #lock_data method.

  # @return [boolean] true if lock is successfully acquired, false otherwise.
  def lock(lock_data = nil)
    begin
      Puppet::FileSystem.exclusive_create(@file_path, nil) do |fd|
        fd.print(lock_data)
      end
      true
    rescue Errno::EEXIST
      false
    end
  end

  def unlock
    if locked?
      Puppet::FileSystem.unlink(@file_path)
      true
    else
      false
    end
  end

  def locked?
    # delegate logic to a more explicit private method
    file_locked?
  end

  # Retrieve the (optional) lock data that was specified at the time the file
  #  was locked.
  # @return [String] the data object.
  def lock_data
    return File.read(@file_path) if file_locked?
  end

  # Private, internal utility method for encapsulating the logic about
  #  whether or not the file is locked.  This method can be called
  #  by other methods in this class without as much risk of accidentally
  #  being overridden by child classes.
  # @return [boolean] true if the file is locked, false if it is not.
  def file_locked?
    Puppet::FileSystem.exist? @file_path
  end
  private :file_locked?
end
