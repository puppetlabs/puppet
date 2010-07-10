require 'puppettest'

module PuppetTest
  # NOTE: currently both of these will produce bogus results on Darwin due to the wonderful
  # UID of nobody.
  def nonrootuser
    Etc.passwd { |user|
      return user if user.uid != Puppet::Util::SUIDManager.uid and user.uid > 0 and user.uid < 255
    }
  end

  def nonrootgroup
    Etc.group { |group|
      return group if group.gid != Puppet::Util::SUIDManager.gid and group.gid > 0 and group.gid < 255
    }
  end
end

