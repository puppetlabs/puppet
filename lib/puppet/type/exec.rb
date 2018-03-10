module Puppet
  Type.newtype(:exec) do
    include Puppet::Util::Execution
    require 'timeout'

    @doc = "Executes external commands.

      Any command in an `exec` resource **must** be able to run multiple times
      without causing harm --- that is, it must be *idempotent*. There are three
      main ways for an exec to be idempotent:

      * The command itself is already idempotent. (For example, `apt-get update`.)
      * The exec has an `onlyif`, `unless`, or `creates` attribute, which prevents
        Puppet from running the command unless some condition is met.
      * The exec has `refreshonly => true`, which only allows Puppet to run the
        command when some other resource is changed. (See the notes on refreshing
        below.)

      A caution: There's a widespread tendency to use collections of execs to
      manage resources that aren't covered by an existing resource type. This
      works fine for simple tasks, but once your exec pile gets complex enough
      that you really have to think to understand what's happening, you should
      consider developing a custom resource type instead, as it will be much
      more predictable and maintainable.

      **Refresh:** `exec` resources can respond to refresh events (via
      `notify`, `subscribe`, or the `~>` arrow). The refresh behavior of execs
      is non-standard, and can be affected by the `refresh` and
      `refreshonly` attributes:

      * If `refreshonly` is set to true, the exec will _only_ run when it receives an
        event. This is the most reliable way to use refresh with execs.
      * If the exec already would have run and receives an event, it will run its
        command **up to two times.** (If an `onlyif`, `unless`, or `creates` condition
        is no longer met after the first run, the second run will not occur.)
      * If the exec already would have run, has a `refresh` command, and receives an
        event, it will run its normal command, then run its `refresh` command
        (as long as any `onlyif`, `unless`, or `creates` conditions are still met
        after the normal command finishes).
      * If the exec would **not** have run (due to an `onlyif`, `unless`, or `creates`
        attribute) and receives an event, it still will not run.
      * If the exec has `noop => true`, would otherwise have run, and receives
        an event from a non-noop resource, it will run once (or run its `refresh`
        command instead, if it has one).

      In short: If there's a possibility of your exec receiving refresh events,
      it becomes doubly important to make sure the run conditions are restricted.

      **Autorequires:** If Puppet is managing an exec's cwd or the executable
      file used in an exec's command, the exec resource will autorequire those
      files. If Puppet is managing the user that an exec should run as, the
      exec resource will autorequire that user."

    # Create a new check mechanism.  It's basically just a parameter that
    # provides one extra 'check' method.
    def self.newcheck(name, options = {}, &block)
      @checks ||= {}

      check = newparam(name, options, &block)
      @checks[name] = check
    end

    def self.checks
      @checks.keys
    end

    newproperty(:returns, :array_matching => :all, :event => :executed_command) do |property|
      include Puppet::Util::Execution
      munge do |value|
        value.to_s
      end

      def event_name
        :executed_command
      end

      defaultto "0"

      attr_reader :output
      desc "The expected exit code(s).  An error will be returned if the
        executed command has some other exit code.  Defaults to 0. Can be
        specified as an array of acceptable exit codes or a single value.

        On POSIX systems, exit codes are always integers between 0 and 255.

        On Windows, **most** exit codes should be integers between 0
        and 2147483647.

        Larger exit codes on Windows can behave inconsistently across different
        tools. The Win32 APIs define exit codes as 32-bit unsigned integers, but
        both the cmd.exe shell and the .NET runtime cast them to signed
        integers. This means some tools will report negative numbers for exit
        codes above 2147483647. (For example, cmd.exe reports 4294967295 as -1.)
        Since Puppet uses the plain Win32 APIs, it will report the very large
        number instead of the negative number, which might not be what you
        expect if you got the exit code from a cmd.exe session.

        Microsoft recommends against using negative/very large exit codes, and
        you should avoid them when possible. To convert a negative exit code to
        the positive one Puppet will use, add it to 4294967296."

      # Make output a bit prettier
      def change_to_s(currentvalue, newvalue)
        _("executed successfully")
      end

      # First verify that all of our checks pass.
      def retrieve
        # We need to return :notrun to trigger evaluation; when that isn't
        # true, we *LIE* about what happened and return a "success" for the
        # value, which causes us to be treated as in_sync?, which means we
        # don't actually execute anything.  I think. --daniel 2011-03-10
        if @resource.check_all_attributes
          return :notrun
        else
          return self.should
        end
      end

      # Actually execute the command.
      def sync
        event = :executed_command
        tries = self.resource[:tries]
        try_sleep = self.resource[:try_sleep]

        begin
          tries.times do |try|
            # Only add debug messages for tries > 1 to reduce log spam.
            debug("Exec try #{try+1}/#{tries}") if tries > 1
            @output, @status = provider.run(self.resource[:command])
            break if self.should.include?(@status.exitstatus.to_s)
            if try_sleep > 0 and tries > 1
              debug("Sleeping for #{try_sleep} seconds between tries")
              sleep try_sleep
            end
          end
        rescue Timeout::Error
          self.fail Puppet::Error, _("Command exceeded timeout"), $!
        end

        if log = @resource[:logoutput]
          case log
          when :true
            log = @resource[:loglevel]
          when :on_failure
            unless self.should.include?(@status.exitstatus.to_s)
              log = @resource[:loglevel]
            else
              log = :false
            end
          end
          unless log == :false
            @output.split(/\n/).each { |line|
              self.send(log, line)
            }
          end
        end

        unless self.should.include?(@status.exitstatus.to_s)
          if @resource.parameter(:command).sensitive
            # Don't print sensitive commands in the clear
            self.fail(_("[command redacted] returned %{status} instead of one of [%{expected}]") % { status: @status.exitstatus, expected: self.should.join(",") })
          else
            self.fail(_("'%{cmd}' returned %{status} instead of one of [%{expected}]") % { cmd: self.resource[:command], status: @status.exitstatus, expected: self.should.join(",") })
          end
        end

        event
      end
    end

    newparam(:command) do
      isnamevar
      desc "The actual command to execute.  Must either be fully qualified
        or a search path for the command must be provided.  If the command
        succeeds, any output produced will be logged at the instance's
        normal log level (usually `notice`), but if the command fails
        (meaning its return code does not match the specified code) then
        any output is logged at the `err` log level."

      validate do |command|
        raise ArgumentError, _("Command must be a String, got value of class %{klass}") % { klass: command.class } unless command.is_a? String
      end
    end

    newparam(:path) do
      desc "The search path used for command execution.
        Commands must be fully qualified if no path is specified.  Paths
        can be specified as an array or as a '#{File::PATH_SEPARATOR}' separated list."

      # Support both arrays and colon-separated fields.
      def value=(*values)
        @value = values.flatten.collect { |val|
          val.split(File::PATH_SEPARATOR)
        }.flatten
      end
    end

    newparam(:user) do
      desc "The user to run the command as.  Note that if you
        use this then any error output is not currently captured.  This
        is because of a bug within Ruby.  If you are using Puppet to
        create this user, the exec will automatically require the user,
        as long as it is specified by name.

        Please note that the $HOME environment variable is not automatically set
        when using this attribute."

      validate do |user|
        if Puppet.features.microsoft_windows?
          self.fail _("Unable to execute commands as other users on Windows")
        elsif !Puppet.features.root? && resource.current_username() != user
          self.fail _("Only root can execute commands as other users")
        end
      end
    end

    newparam(:group) do
      desc "The group to run the command as.  This seems to work quite
        haphazardly on different platforms -- it is a platform issue
        not a Ruby or Puppet one, since the same variety exists when
        running commands as different users in the shell."
      # Validation is handled by the SUIDManager class.
    end

    newparam(:cwd, :parent => Puppet::Parameter::Path) do
      desc "The directory from which to run the command.  If
        this directory does not exist, the command will fail."
    end

    newparam(:logoutput) do
      desc "Whether to log command output in addition to logging the
        exit code.  Defaults to `on_failure`, which only logs the output
        when the command has an exit code that does not match any value
        specified by the `returns` attribute. As with any resource type,
        the log level can be controlled with the `loglevel` metaparameter."

      defaultto :on_failure

      newvalues(:true, :false, :on_failure)
    end

    newparam(:refresh) do
      desc "An alternate command to run when the `exec` receives a refresh event
        from another resource. By default, Puppet runs the main command again.
        For more details, see the notes about refresh behavior above, in the
        description for this resource type.

        Note that this alternate command runs with the same `provider`, `path`,
        `user`, and `group` as the main command. If the `path` isn't set, you
        must fully qualify the command's name."

      validate do |command|
        provider.validatecmd(command)
      end
    end

    newparam(:environment) do
      desc "An array of any additional environment variables you want to set for a
        command, such as `[ 'HOME=/root', 'MAIL=root@example.com']`.
        Note that if you use this to set PATH, it will override the `path`
        attribute. Multiple environment variables should be specified as an
        array."

      validate do |values|
        values = [values] unless values.is_a? Array
        values.each do |value|
          unless value =~ /\w+=/
            raise ArgumentError, _("Invalid environment setting '%{value}'") % { value: value }
          end
        end
      end
    end

    newparam(:umask, :required_feature => :umask) do
      desc "Sets the umask to be used while executing this command"

      munge do |value|
        if value =~ /^0?[0-7]{1,4}$/
          return value.to_i(8)
        else
          raise Puppet::Error, _("The umask specification is invalid: %{value}") % { value: value.inspect }
        end
      end
    end

    newparam(:timeout) do
      desc "The maximum time the command should take.  If the command takes
        longer than the timeout, the command is considered to have failed
        and will be stopped. The timeout is specified in seconds. The default
        timeout is 300 seconds and you can set it to 0 to disable the timeout."

      munge do |value|
        value = value.shift if value.is_a?(Array)
        begin
          value = Float(value)
        rescue ArgumentError
          raise ArgumentError, _("The timeout must be a number."), $!.backtrace
        end
        [value, 0.0].max
      end

      defaultto 300
    end

    newparam(:tries) do
      desc "The number of times execution of the command should be tried.
        Defaults to '1'. This many attempts will be made to execute
        the command until an acceptable return code is returned.
        Note that the timeout parameter applies to each try rather than
        to the complete set of tries."

      munge do |value|
        if value.is_a?(String)
          unless value =~ /^[\d]+$/
            raise ArgumentError, _("Tries must be an integer")
          end
          value = Integer(value)
        end
        raise ArgumentError, _("Tries must be an integer >= 1") if value < 1
        value
      end

      defaultto 1
    end

    newparam(:try_sleep) do
      desc "The time to sleep in seconds between 'tries'."

      munge do |value|
        if value.is_a?(String)
          unless value =~ /^[-\d.]+$/
            raise ArgumentError, _("try_sleep must be a number")
          end
          value = Float(value)
        end
        raise ArgumentError, _("try_sleep cannot be a negative number") if value < 0
        value
      end

      defaultto 0
    end


    newcheck(:refreshonly) do
      desc <<-'EOT'
        The command should only be run as a
        refresh mechanism for when a dependent object is changed.  It only
        makes sense to use this option when this command depends on some
        other object; it is useful for triggering an action:

            # Pull down the main aliases file
            file { '/etc/aliases':
              source => 'puppet://server/module/aliases',
            }

            # Rebuild the database, but only when the file changes
            exec { newaliases:
              path        => ['/usr/bin', '/usr/sbin'],
              subscribe   => File['/etc/aliases'],
              refreshonly => true,
            }

        Note that only `subscribe` and `notify` can trigger actions, not `require`,
        so it only makes sense to use `refreshonly` with `subscribe` or `notify`.
      EOT

      newvalues(:true, :false)

      # We always fail this test, because we're only supposed to run
      # on refresh.
      def check(value)
        # We have to invert the values.
        if value == :true
          false
        else
          true
        end
      end
    end

    newcheck(:creates, :parent => Puppet::Parameter::Path) do
      desc <<-'EOT'
        A file to look for before running the command. The command will
        only run if the file **doesn't exist.**

        This parameter doesn't cause Puppet to create a file; it is only
        useful if **the command itself** creates a file.

            exec { 'tar -xf /Volumes/nfs02/important.tar':
              cwd     => '/var/tmp',
              creates => '/var/tmp/myfile',
              path    => ['/usr/bin', '/usr/sbin',],
            }

        In this example, `myfile` is assumed to be a file inside
        `important.tar`. If it is ever deleted, the exec will bring it
        back by re-extracting the tarball. If `important.tar` does **not**
        actually contain `myfile`, the exec will keep running every time
        Puppet runs.
      EOT

      accept_arrays

      # If the file exists, return false (i.e., don't run the command),
      # else return true
      def check(value)
        ! Puppet::FileSystem.exist?(value)
      end
    end

    newcheck(:unless) do
      desc <<-'EOT'
        A test command that checks the state of the target system and restricts
        when the `exec` can run. If present, Puppet runs this test command
        first, then runs the main command unless the test has an exit code of 0
        (success). For example:

            exec { '/bin/echo root >> /usr/lib/cron/cron.allow':
              path   => '/usr/bin:/usr/sbin:/bin',
              unless => 'grep root /usr/lib/cron/cron.allow 2>/dev/null',
            }

        This would add `root` to the cron.allow file (on Solaris) unless
        `grep` determines it's already there.

        Note that this test command runs with the same `provider`, `path`,
        `user`, and `group` as the main command. If the `path` isn't set, you
        must fully qualify the command's name.

        This parameter can also take an array of commands. For example:

            unless => ['test -f /tmp/file1', 'test -f /tmp/file2'],

        This `exec` would only run if every command in the array has a
        non-zero exit code.
      EOT

      validate do |cmds|
        cmds = [cmds] unless cmds.is_a? Array

        cmds.each do |command|
          provider.validatecmd(command)
        end
      end

      # Return true if the command does not return 0.
      def check(value)
        begin
          output, status = provider.run(value, true)
        rescue Timeout::Error
          err _("Check %{value} exceeded timeout") % { value: value.inspect }
          return false
        end

        output.split(/\n/).each { |line|
          self.debug(line)
        }

        status.exitstatus != 0
      end
    end

    newcheck(:onlyif) do
      desc <<-'EOT'
        A test command that checks the state of the target system and restricts
        when the `exec` can run. If present, Puppet runs this test command
        first, and only runs the main command if the test has an exit code of 0
        (success). For example:

            exec { 'logrotate':
              path     => '/usr/bin:/usr/sbin:/bin',
              provider => shell,
              onlyif   => 'test `du /var/log/messages | cut -f1` -gt 100000',
            }

        This would run `logrotate` only if that test returns true.

        Note that this test command runs with the same `provider`, `path`,
        `user`, and `group` as the main command. If the `path` isn't set, you
        must fully qualify the command's name.

        This parameter can also take an array of commands. For example:

            onlyif => ['test -f /tmp/file1', 'test -f /tmp/file2'],

        This `exec` would only run if every command in the array has an
        exit code of 0 (success).
      EOT

      validate do |cmds|
        cmds = [cmds] unless cmds.is_a? Array

        cmds.each do |command|
          provider.validatecmd(command)
        end
      end

      # Return true if the command returns 0.
      def check(value)
        begin
          output, status = provider.run(value, true)
        rescue Timeout::Error
          err _("Check %{value} exceeded timeout") % { value: value.inspect }
          return false
        end

        output.split(/\n/).each { |line|
          self.debug(line)
        }

        status.exitstatus == 0
      end
    end

    # Exec names are not isomorphic with the objects.
    @isomorphic = false

    validate do
      provider.validatecmd(self[:command])
    end

    # FIXME exec should autorequire any exec that 'creates' our cwd
    autorequire(:file) do
      reqs = []

      # Stick the cwd in there if we have it
      reqs << self[:cwd] if self[:cwd]

      file_regex = Puppet.features.microsoft_windows? ? %r{^([a-zA-Z]:[\\/]\S+)} : %r{^(/\S+)}

      self[:command].scan(file_regex) { |str|
        reqs << str
      }

      self[:command].scan(/^"([^"]+)"/) { |str|
        reqs << str
      }

      [:onlyif, :unless].each { |param|
        next unless tmp = self[param]

        tmp = [tmp] unless tmp.is_a? Array

        tmp.each do |line|
          # And search the command line for files, adding any we
          # find.  This will also catch the command itself if it's
          # fully qualified.  It might not be a bad idea to add
          # unqualified files, but, well, that's a bit more annoying
          # to do.
          reqs += line.scan(file_regex)
        end
      }

      # For some reason, the += isn't causing a flattening
      reqs.flatten!

      reqs
    end

    autorequire(:user) do
      # Autorequire users if they are specified by name
      if user = self[:user] and user !~ /^\d+$/
        user
      end
    end

    def self.instances
      []
    end

    # Verify that we pass all of the checks.  The argument determines whether
    # we skip the :refreshonly check, which is necessary because we now check
    # within refresh
    def check_all_attributes(refreshing = false)
      self.class.checks.each { |check|
        next if refreshing and check == :refreshonly
        if @parameters.include?(check)
          val = @parameters[check].value
          val = [val] unless val.is_a? Array
          val.each do |value|
            return false unless @parameters[check].check(value)
          end
        end
      }

      true
    end

    def output
      if self.property(:returns).nil?
        return nil
      else
        return self.property(:returns).output
      end
    end

    # Run the command, or optionally run a separately-specified command.
    def refresh
      if self.check_all_attributes(true)
        if cmd = self[:refresh]
          provider.run(cmd)
        else
          self.property(:returns).sync
        end
      end
    end

    def current_username
      Etc.getpwuid(Process.uid).name
    end

    private
    def set_sensitive_parameters(sensitive_parameters)
      # Respect sensitive commands
      if sensitive_parameters.include?(:command)
        sensitive_parameters.delete(:command)
        parameter(:command).sensitive = true
      end
      super(sensitive_parameters)
    end
  end
end
