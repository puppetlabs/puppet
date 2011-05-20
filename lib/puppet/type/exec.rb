module Puppet
  newtype(:exec) do
    include Puppet::Util::Execution
    require 'timeout'

    @doc = "Executes external commands.  It is critical that all commands
      executed using this mechanism can be run multiple times without
      harm, i.e., they are *idempotent*.  One useful way to create idempotent
      commands is to use the checks like `creates` to avoid running the
      command unless some condition is met.

      Note that you can restrict an `exec` to only run when it receives
      events by using the `refreshonly` parameter; this is a useful way to
      have your configuration respond to events with arbitrary commands.

      Note also that if an `exec` receives an event from another resource,
      it will get executed again (or execute the command specified in `refresh`, if there is one).

      There is a strong tendency to use `exec` to do whatever work Puppet
      can't already do; while this is obviously acceptable (and unavoidable)
      in the short term, it is highly recommended to migrate work from `exec`
      to native Puppet types as quickly as possible.  If you find that
      you are doing a lot of work with `exec`, please at least notify
      us at Puppet Labs what you are doing, and hopefully we can work with
      you to get a native resource type for the work you are doing.

      **Autorequires:** If Puppet is managing an exec's cwd or the executable file used in an exec's command, the exec resource will autorequire those files. If Puppet is managing the user that an exec should run as, the exec resource will autorequire that user."

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
      desc "The expected return code(s).  An error will be returned if the
        executed command returns something else.  Defaults to 0. Can be
        specified as an array of acceptable return codes or a single value."

      # Make output a bit prettier
      def change_to_s(currentvalue, newvalue)
        "executed successfully"
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
        olddir = nil

        # We need a dir to change to, even if it's just the cwd
        dir = self.resource[:cwd] || Dir.pwd

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
          self.fail "Command exceeded timeout" % value.inspect
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
          self.fail("#{self.resource[:command]} returned #{@status.exitstatus} instead of one of [#{self.should.join(",")}]")
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
    end

    newparam(:path) do
      desc "The search path used for command execution.
        Commands must be fully qualified if no path is specified.  Paths
        can be specified as an array or as a colon separated list."

      # Support both arrays and colon-separated fields.
      def value=(*values)
        @value = values.flatten.collect { |val|
          if val =~ /;/ # recognize semi-colon separated paths
            val.split(";")
          elsif val =~ /^\w:[^:]*$/ # heuristic to avoid splitting a driveletter away
            val
          else
            val.split(":")
          end
        }.flatten
      end
    end

    newparam(:user) do
      desc "The user to run the command as.  Note that if you
        use this then any error output is not currently captured.  This
        is because of a bug within Ruby.  If you are using Puppet to
        create this user, the exec will automatically require the user,
        as long as it is specified by name."

      # Most validation is handled by the SUIDManager class.
      validate do |user|
        self.fail "Only root can execute commands as other users" unless Puppet.features.root?
      end
    end

    newparam(:group) do
      desc "The group to run the command as.  This seems to work quite
        haphazardly on different platforms -- it is a platform issue
        not a Ruby or Puppet one, since the same variety exists when
        running commnands as different users in the shell."
      # Validation is handled by the SUIDManager class.
    end

    newparam(:cwd, :parent => Puppet::Parameter::Path) do
      desc "The directory from which to run the command.  If
        this directory does not exist, the command will fail."
    end

    newparam(:logoutput) do
      desc "Whether to log output.  Defaults to logging output at the
        loglevel for the `exec` resource. Use *on_failure* to only
        log the output when the command reports an error.  Values are
        **true**, *false*, *on_failure*, and any legal log level."

      newvalues(:true, :false, :on_failure)
    end

    newparam(:refresh) do
      desc "How to refresh this command.  By default, the exec is just
        called again when it receives an event from another resource,
        but this parameter allows you to define a different command
        for refreshing."

      validate do |command|
        provider.validatecmd(command)
      end
    end

    newparam(:environment) do
      desc "Any additional environment variables you want to set for a
        command.  Note that if you use this to set PATH, it will override
        the `path` attribute.  Multiple environment variables should be
        specified as an array."

      validate do |values|
        values = [values] unless values.is_a? Array
        values.each do |value|
          unless value =~ /\w+=/
            raise ArgumentError, "Invalid environment setting '#{value}'"
          end
        end
      end
    end

    newparam(:timeout) do
      desc "The maximum time the command should take.  If the command takes
        longer than the timeout, the command is considered to have failed
        and will be stopped.  Use 0 to disable the timeout.
        The time is specified in seconds."

      munge do |value|
        value = value.shift if value.is_a?(Array)
        begin
          value = Float(value)
        rescue ArgumentError => e
          raise ArgumentError, "The timeout must be a number."
        end
        [value, 0.0].max
      end

      defaultto 300
    end

    newparam(:tries) do
      desc "The number of times execution of the command should be tried.
        Defaults to '1'. This many attempts will be made to execute
        the command until an acceptable return code is returned.
        Note that the timeout paramater applies to each try rather than
        to the complete set of tries."

      munge do |value|
        if value.is_a?(String)
          unless value =~ /^[\d]+$/
            raise ArgumentError, "Tries must be an integer"
          end
          value = Integer(value)
        end
        raise ArgumentError, "Tries must be an integer >= 1" if value < 1
        value
      end

      defaultto 1
    end

    newparam(:try_sleep) do
      desc "The time to sleep in seconds between 'tries'."

      munge do |value|
        if value.is_a?(String)
          unless value =~ /^[-\d.]+$/
            raise ArgumentError, "try_sleep must be a number"
          end
          value = Float(value)
        end
        raise ArgumentError, "try_sleep cannot be a negative number" if value < 0
        value
      end

      defaultto 0
    end


    newcheck(:refreshonly) do
      desc "The command should only be run as a
        refresh mechanism for when a dependent object is changed.  It only
        makes sense to use this option when this command depends on some
        other object; it is useful for triggering an action:

            # Pull down the main aliases file
            file { \"/etc/aliases\":
              source => \"puppet://server/module/aliases\"
            }

            # Rebuild the database, but only when the file changes
            exec { newaliases:
              path => [\"/usr/bin\", \"/usr/sbin\"],
              subscribe => File[\"/etc/aliases\"],
              refreshonly => true
            }

        Note that only `subscribe` and `notify` can trigger actions, not `require`,
        so it only makes sense to use `refreshonly` with `subscribe` or `notify`."

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
      desc "A file that this command creates.  If this
        parameter is provided, then the command will only be run
        if the specified file does not exist:

            exec { \"tar xf /my/tar/file.tar\":
              cwd => \"/var/tmp\",
              creates => \"/var/tmp/myfile\",
              path => [\"/usr/bin\", \"/usr/sbin\"]
            }

        "

      accept_arrays

      # If the file exists, return false (i.e., don't run the command),
      # else return true
      def check(value)
        ! FileTest.exists?(value)
      end
    end

    newcheck(:unless) do
      desc "If this parameter is set, then this `exec` will run unless
        the command returns 0.  For example:

            exec { \"/bin/echo root >> /usr/lib/cron/cron.allow\":
              path => \"/usr/bin:/usr/sbin:/bin\",
              unless => \"grep root /usr/lib/cron/cron.allow 2>/dev/null\"
            }

        This would add `root` to the cron.allow file (on Solaris) unless
        `grep` determines it's already there.

        Note that this command follows the same rules as the main command,
        which is to say that it must be fully qualified if the path is not set.
        "

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
          err "Check #{value.inspect} exceeded timeout"
          return false
        end

        status.exitstatus != 0
      end
    end

    newcheck(:onlyif) do
      desc "If this parameter is set, then this `exec` will only run if
        the command returns 0.  For example:

            exec { \"logrotate\":
              path => \"/usr/bin:/usr/sbin:/bin\",
              onlyif => \"test `du /var/log/messages | cut -f1` -gt 100000\"
            }

        This would run `logrotate` only if that test returned true.

        Note that this command follows the same rules as the main command,
        which is to say that it must be fully qualified if the path is not set.

        Also note that onlyif can take an array as its value, e.g.:

            onlyif => [\"test -f /tmp/file1\", \"test -f /tmp/file2\"]

        This will only run the exec if /all/ conditions in the array return true.
        "

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
          err "Check #{value.inspect} exceeded timeout"
          return false
        end

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

      self[:command].scan(/^(#{File::SEPARATOR}\S+)/) { |str|
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
          reqs += line.scan(%r{(#{File::SEPARATOR}\S+)})
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
  end
end
