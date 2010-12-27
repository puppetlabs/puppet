require 'puppet/provider/nameservice/directoryservice'

Puppet::Type.type(:user).provide :directoryservice, :parent => Puppet::Provider::NameService::DirectoryService do
  desc "User management using DirectoryService on OS X."

  commands :dscl => "/usr/bin/dscl"
  confine :operatingsystem => :darwin
  defaultfor :operatingsystem => :darwin

  # JJM: DirectoryService can manage passwords.
  #      This needs to be a special option to dscl though (-passwd)
  has_feature :manages_passwords

  # JJM: comment matches up with the /etc/passwd concept of an user
  options :comment, :key => "realname"
  options :password, :key => "passwd"

  autogen_defaults :home => "/var/empty", :shell => "/usr/bin/false"

  verify :gid, "GID must be an integer" do |value|
    value.is_a? Integer
  end

  verify :uid, "UID must be an integer" do |value|
    value.is_a? Integer
  end

  def autogen_comment
    @resource[:name].capitalize
  end

  # The list of all groups the user is a member of.
  # JJM: FIXME: Override this method...
  def groups
    groups = []
    groups.join(",")
  end

  # This is really lame.  We have to iterate over each
  # of the groups and add us to them.
  def groups=(groups)
    # case groups
    # when Fixnum
    #     groups = [groups.to_s]
    # when String
    #     groups = groups.split(/\s*,\s*/)
    # else
    #     raise Puppet::DevError, "got invalid groups value #{groups.class} of type #{groups}"
    # end
    # # Get just the groups we need to modify
    # diff = groups - (@is || [])
    #
    # data = {}
    # open("| #{command(:nireport)} / /groups name users") do |file|
    #     file.each do |line|
    #         name, members = line.split(/\s+/)
    #
    #         if members.nil? or members =~ /NoValue/
    #             data[name] = []
    #         else
    #             # Add each diff group's current members
    #             data[name] = members.split(/,/)
    #         end
    #     end
    # end
    #
    # user = @resource[:name]
    # data.each do |name, members|
    #     if members.include? user and groups.include? name
    #         # I'm in the group and should be
    #         next
    #     elsif members.include? user
    #         # I'm in the group and shouldn't be
    #         setuserlist(name, members - [user])
    #     elsif groups.include? name
    #         # I'm not in the group and should be
    #         setuserlist(name, members + [user])
    #     else
    #         # I'm not in the group and shouldn't be
    #         next
    #     end
    # end
  end


end
