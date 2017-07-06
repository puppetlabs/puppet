require 'puppet/util/lockfile'

# This class provides a simple API for managing a lock file
# whose contents are a serialized JSON object.  In addition
# to querying the basic state (#locked?) of the lock, managing
# the lock (#lock, #unlock), the contents can be retrieved at
# any time while the lock is held (#lock_data).  This can be
# used to store structured data (state messages, etc.) about
# the lock.
#
# @see Puppet::Util::Lockfile
class Puppet::Util::JsonLockfile < Puppet::Util::Lockfile
  # Lock the lockfile.  You may optionally pass a data object, which will be
  # retrievable for the duration of time during which the file is locked.
  #
  # @param [Hash] lock_data an optional Hash of data to associate with the lock.
  #   This may be used to store pids, descriptive messages, etc.  The
  #   data may be retrieved at any time while the lock is held by
  #   calling the #lock_data method. <b>NOTE</b> that the JSON serialization
  #   does NOT support Symbol objects--if you pass them in, they will be
  #   serialized as Strings, so you should plan accordingly.
  # @return [boolean] true if lock is successfully acquired, false otherwise.
  def lock(lock_data = nil)
    return false if locked?

    super(lock_data.to_pson)
  end

  # Retrieve the (optional) lock data that was specified at the time the file
  #  was locked.
  # @return [Object] the data object.  Remember that the serialization does not
  #  support Symbol objects, so if your data Object originally contained symbols,
  #  they will be converted to Strings.
  def lock_data
    return nil unless file_locked?
    file_contents = super
    return nil if file_contents.nil? or file_contents.empty?
    PSON.parse(file_contents)
  rescue PSON::ParserError => e
    Puppet.warning "Unable to read lockfile data from #{@file_path}: not in PSON"
    nil
  end

end
