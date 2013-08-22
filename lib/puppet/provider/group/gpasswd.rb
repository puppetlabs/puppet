require 'puppet/provider/group/groupadd'

Puppet::Type.type(:group).provide :gpasswd, :parent => Puppet::Type::Group::ProviderGroupadd do
  require 'set'
  require 'shellwords'

  desc <<-EOM
    Group management via `gpasswd`. This allows for local group
    management when the users exist in a remote system.
  EOM

  # This should be enhanced as the provider can be tested on additional
  # Operating Systems
  confine :kernel => [:Linux]

  commands  :addmember => 'gpasswd',
            :delmember => 'gpasswd'

  has_feature :manages_members

  def addcmd
    cmd = []
    cmd << super.shelljoin

    if @resource[:members]
      cmd << @resource[:members].map{ |x|
        [ command(:addmember),'-a',x,@resource[:name] ].shelljoin
      }
    end

    # NOTE: This will create the group but may not add some members to
    # your group if they do not exist on the system. Any member that
    # can be added will be added in an attempt to do "the right
    # thing".
    cmd.join(' && ')
  end

  def members
    retval = @objectinfo.mem

    if @resource[:members] &&
       @resource[:auth_membership] &&
       (@resource[:members] - @objectinfo.mem).empty?
    then
        retval = @resource[:members]
    end

    retval
  end

  def members=(members)
    cmd = []
    to_be_added = members.dup
    unless @resource[:auth_membership]
      to_be_added = to_be_added.to_set.union(@objectinfo.mem)
    else
      to_be_removed = @objectinfo.mem - to_be_added
      to_be_added = to_be_added - @objectinfo.mem

      unless to_be_removed.empty?
        cmd << to_be_removed.map { |x|
          [ command(:addmember),'-d',x,@resource[:name] ].shelljoin
        }
      end
    end

    unless to_be_added.empty?
      cmd << to_be_added.map { |x|
        [ command(:addmember),'-a',x,@resource[:name] ].shelljoin
      }
    end

    # NOTE: This will create the group but may not add some members to
    # your group if they do not exist on the system. Any member that
    # can be added will be added in an attempt to do "the right
    # thing".
    cmd.each_slice(50) { |cmd_slice|
      execute(cmd_slice.join(' && '))
    }
  end
end
