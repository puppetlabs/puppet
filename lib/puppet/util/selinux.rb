# Provides utility functions to help interface Puppet to SELinux.
#
# This requires the very new SELinux Ruby bindings.  These bindings closely
# mirror the SELinux C library interface.
#
# Support for the command line tools is not provided because the performance
# was abysmal.  At this time (2008-11-02) the only distribution providing
# these Ruby SELinux bindings which I am aware of is Fedora (in libselinux-ruby).

Puppet.features.selinux? # check, but continue even if it's not

require 'pathname'

module Puppet::Util::SELinux

  def selinux_support?
    return false unless defined?(Selinux)
    if Selinux.is_selinux_enabled == 1
      return true
    end
    false
  end

  # Retrieve and return the full context of the file.  If we don't have
  # SELinux support or if the SELinux call fails then return nil.
  def get_selinux_current_context(file)
    return nil unless selinux_support?
    retval = Selinux.lgetfilecon(file)
    if retval == -1
      return nil
    end
    retval[1]
  end

  # Retrieve and return the default context of the file.  If we don't have
  # SELinux support or if the SELinux call fails to file a default then return nil.
  def get_selinux_default_context(file)
    return nil unless selinux_support?
    # If the filesystem has no support for SELinux labels, return a default of nil
    # instead of what matchpathcon would return
    return nil unless selinux_label_support?(file)
    # If the file exists we should pass the mode to matchpathcon for the most specific
    # matching.  If not, we can pass a mode of 0.
    begin
      filestat = file_lstat(file)
      mode = filestat.mode
    rescue Errno::EACCES, Errno::ENOENT
      mode = 0
    end

    retval = Selinux.matchpathcon(file, mode)
    if retval == -1
      return nil
    end
    retval[1]
  end

  # Take the full SELinux context returned from the tools and parse it
  # out to the three (or four) component parts.  Supports :seluser, :selrole,
  # :seltype, and on systems with range support, :selrange.
  def parse_selinux_context(component, context)
    if context.nil? or context == "unlabeled"
      return nil
    end
    unless context =~ /^([^\s:]+):([^\s:]+):([^\s:]+)(?::([\sa-zA-Z0-9:,._-]+))?$/
      raise Puppet::Error, "Invalid context to parse: #{context}"
    end
    ret = {
      :seluser => $1,
      :selrole => $2,
      :seltype => $3,
      :selrange => $4,
    }
    ret[component]
  end

  # This updates the actual SELinux label on the file.  You can update
  # only a single component or update the entire context.
  # The caveat is that since setting a partial context makes no sense the
  # file has to already exist.  Puppet (via the File resource) will always
  # just try to set components, even if all values are specified by the manifest.
  # I believe that the OS should always provide at least a fall-through context
  # though on any well-running system.
  def set_selinux_context(file, value, component = false)
    return nil unless selinux_support? && selinux_label_support?(file)

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
          raise ArgumentError, "set_selinux_context component must be one of :seluser, :selrole, :seltype, or :selrange"
      end
      context = context.join(':')
    else
      context = value
    end

    retval = Selinux.lsetfilecon(file, context)
    if retval == 0
      return true
    else
      Puppet.warning "Failed to set SELinux context #{context} on #{file}"
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
    return nil unless new_context
    cur_context = get_selinux_current_context(file)
    if new_context != cur_context
      set_selinux_context(file, new_context)
      return new_context
    end
    nil
  end

  ########################################################################
  # Internal helper methods from here on in, kids.  Don't fiddle.
  private

  # Check filesystem a path resides on for SELinux support against
  # whitelist of known-good filesystems.
  # Returns true if the filesystem can support SELinux labels and
  # false if not.
  def selinux_label_support?(file)
    fstype = find_fs(file)
    return false if fstype.nil?
    filesystems = ['ext2', 'ext3', 'ext4', 'gfs', 'gfs2', 'xfs', 'jfs', 'btrfs']
    filesystems.include?(fstype)
  end

  # Internal helper function to read and parse /proc/mounts
  def read_mounts
    mounts = ""
    begin
      if File.method_defined? "read_nonblock"
        # If possible we use read_nonblock in a loop rather than read to work-
        # a linux kernel bug.  See ticket #1963 for details.
        mountfh = File.open("/proc/mounts")
        mounts += mountfh.read_nonblock(1024) while true
      else
        # Otherwise we shell out and let cat do it for us
        mountfh = IO.popen("/bin/cat /proc/mounts")
        mounts = mountfh.read
      end
    rescue EOFError
      # that's expected
    rescue
      return nil
    ensure
      mountfh.close if mountfh
    end

    mntpoint = {}

    # Read all entries in /proc/mounts.  The second column is the
    # mountpoint and the third column is the filesystem type.
    # We skip rootfs because it is always mounted at /
    mounts.each_line do |line|
      params = line.split(' ')
      next if params[2] == 'rootfs'
      mntpoint[params[1]] = params[2]
    end
    mntpoint
  end

  # Internal helper function to return which type of filesystem a given file
  # path resides on
  def find_fs(path)
    return nil unless mounts = read_mounts

    # cleanpath eliminates useless parts of the path (like '.', or '..', or
    # multiple slashes), without touching the filesystem, and without
    # following symbolic links.  This gives the right (logical) tree to follow
    # while we try and figure out what file-system the target lives on.
    path = Pathname(path).cleanpath
    unless path.absolute?
      raise Puppet::DevError, "got a relative path in SELinux find_fs: #{path}"
    end

    # Now, walk up the tree until we find a match for that path in the hash.
    path.ascend do |segment|
      return mounts[segment.to_s] if mounts.has_key?(segment.to_s)
    end

    # Should never be reached...
    return mounts['/']
  end

  ##
  # file_lstat is an internal, private method to allow precise stubbing and
  # mocking without affecting the rest of the system.
  #
  # @return [File::Stat] File.lstat result
  def file_lstat(path)
    Puppet::FileSystem.lstat(path)
  end
  private :file_lstat
end
