Puppet::Type.type(:group).provide :gpasswd, :parent => Puppet::Type::Group::ProviderGroupadd do
  require 'set'
  require 'shellwords'

  desc <<-EOM
    Group management via `gpasswd`. This allows for local group
    management when the users exist in a remote system.
  EOM

  commands  :addmember => 'gpasswd',
            :delmember => 'gpasswd'

  has_feature :manages_members unless %w{HP-UX Solaris}.include? Facter.value(:operatingsystem)

  def addcmd
    cmd = []
    cmd << super.shelljoin

    @resource[:members] and cmd << @resource[:members].map{ |x|
      [ command(:addmember),'-a',x,@resource[:name] ].shelljoin
    }
    
    # NOTE: This will create the group but may not add some members to
    # your group if they do not exist on the system. Any member that
    # can be added will be added in an attempt to do "the right
    # thing".
    cmd.join(' && ')
  end

  def members
    if @resource[:attribute_membership] == :minimum
      if (@resource[:members] - @objectinfo.mem).empty?
        retval = @resource[:members]
      else
        retval = @resource[:members].to_set.union(@objectinfo.mem)
      end
    else
      retval = @objectinfo.mem
    end

    retval
  end

  def members=(members)
    cmd = []
    to_be_added = members.dup
    if @resource[:attribute_membership] == :minimum
      to_be_added = to_be_added.to_set.union(@objectinfo.mem)
    else
      to_be_removed = @objectinfo.mem - to_be_added
      to_be_added = to_be_added - @objectinfo.mem

      not to_be_removed.empty? and cmd << to_be_removed.map { |x|
        [ command(:addmember),'-d',x,@resource[:name] ].shelljoin
      }

    end

    not to_be_added.empty? and cmd << to_be_added.map { |x|
      [ command(:addmember),'-a',x,@resource[:name] ].shelljoin
    }

    # NOTE: This will create the group but may not add some members to
    # your group if they do not exist on the system. Any member that
    # can be added will be added in an attempt to do "the right
    # thing".
    execute(cmd.join(' && '))
  end
end
