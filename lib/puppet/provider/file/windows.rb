Puppet::Type.type(:file).provide :windows do
  desc "Uses Microsoft Windows functionality to manage file ownership and permissions."

  confine 'os.name' => :windows
  has_feature :manages_symlinks if Puppet.features.manages_symlinks?

  include Puppet::Util::Warnings

  if Puppet::Util::Platform.windows?
    require_relative '../../../puppet/util/windows'
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
      managing_owner = !resource[:owner].nil?
      managing_group = !resource[:group].nil?
      set_mode(value.to_i(8), resource[:path], true, managing_owner, managing_group)
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

  # munge the windows group permissions if the user or group are set to SYSTEM
  #
  # when SYSTEM user is the group or user and the resoure is not managing them then treat
  # the resource as insync if System has FullControl access.
  #
  # @param [String] current - the current mode returned by the resource
  # @param [String] should  - what the mode should be
  #
  # @return [String, nil] munged mode or nil if the resource should be out of sync
  def munge_windows_system_group(current, should)
    [
      {
        'type'        => 'group',
        'resource'    => resource[:group],
        'set_to_user' => group,
        'fullcontrol' => "070".to_i(8),
        'remove_mask' => "707".to_i(8),
        'should_mask' => (should[0].to_i(8) & "070".to_i(8)),
      },
      {
        'type'        => 'owner',
        'resource'    => resource[:owner],
        'set_to_user' => owner,
        'fullcontrol' => "700".to_i(8),
        'remove_mask' => "077".to_i(8),
        'should_mask' => (should[0].to_i(8) & "700".to_i(8)),
      }
    ].each do |mode_part|
      if mode_part['resource'].nil? && (mode_part['set_to_user'] == Puppet::Util::Windows::SID::LocalSystem)
        if (current.to_i(8) & mode_part['fullcontrol']) == mode_part['fullcontrol']
          # Since the group is LocalSystem, and the permissions are FullControl,
          # replace the value returned with the value expected. This will treat
          # this specific situation as "insync"
          current = ( (current.to_i(8) & mode_part['remove_mask']) | mode_part['should_mask'] ).to_s(8).rjust(4, '0')
        else
          # If the SYSTEM account does _not_ have FullControl in this scenario, we should
          # force the resource out of sync no matter what.
          #TRANSLATORS 'SYSTEM' is a Windows name and should not be translated
          Puppet.debug { _("%{resource_name}: %{mode_part_type} set to SYSTEM. SYSTEM permissions cannot be set below FullControl ('7')") % { resource_name: resource[:name], mode_part_type: mode_part['type']} }
          return nil
        end
      end
    end
    current
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
