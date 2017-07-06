# Manage SELinux context of files.
#
# This code actually manages three pieces of data in the context.
#
# [root@delenn files]# ls -dZ /
# drwxr-xr-x  root root system_u:object_r:root_t         /
#
# The context of '/' here is 'system_u:object_r:root_t'.  This is
# three separate fields:
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
# See https://www.nsa.gov/selinux/ for complete docs on SELinux.


module Puppet
  require 'puppet/util/selinux'

  class SELFileContext < Puppet::Property
    include Puppet::Util::SELinux

    def retrieve
      return :absent unless @resource.stat
      context = self.get_selinux_current_context(@resource[:path])
      parse_selinux_context(name, context)
    end

    def retrieve_default_context(property)
      if @resource[:selinux_ignore_defaults] == :true
        return nil
      end

      unless context = self.get_selinux_default_context(@resource[:path])
        return nil
      end

      property_default = self.parse_selinux_context(property, context)
      self.debug "Found #{property} default '#{property_default}' for #{@resource[:path]}" if not property_default.nil?
      property_default
    end

    def insync?(value)
      if not selinux_support?
        debug("SELinux bindings not found. Ignoring parameter.")
        true
      elsif not selinux_label_support?(@resource[:path])
        debug("SELinux not available for this filesystem. Ignoring parameter.")
        true
      else
        super
      end
    end

    def sync
      self.set_selinux_context(@resource[:path], @should, name)
      :file_changed
    end
  end

  Puppet::Type.type(:file).newparam(:selinux_ignore_defaults) do
    desc "If this is set then Puppet will not ask SELinux (via matchpathcon) to
      supply defaults for the SELinux attributes (seluser, selrole,
      seltype, and selrange). In general, you should leave this set at its
      default and only set it to true when you need Puppet to not try to fix
      SELinux labels automatically."
    newvalues(:true, :false)

    defaultto :false
  end

  Puppet::Type.type(:file).newproperty(:seluser, :parent => Puppet::SELFileContext) do
    desc "What the SELinux user component of the context of the file should be.
      Any valid SELinux user component is accepted.  For example `user_u`.
      If not specified it defaults to the value returned by matchpathcon for
      the file, if any exists.  Only valid on systems with SELinux support
      enabled."

    @event = :file_changed
    defaultto { self.retrieve_default_context(:seluser) }
  end

  Puppet::Type.type(:file).newproperty(:selrole, :parent => Puppet::SELFileContext) do
    desc "What the SELinux role component of the context of the file should be.
      Any valid SELinux role component is accepted.  For example `role_r`.
      If not specified it defaults to the value returned by matchpathcon for
      the file, if any exists.  Only valid on systems with SELinux support
      enabled."

    @event = :file_changed
    defaultto { self.retrieve_default_context(:selrole) }
  end

  Puppet::Type.type(:file).newproperty(:seltype, :parent => Puppet::SELFileContext) do
    desc "What the SELinux type component of the context of the file should be.
      Any valid SELinux type component is accepted.  For example `tmp_t`.
      If not specified it defaults to the value returned by matchpathcon for
      the file, if any exists.  Only valid on systems with SELinux support
      enabled."

    @event = :file_changed
    defaultto { self.retrieve_default_context(:seltype) }
  end

  Puppet::Type.type(:file).newproperty(:selrange, :parent => Puppet::SELFileContext) do
    desc "What the SELinux range component of the context of the file should be.
      Any valid SELinux range component is accepted.  For example `s0` or
      `SystemHigh`.  If not specified it defaults to the value returned by
      matchpathcon for the file, if any exists.  Only valid on systems with
      SELinux support enabled and that have support for MCS (Multi-Category
      Security)."

    @event = :file_changed
    defaultto { self.retrieve_default_context(:selrange) }
  end

end

