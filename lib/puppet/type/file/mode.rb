# Manage file modes.  This state should support different formats
# for specification (e.g., u+rwx, or -0011), but for now only supports
# specifying the full mode.


module Puppet
  Puppet::Type.type(:file).newproperty(:mode) do
    require 'puppet/util/symbolic_file_mode'
    include Puppet::Util::SymbolicFileMode

    desc <<-'EOT'
      The desired permissions mode for the file, in symbolic or numeric
      notation. This value **must** be specified as a string; do not use
      un-quoted numbers to represent file modes.

      The `file` type uses traditional Unix permission schemes and translates
      them to equivalent permissions for systems which represent permissions
      differently, including Windows. For detailed ACL controls on Windows,
      you can leave `mode` unmanaged and use
      [the puppetlabs/acl module.](https://forge.puppetlabs.com/puppetlabs/acl)

      Numeric modes should use the standard octal notation of
      `<SETUID/SETGID/STICKY><OWNER><GROUP><OTHER>` (e.g. '0644').

      * Each of the "owner," "group," and "other" digits should be a sum of the
        permissions for that class of users, where read = 4, write = 2, and
        execute/search = 1.
      * The setuid/setgid/sticky digit is also a sum, where setuid = 4, setgid = 2,
        and sticky = 1.
      * The setuid/setgid/sticky digit is optional. If it is absent, Puppet will
        clear any existing setuid/setgid/sticky permissions. (So to make your intent
        clear, you should use at least four digits for numeric modes.)
      * When specifying numeric permissions for directories, Puppet sets the search
        permission wherever the read permission is set.

      Symbolic modes should be represented as a string of comma-separated
      permission clauses, in the form `<WHO><OP><PERM>`:

      * "Who" should be u (user), g (group), o (other), and/or a (all)
      * "Op" should be = (set exact permissions), + (add select permissions),
        or - (remove select permissions)
      * "Perm" should be one or more of:
          * r (read)
          * w (write)
          * x (execute/search)
          * t (sticky)
          * s (setuid/setgid)
          * X (execute/search if directory or if any one user can execute)
          * u (user's current permissions)
          * g (group's current permissions)
          * o (other's current permissions)

      Thus, mode `0664` could be represented symbolically as either `a=r,ug+w`
      or `ug=rw,o=r`.  However, symbolic modes are more expressive than numeric
      modes: a mode only affects the specified bits, so `mode => 'ug+w'` will
      set the user and group write bits, without affecting any other bits.

      See the manual page for GNU or BSD `chmod` for more details
      on numeric and symbolic modes.

      On Windows, permissions are translated as follows:

      * Owner and group names are mapped to Windows SIDs
      * The "other" class of users maps to the "Everyone" SID
      * The read/write/execute permissions map to the `FILE_GENERIC_READ`,
        `FILE_GENERIC_WRITE`, and `FILE_GENERIC_EXECUTE` access rights; a
        file's owner always has the `FULL_CONTROL` right
      * "Other" users can't have any permissions a file's group lacks,
        and its group can't have any permissions its owner lacks; that is, 0644
        is an acceptable mode, but 0464 is not.
    EOT

    validate do |value|
      if !value.is_a?(String)
        raise Puppet::Error, "The file mode specification must be a string, not '#{value.class.name}'"
      end
      unless value.nil? or valid_symbolic_mode?(value)
        raise Puppet::Error, "The file mode specification is invalid: #{value.inspect}"
      end
    end

    munge do |value|
      return nil if value.nil?

      unless valid_symbolic_mode?(value)
        raise Puppet::Error, "The file mode specification is invalid: #{value.inspect}"
      end

      normalize_symbolic_mode(value)
    end

    def desired_mode_from_current(desired, current)
      current = current.to_i(8) if current.is_a? String
      is_a_directory = @resource.stat && @resource.stat.directory?
      symbolic_mode_to_int(desired, current, is_a_directory)
    end

    # If we're a directory, we need to be executable for all cases
    # that are readable.  This should probably be selectable, but eh.
    def dirmask(value)
      if FileTest.directory?(resource[:path]) and value =~ /^\d+$/ then
        value = value.to_i(8)
        value |= 0100 if value & 0400 != 0
        value |= 010 if value & 040 != 0
        value |= 01 if value & 04 != 0
        value = value.to_s(8)
      end

      value
    end

    # If we're not following links and we're a link, then we just turn
    # off mode management entirely.
    def insync?(currentvalue)
      if stat = @resource.stat and stat.ftype == "link" and @resource[:links] != :follow
        self.debug "Not managing symlink mode"
        return true
      else
        return super(currentvalue)
      end
    end

    def property_matches?(current, desired)
      return false unless current
      current_bits = normalize_symbolic_mode(current)
      desired_bits = desired_mode_from_current(desired, current).to_s(8)
      current_bits == desired_bits
    end

    # Ideally, dirmask'ing could be done at munge time, but we don't know if 'ensure'
    # will eventually be a directory or something else. And unfortunately, that logic
    # depends on the ensure, source, and target properties. So rather than duplicate
    # that logic, and get it wrong, we do dirmask during retrieve, after 'ensure' has
    # been synced.
    def retrieve
      if @resource.stat
        @should &&= @should.collect { |s| self.dirmask(s) }
      end

      super
    end

    # Finally, when we sync the mode out we need to transform it; since we
    # don't have access to the calculated "desired" value here, or the
    # "current" value, only the "should" value we need to retrieve again.
    def sync
      current = @resource.stat ? @resource.stat.mode : 0644
      set(desired_mode_from_current(@should[0], current).to_s(8))
    end

    def change_to_s(old_value, desired)
      return super if desired =~ /^\d+$/

      old_bits = normalize_symbolic_mode(old_value)
      new_bits = normalize_symbolic_mode(desired_mode_from_current(desired, old_bits))
      super(old_bits, new_bits) + " (#{desired})"
    end

    def should_to_s(should_value)
      should_value.rjust(4, "0")
    end

    def is_to_s(currentvalue)
      if currentvalue == :absent
        # This can occur during audits---if a file is transitioning from
        # present to absent the mode will have a value of `:absent`.
        super
      else
        currentvalue.rjust(4, "0")
      end
    end
  end
end
