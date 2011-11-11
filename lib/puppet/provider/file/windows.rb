Puppet::Type.type(:file).provide :windows do
  desc "Uses Microsoft Windows functionality to manage file's users and rights."

  confine :operatingsystem => :windows

  include Puppet::Util::Warnings

  if Puppet.features.microsoft_windows?
    require 'puppet/util/windows'
    require 'puppet/util/adsi'
    include Puppet::Util::Windows::Security
  end

  ERROR_INVALID_SID_STRUCTURE = 1337

  def id2name(id)
    # If it's a valid sid, get the name. Otherwise, it's already a name, so
    # just return it.
    begin
      if string_to_sid_ptr(id)
        name = nil
        Puppet::Util::ADSI.execquery(
          "SELECT Name FROM Win32_Account WHERE SID = '#{id}'
           AND LocalAccount = true"
        ).each { |a| name ||= a.name }
        return name
      end
    rescue Puppet::Util::Windows::Error => e
      raise unless e.code == ERROR_INVALID_SID_STRUCTURE
    end

    id
  end

  # Determine if the account is valid, and if so, return the UID
  def name2id(value)
    # If it's a valid sid, then return it. Else, it's a name we need to convert
    # to sid.
    begin
      return value if string_to_sid_ptr(value)
    rescue Puppet::Util::Windows::Error => e
      raise unless e.code == ERROR_INVALID_SID_STRUCTURE
    end

    Puppet::Util::ADSI.sid_for_account(value) rescue nil
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
