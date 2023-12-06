# frozen_string_literal: true
require 'timeout'
require_relative '../../puppet/file_system/uniquefile'

module Puppet
  require 'rbconfig'

  require_relative '../../puppet/error'
  # A command failed to execute.
  # @api public
  class ExecutionFailure < Puppet::Error
  end
end

# This module defines methods for execution of system commands. It is intended for inclusion
# in classes that needs to execute system commands.
# @api public
module Puppet::Util::Execution

  # This is the full output from a process. The object itself (a String) is the
  # stdout of the process.
  #
  # @api public
  class ProcessOutput < String
    # @return [Integer] The exit status of the process
    # @api public
    attr_reader :exitstatus

    # @api private
    def initialize(value,exitstatus)
      super(value)
      @exitstatus = exitstatus
    end
  end

  # The command can be a simple string, which is executed as-is, or an Array,
  # which is treated as a set of command arguments to pass through.
  #
  # In either case, the command is passed directly to the shell, STDOUT and
  # STDERR are connected together, and STDOUT will be streamed to the yielded
  # pipe.
  #
  # @param command [String, Array<String>] the command to execute as one string,
  #   or as parts in an array. The parts of the array are joined with one
  #   separating space between each entry when converting to the command line
  #   string to execute.
  # @param failonfail [Boolean] (true) if the execution should fail with
  #   Exception on failure or not.
  # @yield [pipe] to a block executing a subprocess
  # @yieldparam pipe [IO] the opened pipe
  # @yieldreturn [String] the output to return
  # @raise [Puppet::ExecutionFailure] if the executed child process did not
  #   exit with status == 0 and `failonfail` is `true`.
  # @return [String] a string with the output from the subprocess executed by
  #   the given block
  #
  # @see Kernel#open for `mode` values
  # @api public
  def self.execpipe(command, failonfail = true)
    # Paste together an array with spaces.  We used to paste directly
    # together, no spaces, which made for odd invocations; the user had to
    # include whitespace between arguments.
    #
    # Having two spaces is really not a big drama, since this passes to the
    # shell anyhow, while no spaces makes for a small developer cost every
    # time this is invoked. --daniel 2012-02-13
    command_str = command.respond_to?(:join) ? command.join(' ') : command

    if respond_to? :debug
      debug "Executing '#{command_str}'"
    else
      Puppet.debug { "Executing '#{command_str}'" }
    end

    # force the run of the command with
    # the user/system locale to "C" (via environment variables LANG and LC_*)
    # it enables to have non localized output for some commands and therefore
    # a predictable output
    english_env = ENV.to_hash.merge( {'LANG' => 'C', 'LC_ALL' => 'C'} )
    output = Puppet::Util.withenv(english_env) do
      # We are intentionally using 'pipe' with open to launch a process
      open("| #{command_str} 2>&1") do |pipe| # rubocop:disable Security/Open
        yield pipe
      end
    end

    if failonfail && exitstatus != 0
      raise Puppet::ExecutionFailure, output.to_s
    end

    output
  end

  def self.exitstatus
    $CHILD_STATUS.exitstatus
  end
  private_class_method :exitstatus

  # Default empty options for {execute}
  NoOptionsSpecified = {}

  # Executes the desired command, and return the status and output.
  # def execute(command, options)
  # @param command [Array<String>, String] the command to execute. If it is
  #   an Array the first element should be the executable and the rest of the
  #   elements should be the individual arguments to that executable.
  # @param options [Hash] a Hash of options
  # @option options [String] :cwd the directory from which to run the command. Raises an error if the directory does not exist.
  #   This option is only available on the agent. It cannot be used on the master, meaning it cannot be used in, for example,
  #   regular functions, hiera backends, or report processors.
  # @option options [Boolean]  :failonfail if this value is set to true, then this method will raise an error if the
  #   command is not executed successfully.
  # @option options [Integer, String] :uid (nil) the user id of the user that the process should be run as. Will be ignored if the
  #   user id matches the effective user id of the current process.
  # @option options [Integer, String] :gid (nil) the group id of the group that the process should be run as. Will be ignored if the
  #   group id matches the effective group id of the current process.
  # @option options [Boolean] :combine sets whether or not to combine stdout/stderr in the output, if false stderr output is discarded
  # @option options [String] :stdinfile (nil) sets a file that can be used for stdin. Passing a string for stdin is not currently
  #   supported.
  # @option options [Boolean] :squelch (false) if true, ignore stdout / stderr completely.
  # @option options [Boolean] :override_locale (true) by default (and if this option is set to true), we will temporarily override
  #   the user/system locale to "C" (via environment variables LANG and LC_*) while we are executing the command.
  #   This ensures that the output of the command will be formatted consistently, making it predictable for parsing.
  #   Passing in a value of false for this option will allow the command to be executed using the user/system locale.
  # @option options [Hash<{String => String}>] :custom_environment ({}) a hash of key/value pairs to set as environment variables for the duration
  #   of the command.
  # @return [Puppet::Util::Execution::ProcessOutput] output as specified by options
  # @raise [Puppet::ExecutionFailure] if the executed chiled process did not exit with status == 0 and `failonfail` is
  #   `true`.
  # @note Unfortunately, the default behavior for failonfail and combine (since
  #   0.22.4 and 0.24.7, respectively) depend on whether options are specified
  #   or not. If specified, then failonfail and combine default to false (even
  #   when the options specified are neither failonfail nor combine). If no
  #   options are specified, then failonfail and combine default to true.
  # @comment See commits efe9a833c and d32d7f30
  # @api public
  #
  def self.execute(command, options = NoOptionsSpecified)
    # specifying these here rather than in the method signature to allow callers to pass in a partial
    # set of overrides without affecting the default values for options that they don't pass in
    default_options = {
        :failonfail => NoOptionsSpecified.equal?(options),
        :uid => nil,
        :gid => nil,
        :combine => NoOptionsSpecified.equal?(options),
        :stdinfile => nil,
        :squelch => false,
        :override_locale => true,
        :custom_environment => {},
        :sensitive => false,
        :suppress_window => false,
    }

    options = default_options.merge(options)

    if command.is_a?(Array)
      command = command.flatten.map(&:to_s)
      command_str = command.join(" ")
    elsif command.is_a?(String)
      command_str = command
    end

    # do this after processing 'command' array or string
    command_str = '[redacted]' if options[:sensitive]

    user_log_s = ''.dup
    if options[:uid]
      user_log_s << " uid=#{options[:uid]}"
    end
    if options[:gid]
      user_log_s << " gid=#{options[:gid]}"
    end
    if user_log_s != ''
      user_log_s.prepend(' with')
    end

    if respond_to? :debug
      debug "Executing#{user_log_s}: '#{command_str}'"
    else
      Puppet.debug { "Executing#{user_log_s}: '#{command_str}'" }
    end

    null_file = Puppet::Util::Platform.windows? ? 'NUL' : '/dev/null'

    cwd = options[:cwd]
    if cwd && ! Puppet::FileSystem.directory?(cwd)
      raise ArgumentError, _("Working directory %{cwd} does not exist!") % { cwd: cwd }
    end

    begin
      stdin = Puppet::FileSystem.open(options[:stdinfile] || null_file, nil, 'r')
      # On Windows, continue to use the file-based approach to avoid breaking people's existing
      # manifests. If they use a script that doesn't background cleanly, such as
      # `start /b ping 127.0.0.1`, we couldn't handle it with pipes as there's no non-blocking
      # read available.
      if options[:squelch]
        stdout = Puppet::FileSystem.open(null_file, nil, 'w')
      elsif Puppet.features.posix?
        reader, stdout = IO.pipe
      else
        stdout = Puppet::FileSystem::Uniquefile.new('puppet')
      end
      stderr = options[:combine] ? stdout : Puppet::FileSystem.open(null_file, nil, 'w')

      exec_args = [command, options, stdin, stdout, stderr]
      output = ''.dup

      # We close stdin/stdout/stderr immediately after fork/exec as they're no longer needed by
      # this process. In most cases they could be closed later, but when `stdout` is the "writer"
      # pipe we must close it or we'll never reach eof on the `reader` pipe.
      execution_stub = Puppet::Util::ExecutionStub.current_value
      if execution_stub
        child_pid = execution_stub.call(*exec_args)
        [stdin, stdout, stderr].each {|io| io.close rescue nil}
        return child_pid
      elsif Puppet.features.posix?
        child_pid = nil
        begin
          child_pid = execute_posix(*exec_args)
          [stdin, stdout, stderr].each {|io| io.close rescue nil}
          if options[:squelch]
            exit_status = Process.waitpid2(child_pid).last.exitstatus
          else
            # Use non-blocking read to check for data. After each attempt,
            # check whether the child is done. This is done in case the child
            # forks and inherits stdout, as happens in `foo &`.
            # If we encounter EOF, though, then switch to a blocking wait for
            # the child; after EOF, IO.select will never block and the loop
            # below will use maximum CPU available.

            wait_flags = Process::WNOHANG
            until results = Process.waitpid2(child_pid, wait_flags) #rubocop:disable Lint/AssignmentInCondition

              # If not done, wait for data to read with a timeout
              # This timeout is selected to keep activity low while waiting on
              # a long process, while not waiting too long for the pathological
              # case where stdout is never closed.
              ready = IO.select([reader], [], [], 0.1)
              begin
                output << reader.read_nonblock(4096) if ready
              rescue Errno::EAGAIN
                retry
              rescue EOFError
                wait_flags = 0
              end
            end

            # Read any remaining data. Allow for but don't expect EOF.
            begin
              loop do
                output << reader.read_nonblock(4096)
              end
            rescue Errno::EAGAIN
              retry
            rescue EOFError
              # done reading, continue
            end

            # Force to external encoding to preserve prior behavior when reading a file.
            # Wait until after reading all data so we don't encounter corruption when
            # reading part of a multi-byte unicode character if default_external is UTF-8.
            output.force_encoding(Encoding.default_external)
            exit_status = results.last.exitstatus
          end
          child_pid = nil
        rescue Timeout::Error => e
          # NOTE: For Ruby 2.1+, an explicit Timeout::Error class has to be
          # passed to Timeout.timeout in order for there to be something for
          # this block to rescue.
          unless child_pid.nil?
            Process.kill(:TERM, child_pid)
            # Spawn a thread to reap the process if it dies.
            Thread.new { Process.waitpid(child_pid) }
          end

          raise e
        end
      elsif Puppet::Util::Platform.windows?
        process_info = execute_windows(*exec_args)
        begin
          [stdin, stderr].each {|io| io.close rescue nil}
          exit_status = Puppet::Util::Windows::Process.wait_process(process_info.process_handle)

          # read output in if required
          unless options[:squelch]
            output = wait_for_output(stdout)
            Puppet.warning _("Could not get output") unless output
          end
        ensure
          FFI::WIN32.CloseHandle(process_info.process_handle)
          FFI::WIN32.CloseHandle(process_info.thread_handle)
        end
      end

      if options[:failonfail] and exit_status != 0
        raise Puppet::ExecutionFailure, _("Execution of '%{str}' returned %{exit_status}: %{output}") % { str: command_str, exit_status: exit_status, output: output.strip }
      end
    ensure
      # Make sure all handles are closed in case an exception was thrown attempting to execute.
      [stdin, stdout, stderr].each {|io| io.close rescue nil}
      if !options[:squelch]
        # if we opened a pipe, we need to clean it up.
        reader.close if reader
        stdout.close! if Puppet::Util::Platform.windows?
      end
    end

    Puppet::Util::Execution::ProcessOutput.new(output || '', exit_status)
  end

  # Returns the path to the ruby executable (available via Config object, even if
  # it's not in the PATH... so this is slightly safer than just using Puppet::Util.which)
  # @return [String] the path to the Ruby executable
  # @api private
  #
  def self.ruby_path()
    File.join(RbConfig::CONFIG['bindir'],
              RbConfig::CONFIG['ruby_install_name'] + RbConfig::CONFIG['EXEEXT']).
      sub(/.*\s.*/m, '"\&"')
  end

  # Because some modules provide their own version of this method.
  class << self
    alias util_execute execute
  end


  # This is private method.
  # @comment see call to private_class_method after method definition
  # @api private
  #
  def self.execute_posix(command, options, stdin, stdout, stderr)
    child_pid = Puppet::Util.safe_posix_fork(stdin, stdout, stderr) do
      # We can't just call Array(command), and rely on it returning
      # things like ['foo'], when passed ['foo'], because
      # Array(command) will call command.to_a internally, which when
      # given a string can end up doing Very Bad Things(TM), such as
      # turning "/tmp/foo;\r\n /bin/echo" into ["/tmp/foo;\r\n", " /bin/echo"]
      command = [command].flatten
      Process.setsid
      begin
        # We need to chdir to our cwd before changing privileges as there's a
        # chance that the user may not have permissions to access the cwd, which
        # would cause execute_posix to fail.
        cwd = options[:cwd]
        Dir.chdir(cwd) if cwd

        Puppet::Util::SUIDManager.change_privileges(options[:uid], options[:gid], true)

        # if the caller has requested that we override locale environment variables,
        if (options[:override_locale]) then
          # loop over them and clear them
          Puppet::Util::POSIX::LOCALE_ENV_VARS.each { |name| ENV.delete(name) }
          # set LANG and LC_ALL to 'C' so that the command will have consistent, predictable output
          # it's OK to manipulate these directly rather than, e.g., via "withenv", because we are in
          # a forked process.
          ENV['LANG'] = 'C'
          ENV['LC_ALL'] = 'C'
        end

        # unset all of the user-related environment variables so that different methods of starting puppet
        # (automatic start during boot, via 'service', via /etc/init.d, etc.) won't have unexpected side
        # effects relating to user / home dir environment vars.
        # it's OK to manipulate these directly rather than, e.g., via "withenv", because we are in
        # a forked process.
        Puppet::Util::POSIX::USER_ENV_VARS.each { |name| ENV.delete(name) }

        options[:custom_environment] ||= {}
        Puppet::Util.withenv(options[:custom_environment]) do
          Kernel.exec(*command)
        end
      rescue => detail
        Puppet.log_exception(detail, _("Could not execute posix command: %{detail}") % { detail: detail })
        exit!(1)
      end
    end
    child_pid
  end
  private_class_method :execute_posix


  # This is private method.
  # @comment see call to private_class_method after method definition
  # @api private
  #
  def self.execute_windows(command, options, stdin, stdout, stderr)
    command = command.map do |part|
      part.include?(' ') ? %Q["#{part.gsub(/"/, '\"')}"] : part
    end.join(" ") if command.is_a?(Array)

    options[:custom_environment] ||= {}
    Puppet::Util.withenv(options[:custom_environment]) do
      Puppet::Util::Windows::Process.execute(command, options, stdin, stdout, stderr)
    end
  end
  private_class_method :execute_windows


  # This is private method.
  # @comment see call to private_class_method after method definition
  # @api private
  #
  def self.wait_for_output(stdout)
    # Make sure the file's actually been written.  This is basically a race
    # condition, and is probably a horrible way to handle it, but, well, oh
    # well.
    # (If this method were treated as private / inaccessible from outside of this file, we shouldn't have to worry
    #  about a race condition because all of the places that we call this from are preceded by a call to "waitpid2",
    #  meaning that the processes responsible for writing the file have completed before we get here.)
    2.times do |try|
      if Puppet::FileSystem.exist?(stdout.path)
        stdout.open
        begin
          return stdout.read
        ensure
          stdout.close
          stdout.unlink
        end
      else
        time_to_sleep = try / 2.0
        Puppet.warning _("Waiting for output; will sleep %{time_to_sleep} seconds") % { time_to_sleep: time_to_sleep }
        sleep(time_to_sleep)
      end
    end
    nil
  end
  private_class_method :wait_for_output
end
