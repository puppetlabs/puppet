
class Puppet::Util::AnonymousFilelock
  attr_reader :lockfile

  def initialize(lockfile)
    @lockfile = lockfile
  end

  def anonymous?
    true
  end

  def lock(msg = '')
    return false if locked?

    File.open(@lockfile, 'w') { |fd| fd.print(msg) }
    true
  end

  def unlock
    if locked?
      File.unlink(@lockfile)
      true
    else
      false
    end
  end

  def locked?
    File.exists? @lockfile
  end

  def message
    return File.read(@lockfile) if locked?
  end
end