# Provides utility functions to help interfaces Puppet to SELinux.
#
# This requires the very new SELinux Ruby bindings.  These bindings closely
# mirror the SELinux C library interface.
#
# Support for the command line tools is not provided because the performance
# was abysmal.  At this time (2008-11-02) the only distribution providing
# these Ruby SELinux bindings which I am aware of is Fedora (in libselinux-ruby).

begin
    require 'selinux'
rescue LoadError
    # Nothing
end

module Puppet::Util::SELinux

    def selinux_support?
        unless defined? Selinux
            return false
        end
        if Selinux.is_selinux_enabled == 1
            return true
        end
        return false
    end

    # Retrieve and return the full context of the file.  If we don't have
    # SELinux support or if the SELinux call fails then return nil.
    def get_selinux_current_context(file)
        unless selinux_support?
            return nil
        end
        retval = Selinux.lgetfilecon(file)
        if retval == -1
            return nil
        end
        return retval[1]
    end

    # Retrieve and return the default context of the file.  If we don't have
    # SELinux support or if the SELinux call fails to file a default then return nil.
    def get_selinux_default_context(file)
        unless selinux_support?
            return nil
        end
        filestat = File.lstat(file)
        retval = Selinux.matchpathcon(file, filestat.mode)
        if retval == -1
            return nil
        end
        return retval[1]
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
    # only a single component or update the entire context.
    # The caveat is that since setting a partial context makes no sense the
    # file has to already exist.  Puppet (via the File resource) will always
    # just try to set components, even if all values are specified by the manifest.
    # I believe that the OS should always provide at least a fall-through context
    # though on any well-running system.
    def set_selinux_context(file, value, component = false)
        unless selinux_support?
            return nil
        end

        if component
            # Must first get existing context to replace a single component
            context = Selinux.lgetfilecon(file)[1]
            if context == -1
                # We can't set partial context components when no context exists
                # unless/until we can find a way to make Puppet call this method
                # once for all selinux file label attributes.
                Puppet.warning "Can't set SELinux context on file unless the file already has some kind of context"
                return nil
            end
            context = context.split(':')
            case component
                when :seluser
                    context[0] = value
                when :selrole
                    context[1] = value
                when :seltype
                    context[2] = value
                when :selrange
                    context[3] = value
                else
                    raise ArguementError, "set_selinux_context component must be one of :seluser, :selrole, :seltype, or :selrange"
            end
            context = context.join(':')
        else
            context = value
        end
       
        retval = Selinux.lsetfilecon(file, context)
        if retval == 0
            return true
        else
            Puppet.warning "Failed to set SELinux context %s on %s" % [context, file]
            return false
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
            return new_context
        end
        return nil
    end
end
