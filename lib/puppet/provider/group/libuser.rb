require 'puppet/provider/nameservice/objectadd'

Puppet::Type.type(:group).provide :libuser, :parent => Puppet::Provider::NameService::ObjectAdd do
  desc "Group management via `libuser`. Available on most RedHat-based platforms."

  commands :add => "lgroupadd", :delete => "lgroupdel", :modify => "lgroupmod"

  has_feature :system_groups, :manages_members

  options :members, :flag => '-M', :method => :mem

  # TODO maybe move this closer? I'm open to suggestions
  ENV['LIBUSER_CONF'] = File.expand_path("../../../util/libuser.conf", __FILE__)

  def create
    super
    if @resource['members']
      set(:members, @resource[:members])
    end
  end

  def gid_exists?
    begin
      !!Etc.getgrgid(@resource.should(:gid))
    rescue ArgumentError
      nil
    end
  end

  def check_allow_dup
    # We have to manually check for duplicates when using libuser
    # because by default duplicates are allowed.
    if gid_exists? && !@resource.allowdupe?
      raise(Puppet::Error, _("GID %{resource} already exists, use allowdupe to force this change") % { resource: @resource.should(:gid).to_s })
    end
  end

  def addcmd
    cmd = [command(:add)]
    gid = @resource.should(:gid)
    if gid
      cmd << flag(:gid) << gid
      check_allow_dup
    end
    cmd << "-r" if @resource.system?
    cmd << @resource[:name]
    cmd
  end

  def purge_members
    modify('-m', members_to_s(members), @resource.name)
  end

  def modifycmd(param, value)
    cmd = [command(:modify)]
    if param == :members
      value = members_to_s(value)
      purge_members if @resource[:auth_membership] && !members.empty?
    end
    check_allow_dup if param == :gid
    cmd << flag(param) << value
    cmd << @resource[:name]
    cmd
  end

  def deletecmd
    [command(:delete), @resource[:name]]
  end

  def members_insync?(current, should)
    current.sort == @resource.parameter(:members).actual_should(current, should)
  end

  def members_to_s(current)
    return '' if current.nil? or !current.kind_of?(Array)
    current.join(',')
  end

  def member_valid?(user)
    begin
      !!Etc.getpwnam(user)
    rescue ArgumentError
      raise Puppet::Error, _("User %{user} does not exist") % { user: user }
    end
  end
end
