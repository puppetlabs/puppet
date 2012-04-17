require 'puppet/util/lockfile'

class Puppet::Util::JsonFilelock < Puppet::Util::Lockfile
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
    return nil if file_contents.nil?
    PSON.parse(file_contents)
  end

end