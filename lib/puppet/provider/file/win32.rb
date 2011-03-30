Puppet::Type.type(:file).provide :microsoft_windows do
  desc "Uses Microsoft Windows functionality to manage file's users and rights."

  confine :feature => :microsoft_windows

  include Puppet::Util::Warnings

  require 'sys/admin' if Puppet.features.microsoft_windows?

  def id2name(id)
    return id.to_s if id.is_a?(Symbol)
    return nil if id > Puppet[:maximum_uid].to_i
    # should translate ID numbers to usernames
    id
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
    info "Is '#{value}' a valid user?"
    return 0
    begin
      number = Integer(value)
      return number
    rescue ArgumentError
      number = nil
    end
    (number = uid(value)) && number
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
    info("should set '%s'%%owner to '%s'" % [path, should])
  end
end
