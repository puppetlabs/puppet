require 'puppettest'

module PuppetTest
    # NOTE: currently both of these will produce bogus results on Darwin due to the wonderful
    # UID of nobody.
    def nonrootuser
        Etc.passwd { |user|
            if user.uid != Puppet::Util::SUIDManager.uid and user.uid > 0 and user.uid < 255
                return user
            end
        }
    end

    def nonrootgroup
        Etc.group { |group|
            if group.gid != Puppet::Util::SUIDManager.gid and group.gid > 0 and group.gid < 255
                return group
            end
        }
    end
end

