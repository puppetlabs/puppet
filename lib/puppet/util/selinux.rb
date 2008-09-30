# Provides utility functions to help interfaces Puppet to SELinux.
#
# Currently this is implemented via the command line tools.  At some
# point support should be added to use the new SELinux ruby bindings
# as that will be faster and more reliable then shelling out when they
# are available.  At this time (2008-09-26) these bindings aren't bundled on
# any SELinux-using distribution I know of.

module Puppet::Util::SELinux

    def selinux_support?
        FileTest.exists?("/selinux/enforce")
    end

    # Retrieve and return the full context of the file.  If we don't have
    # SELinux support or if the stat call fails then return nil.
    def get_selinux_current_context(file)
        unless selinux_support?
            return nil
        end
        context = `stat -c %C #{file}`
        if ($?.to_i >> 8) > 0
            return nil
        end
        context.chomp!
        return context
    end

    # Use the matchpathcon command, if present, to return the SELinux context
    # which the SELinux policy on the system expects the file to have.  We can
    # use this to obtain a good default context.  If the command does not
    # exist or the call fails return nil.
    #
    # Note: For this command to work a full, non-relative, filesystem path
    # should be given.
    def get_selinux_default_context(file)
        unless FileTest.executable?("/usr/sbin/matchpathcon")
            return nil
        end
        context = %x{/usr/sbin/matchpathcon #{file} 2>&1}
        if ($?.to_i >> 8) > 0
            return nil
        end
        # For a successful match, matchpathcon returns two fields separated by
        # a variable amount of whitespace.  The second field is the full context.
        context = context.split(/\s/)[1]
        return context
    end

    # Take the full SELinux context returned from the tools and parse it
    # out to the three (or four) component parts.  Supports :seluser, :selrole,
    # :seltype, and on systems with range support, :selrange.
    def parse_selinux_context(component, context)
        if context == "unlabeled"
            return nil
        end
        unless context =~ /^[a-z0-9_]+:[a-z0-9_]+:[a-z0-9_]+(:[a-z0-9_])?/
            raise Puppet::Error, "Invalid context to parse: #{context}"
        end
        bits = context.split(':')
        ret = {
            :seluser => bits[0],
            :selrole => bits[1],
            :seltype => bits[2]
        }
        if bits.length == 4
            ret[:selrange] = bits[3]
        end
        return ret[component]
    end

    # This updates the actual SELinux label on the file.  You can update
    # only a single component or update the entire context.  It is just a
    # wrapper around the chcon command.
    def set_selinux_context(file, value, component = false)
        case component
            when :seluser
                flag = "-u"
            when :selrole
                flag = "-r"
            when :seltype
                flag = "-t"
            when :selrange
                flag = "-l"
            else
                flag = ""
        end

        Puppet.debug "Running chcon #{flag} #{value} #{file}"
        retval = system("chcon #{flag} #{value} #{file}")
        unless retval
            error = Puppet::Error.new("failed to chcon %s" % [@resource[:path]])
            raise error
        end
    end

    # Since this call relies on get_selinux_default_context it also needs a
    # full non-relative path to the file.  Fortunately, that seems to be all
    # Puppet uses.  This will set the file's SELinux context to the policy's
    # default context (if any) if it differs from the context currently on
    # the file.
    def set_selinux_default_context(file)
        new_context = get_selinux_default_context(file)
        unless new_context
            return nil
        end
        cur_context = get_selinux_current_context(file)
        if new_context != cur_context
            set_selinux_context(file, new_context)
        end
        return new_context
    end
end
