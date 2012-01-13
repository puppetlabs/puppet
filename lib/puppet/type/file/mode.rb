# Manage file modes.  This state should support different formats
# for specification (e.g., u+rwx, or -0011), but for now only supports
# specifying the full mode.
module Puppet
  Puppet::Type.type(:file).newproperty(:mode) do
    require 'puppet/util/symbolic_file_mode'
    include Puppet::Util::SymbolicFileMode

    desc "Mode the file should be.  Currently relatively limited:
      you must specify the exact mode the file should be.

      Note that when you set the mode of a directory, Puppet always
      sets the search/traverse (1) bit anywhere the read (4) bit is set.
      This is almost always what you want: read allows you to list the
      entries in a directory, and search/traverse allows you to access
      (read/write/execute) those entries.)  Because of this feature, you
      can recursively make a directory and all of the files in it
      world-readable by setting e.g.:

          file { '/some/dir':
            mode    => 644,
            recurse => true,
          }

      In this case all of the files underneath `/some/dir` will have
      mode 644, and all of the directories will have mode 755."

    validate do |value|
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
      is_a_directory = @resource.stat and @resource.stat.directory?
      symbolic_mode_to_int(desired, current, is_a_directory)
    end

    # If we're a directory, we need to be executable for all cases
    # that are readable.  This should probably be selectable, but eh.
    def dirmask(value)
      orig = value
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
      currentvalue.rjust(4, "0")
    end
  end
end
