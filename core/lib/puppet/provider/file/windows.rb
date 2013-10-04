Puppet::Type.type(:file).provide :windows do
  desc "Uses Microsoft Windows functionality to manage file ownership and permissions."

  confine :operatingsystem => :windows

  include Puppet::Util::Warnings

  if Puppet.features.microsoft_windows?
    require 'puppet/util/windows'
    require 'puppet/util/adsi'
    include Puppet::Util::Windows::Security
  end

  # Determine if the account is valid, and if so, return the UID
  def name2id(value)
    Puppet::Util::Windows::Security.name_to_sid(value)
  end

  # If it's a valid SID, get the name. Otherwise, it's already a name,
  # so just return it.
  def id2name(id)
    if Puppet::Util::Windows::Security.valid_sid?(id)
      Puppet::Util::Windows::Security.sid_to_name(id)
    else
      id
    end
  end

  # We use users and groups interchangeably, so use the same methods for both
  # (the type expects different methods, so we have to oblige).
  alias :uid2name :id2name
  alias :gid2name :id2name

  alias :name2gid :name2id
  alias :name2uid :name2id

  def owner
    return :absent unless resource.exist?
    get_owner(resource[:path])
  end

  def owner=(should)
    begin
      set_owner(should, resource[:path])
    rescue => detail
      raise Puppet::Error, "Failed to set owner to '#{should}': #{detail}"
    end
  end

  def group
    return :absent unless resource.exist?
    get_group(resource[:path])
  end

  def group=(should)
    begin
      set_group(should, resource[:path])
    rescue => detail
      raise Puppet::Error, "Failed to set group to '#{should}': #{detail}"
    end
  end

  def mode
    if resource.exist?
      mode = get_mode(resource[:path])
      mode ? mode.to_s(8) : :absent
    else
      :absent
    end
  end

  def mode=(value)
    begin
      set_mode(value.to_i(8), resource[:path])
    rescue => detail
      error = Puppet::Error.new("failed to set mode #{mode} on #{resource[:path]}: #{detail.message}")
      error.set_backtrace detail.backtrace
      raise error
    end
    :file_changed
  end

  def validate
    if [:owner, :group, :mode].any?{|p| resource[p]} and !supports_acl?(resource[:path])
      resource.fail("Can only manage owner, group, and mode on filesystems that support Windows ACLs, such as NTFS")
    end
  end
end
