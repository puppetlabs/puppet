# Provides utility functions to help interfaces Puppet to SELinux.
#
# Currently this is implemented via the command line tools.  At some
# point support should be added to use the new SELinux ruby bindings
# as that will be faster and more reliable then shelling out when they
# are available.  At this time (2008-09-26) these bindings aren't bundled on
# any SELinux-using distribution I know of.

require 'puppet/util'

module Puppet::Util::SELinux

    include Puppet::Util

    def selinux_support?
        FileTest.exists?("/selinux/enforce")
    end

    # Retrieve and return the full context of the file.  If we don't have
    # SELinux support or if the stat call fails then return nil.
    def get_selinux_current_context(file)
        unless selinux_support?
            return nil
        end
        context = ""
        begin
            execpipe("/usr/bin/stat -c %C #{file}") do |out|
                out.each do |line|
                    context << line
                end
            end
        rescue Puppet::ExecutionFailure
            return nil
        end
        context.chomp!
        # Handle the case that the system seems to have SELinux support but
        # stat finds unlabled files.
        if context == "(null)"
            return nil
        end
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
        unless selinux_support?
            return nil
        end
        unless FileTest.executable?("/usr/sbin/matchpathcon")
            return nil
        end
        context = ""
        begin
            execpipe("/usr/sbin/matchpathcon #{file}") do |out|
                out.each do |line|
                    context << line
                end
            end
        rescue Puppet::ExecutionFailure
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
        if context.nil? or context == "unlabeled"
            return nil
        end
        unless context =~ /^([a-z0-9_]+):([a-z0-9_]+):([a-z0-9_]+)(?::([a-zA-Z0-9:,._-]+))?/
            raise Puppet::Error, "Invalid context to parse: #{context}"
        end
        ret = {
            :seluser => $1,
            :selrole => $2,
            :seltype => $3,
            :selrange => $4,
        }
        return ret[component]
    end

    # This updates the actual SELinux label on the file.  You can update
    # only a single component or update the entire context.  It is just a
    # wrapper around the chcon command.
    def set_selinux_context(file, value, component = false)
        unless selinux_support?
            return nil
        end
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
                flag = nil
        end

        if flag.nil?
            cmd = ["/usr/bin/chcon","-h",value,file]
        else
            cmd = ["/usr/bin/chcon","-h",flag,value,file]
        end
        execute(cmd)
        return true
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
            return new_context
        end
        return nil
    end
end
