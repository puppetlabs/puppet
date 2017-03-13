Puppet::Type.type(:file).provide :windows do
  desc "Uses Microsoft Windows functionality to manage file ownership and permissions."

  confine :operatingsystem => :windows
  has_feature :manages_symlinks if Puppet.features.manages_symlinks?

  include Puppet::Util::Warnings

  if Puppet.features.microsoft_windows?
    require 'puppet/util/windows'
    include Puppet::Util::Windows::Security
  end

  # Determine if the account is valid, and if so, return the UID
  def name2id(value)
    Puppet::Util::Windows::SID.name_to_sid(value)
  end

  # If it's a valid SID, get the name. Otherwise, it's already a name,
  # so just return it.
  def id2name(id)
    if Puppet::Util::Windows::SID.valid_sid?(id)
      Puppet::Util::Windows::SID.sid_to_name(id)
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
    return :absent unless resource.stat
    get_owner(resource[:path])
  end

  def owner=(should)
    begin
      set_owner(should, resolved_path)
    rescue => detail
      raise Puppet::Error, _("Failed to set owner to '%{should}': %{detail}") % { should: should, detail: detail }, detail.backtrace
    end
  end

  def group
    return :absent unless resource.stat
    get_group(resource[:path])
  end

  def group=(should)
    begin
      set_group(should, resolved_path)
    rescue => detail
      raise Puppet::Error, _("Failed to set group to '%{should}': %{detail}") % { should: should, detail: detail }, detail.backtrace
    end
  end

  def mode
    if resource.stat
      mode = get_mode(resource[:path])
      mode ? mode.to_s(8).rjust(4, '0') : :absent
    else
      :absent
    end
  end

  def mode=(value)
    begin
      set_mode(value.to_i(8), resource[:path])
    rescue => detail
      error = Puppet::Error.new(_("failed to set mode %{mode} on %{path}: %{message}") % { mode: mode, path: resource[:path], message: detail.message })
      error.set_backtrace detail.backtrace
      raise error
    end
    :file_changed
  end

  def validate
    if [:owner, :group, :mode].any?{|p| resource[p]} and !supports_acl?(resource[:path])
      resource.fail(_("Can only manage owner, group, and mode on filesystems that support Windows ACLs, such as NTFS"))
    end
  end

  attr_reader :file
  private
  def file
    @file ||= Puppet::FileSystem.pathname(resource[:path])
  end

  def resolved_path
    path = file()
    # under POSIX, :manage means use lchown - i.e. operate on the link
    return path.to_s if resource[:links] == :manage

    # otherwise, use chown -- that will resolve the link IFF it is a link
    # otherwise it will operate on the path
    Puppet::FileSystem.symlink?(path) ? Puppet::FileSystem.readlink(path) : path.to_s
  end
end
