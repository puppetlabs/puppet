# A module to collect utility functions.

module Puppet
module Util
    # Execute a block as a given user, and optionally as a group
    def self.asuser(user, group = nil)
        # FIXME This needs to allow user, group, or both to be optional.
        require 'etc'

        uid = nil
        gid = nil
        olduid = nil
        oldgid = nil

        begin
            # the groupid, if we got passed a group
            # The gid has to be changed first, because, well, otherwise we won't
            # be able to
            if group
                if group.is_a?(Integer)
                    gid = group
                else
                    obj = Puppet::Type::Group.create(
                        :name => user,
                        :check => [:gid]
                    )
                    obj.retrieve
                    gid = obj.is(:gid)
                    unless gid.is_a?(Integer)
                        raise Puppet::Error, "Could not find group %s" % group
                    end
                end

                if Process.gid != gid
                    oldgid = Process.gid
                    begin
                        Process.egid = gid
                    rescue => detail
                        raise Puppet::Error, "Could not change GID: %s" % detail
                    end
                end
            end

            if user
                # Retrieve the user id
                if user.is_a?(Integer)
                    uid = user
                else
                    obj = Puppet::Type::User.create(
                        :name => user,
                        :check => [:uid, :gid]
                    )
                    obj.retrieve
                    uid = obj.is(:uid)
                    unless uid.is_a?(Integer)
                        raise Puppet::Error, "Could not find user %s" % user
                    end
                end

                # Now change the uid
                if Process.uid != uid
                    olduid = Process.uid
                    begin
                        Process.euid = uid
                    rescue => detail
                        raise Puppet::Error, "Could not change UID: %s" % detail
                    end
                end
            end

            retval = yield
        ensure
            if olduid
                Process.euid = olduid
            end

            if oldgid
                Process.egid = oldgid
            end
        end

        return retval
    end

    # XXX this should all be done using puppet objects, not using
    # normal mkdir
    def self.recmkdir(dir,mode = 0755)
        if FileTest.exist?(dir)
            return false
        else
            tmp = dir.sub(/^\//,'')
            path = [File::SEPARATOR]
            tmp.split(File::SEPARATOR).each { |dir|
                path.push dir
                if ! FileTest.exist?(File.join(path))
                    Dir.mkdir(File.join(path), mode)
                elsif FileTest.directory?(File.join(path))
                    next
                else FileTest.exist?(File.join(path))
                    raise "Cannot create %s: basedir %s is a file" %
                        [dir, File.join(path)]
                end
            }
            return true
        end
    end
end
end

# $Id$
