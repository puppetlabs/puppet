Puppet::Type.type(:file).provide :posix do
  desc "Uses POSIX functionality to manage file's users and rights."

  confine :feature => :posix

  include Puppet::Util::POSIX
  include Puppet::Util::Warnings

  require 'etc'

  def id2name(id)
    return id.to_s if id.is_a?(Symbol)
    return nil if id > Puppet[:maximum_uid].to_i

    begin
      user = Etc.getpwuid(id)
    rescue TypeError
      return nil
    rescue ArgumentError
      return nil
    end

    if user.uid == ""
      return nil
    else
      return user.name
    end
  end

  def is_owner_insync?(current, should)
    should.each do |value|
      if value =~ /^\d+$/
        uid = Integer(value)
      elsif value.is_a?(String)
        fail "Could not find user #{value}" unless uid = uid(value)
      else
        uid = value
      end

      return true if uid == current
    end

    unless Puppet.features.root?
      warnonce "Cannot manage ownership unless running as root"
      return true
    end

    false
  end

  # Determine if the user is valid, and if so, return the UID
  def validuser?(value)
    Integer(value) rescue uid(value) || false
  end

  def retrieve(resource)
    unless stat = resource.stat
      return :absent
    end

    currentvalue = stat.uid

    # On OS X, files that are owned by -2 get returned as really
    # large UIDs instead of negative ones.  This isn't a Ruby bug,
    # it's an OS X bug, since it shows up in perl, too.
    if currentvalue > Puppet[:maximum_uid].to_i
      self.warning "Apparently using negative UID (#{currentvalue}) on a platform that does not consistently handle them"
      currentvalue = :silly
    end

    currentvalue
  end

  def sync(path, links, should)
    # Set our method appropriately, depending on links.
    if links == :manage
      method = :lchown
    else
      method = :chown
    end

    uid = nil
    should.each do |user|
      break if uid = validuser?(user)
    end

    raise Puppet::Error, "Could not find user(s) #{should.join(",")}" unless uid

    begin
      File.send(method, uid, nil, path)
    rescue => detail
      raise Puppet::Error, "Failed to set owner to '#{uid}': #{detail}"
    end

    :file_changed
  end
end
