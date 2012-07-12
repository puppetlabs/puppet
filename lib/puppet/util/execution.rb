module Puppet
  require 'rbconfig'

  # A command failed to execute.
  require 'puppet/error'
  class ExecutionFailure < Puppet::Error
  end

module Util::Execution

  # Execute the provided command with STDIN connected to a pipe, yielding the
  # pipe object.  That allows data to be fed to that subprocess.
  #
  # The command can be a simple string, which is executed as-is, or an Array,
  # which is treated as a set of command arguments to pass through.#
  #
  # In all cases this is passed directly to the shell, and STDOUT and STDERR
  # are connected together during execution.
  def self.execpipe(command, failonfail = true)
    if respond_to? :debug
      debug "Executing '#{command}'"
    else
      Puppet.debug "Executing '#{command}'"
    end

    # Paste together an array with spaces.  We used to paste directly
    # together, no spaces, which made for odd invocations; the user had to
    # include whitespace between arguments.
    #
    # Having two spaces is really not a big drama, since this passes to the
    # shell anyhow, while no spaces makes for a small developer cost every
    # time this is invoked. --daniel 2012-02-13
    command_str = command.respond_to?(:join) ? command.join(' ') : command
    output = open("| #{command_str} 2>&1") do |pipe|
      yield pipe
    end

    if failonfail
      unless $CHILD_STATUS == 0
        raise ExecutionFailure, output
      end
    end

    output
  end

  def self.execfail(command, exception)
    output = execute(command)
    return output
  rescue ExecutionFailure
    raise exception, output
  end



  # Execute the desired command, and return the status and output.
  # def execute(command, options)
  # [command] an Array or String representing the command to execute. If it is
  #   an Array the first element should be the executable and the rest of the
  #   elements should be the individual arguments to that executable.
  # [options] a Hash optionally containing any of the following keys:
  #   :failonfail (default true) -- if this value is set to true, then this method will raise an error if the
  #      command is not executed successfully.
  #   :uid (default nil) -- the user id of the user that the process should be run as
  #   :gid (default nil) -- the group id of the group that the process should be run as
  #   :combine (default true) -- sets whether or not to combine stdout/stderr in the output
  #   :stdinfile (default nil) -- sets a file that can be used for stdin. Passing a string for stdin is not currently
  #      supported.
  #   :squelch (default false) -- if true, ignore stdout / stderr completely
  #   :override_locale (default true) -- by default (and if this option is set to true), we will temporarily override
  #     the user/system locale to "C" (via environment variables LANG and LC_*) while we are executing the command.
  #     This ensures that the output of the command will be formatted consistently, making it predictable for parsing.
  #     Passing in a value of false for this option will allow the command to be executed using the user/system locale.
  #   :custom_environment (default {}) -- a hash of key/value pairs to set as environment variables for the duration
  #     of the command
  def self.execute(command, options = {})
    # specifying these here rather than in the method signature to allow callers to pass in a partial
    # set of overrides without affecting the default values for options that they don't pass in
    default_options = {
        :failonfail => true,
        :uid => nil,
        :gid => nil,
        :combine => true,
        :stdinfile => nil,
        :squelch => false,
        :override_locale => true,
        :custom_environment => {},
    }

    options = default_options.merge(options)

    if command.is_a?(Array)
      command = command.flatten.map(&:to_s)
      str = command.join(" ")
    elsif command.is_a?(String)
      str = command
    end

    if respond_to? :debug
      debug "Executing '#{str}'"
    else
      Puppet.debug "Executing '#{str}'"
    end

    null_file = Puppet.features.microsoft_windows? ? 'NUL' : '/dev/null'

    stdin = File.open(options[:stdinfile] || null_file, 'r')
    stdout = options[:squelch] ? File.open(null_file, 'w') : Tempfile.new('puppet')
    stderr = options[:combine] ? stdout : File.open(null_file, 'w')

    exec_args = [command, options, stdin, stdout, stderr]

    if execution_stub = Puppet::Util::ExecutionStub.current_value
      return execution_stub.call(*exec_args)
    elsif Puppet.features.posix?
      child_pid = execute_posix(*exec_args)
      exit_status = Process.waitpid2(child_pid).last.exitstatus
    elsif Puppet.features.microsoft_windows?
      process_info = execute_windows(*exec_args)
      begin
        exit_status = Puppet::Util::Windows::Process.wait_process(process_info.process_handle)
      ensure
        Process.CloseHandle(process_info.process_handle)
        Process.CloseHandle(process_info.thread_handle)
      end
    end

    [stdin, stdout, stderr].each {|io| io.close rescue nil}

    # read output in if required
    unless options[:squelch]
      output = wait_for_output(stdout)
      Puppet.warning "Could not get output" unless output
    end

    if options[:failonfail] and exit_status != 0
      raise ExecutionFailure, "Execution of '#{str}' returned #{exit_status}: #{output}"
    end

    output
  end

  # get the path to the ruby executable (available via Config object, even if
  # it's not in the PATH... so this is slightly safer than just using
  # Puppet::Util.which)
  def self.ruby_path()
    File.join(RbConfig::CONFIG['bindir'],
              RbConfig::CONFIG['ruby_install_name'] + RbConfig::CONFIG['EXEEXT']).
      sub(/.*\s.*/m, '"\&"')
  end

  # Because some modules provide their own version of this method.
  class << self
    alias util_execute execute
  end


  # this is private method, see call to private_class_method after method definition
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
        Puppet.log_exception(detail, "Could not execute posix command: #{detail}")
        exit!(1)
      end
    end
    child_pid
  end
  private_class_method :execute_posix


  # this is private method, see call to private_class_method after method definition
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


  # this is private method, see call to private_class_method after method definition
  def self.wait_for_output(stdout)
    # Make sure the file's actually been written.  This is basically a race
    # condition, and is probably a horrible way to handle it, but, well, oh
    # well.
    # (If this method were treated as private / inaccessible from outside of this file, we shouldn't have to worry
    #  about a race condition because all of the places that we call this from are preceded by a call to "waitpid2",
    #  meaning that the processes responsible for writing the file have completed before we get here.)
    2.times do |try|
      if File.exists?(stdout.path)
        output = stdout.open.read

        begin
          stdout.close(true)
        rescue Errno::EACCES => e
          # try to unlink, though it will fail on Windows if the child process,
          # e.g. start.exe, executed another process asynchronously, as the
          # grandchild still has a handle to the tempfile
          raise e unless Puppet.features.microsoft_windows?
        end

        return output
      else
        time_to_sleep = try / 2.0
        Puppet.warning "Waiting for output; will sleep #{time_to_sleep} seconds"
        sleep(time_to_sleep)
      end
    end
    nil
  end
  private_class_method :wait_for_output




end
end
