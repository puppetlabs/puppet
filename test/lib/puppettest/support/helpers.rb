require 'puppettest'

module PuppetTest
    def nonrootuser
        Etc.passwd { |user|
            if user.uid != Puppet::SUIDManager.uid and user.uid > 0
                return user
            end
        }
    end

    def nonrootgroup
        Etc.group { |group|
            if group.gid != Puppet::SUIDManager.gid and group.gid > 0
                return group
            end
        }
    end
end

# $Id$
