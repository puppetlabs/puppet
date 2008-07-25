# Manage SELinux context of files.
#
# This code actually manages three pieces of data in the context.
#
# [root@delenn files]# ls -dZ /
# drwxr-xr-x  root root system_u:object_r:root_t         /
#
# The context of '/' here is 'system_u:object_r:root_t'.  This is
# three seperate fields:
#
# system_u is the user context
# object_r is the role context
# root_t is the type context
#
# All three of these fields are returned in a single string by the
# output of the stat command, but set individually with the chcon
# command.  This allows the user to specify a subset of the three
# values while leaving the others alone.
#
# See http://www.nsa.gov/selinux/ for complete docs on SELinux.

module Puppet
    class SELFileContext < Puppet::Property

        def retrieve
            unless @resource.stat(false)
                return :absent
            end
            context = `stat -c %C #{@resource[:path]}`
            context.chomp!
            if context == "unlabeled"
                return nil
            end
            unless context =~ /^[a-z0-9_]+:[a-z0-9_]+:[a-z0-9_]+/
                raise Puppet::Error, "Invalid output from stat: #{context}"
            end
            bits = context.split(':')
            ret = {
                :seluser => bits[0],
                :selrole => bits[1],
                :seltype => bits[2]
            }
            return ret[name]
        end

        def sync
            unless @resource.stat(false)
                stat = @resource.stat(true)
                unless stat
                    return nil
                end
            end

            flag = ''

            case name
            when :seluser
                flag = "-u"
            when :selrole
                flag = "-r"
            when :seltype
                flag = "-t"
            else
                raise Puppet::Error, "Invalid SELinux file context component: #{name}"
            end

            self.debug "Running chcon #{flag} #{@should} #{@resource[:path]}"
            retval = system("chcon #{flag} #{@should} #{@resource[:path]}")
            unless retval
                error = Puppet::Error.new("failed to chcon %s" % [@resource[:path]])
                raise error
            end
            return :file_changed
        end
    end

    Puppet.type(:file).newproperty(:seluser, :parent => Puppet::SELFileContext) do
        desc "What the SELinux User context of the file should be."

        @event = :file_changed
    end

    Puppet.type(:file).newproperty(:selrole, :parent => Puppet::SELFileContext) do
        desc "What the SELinux Role context of the file should be."

        @event = :file_changed
    end

    Puppet.type(:file).newproperty(:seltype, :parent => Puppet::SELFileContext) do
        desc "What the SELinux Type context of the file should be."

        @event = :file_changed
    end

end

