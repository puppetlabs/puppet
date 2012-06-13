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
    elsif Puppet.features.jruby?
      exit_status = execute_jruby(*exec_args)
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

  def self.execute_jruby(command, option, stdin, stdout, stderr)
    [:uid, :gid].each do |name|
      if option[name]
        raise "execute_jruby: unsupported option #{name} => #{option[name].inspect}"
      end
    end

    # JRuby 1.6.7, I hate your awesomely limited support for child process
    # execution.  So many things that would be good, and so few that actually
    # work in a sane fashion.  Makes my life harder than it would otherwise
    # be, which annoys me.
    #
    # In this case, Open3 is incomplete, and doesn't support environment
    # magic, so we are forced to open-code the damn thing ourselves.
    #
    # So is Process.spawn.  So, in fact, is every possible path I could follow
    # to get this working.  Which is bloody awesome.  Time to get back to Java
    # and do this the native way, I suppose.

    # Reprocess the command, emulate some horrific API along the way.  Various
    # code (like the code that obtains the catalog version from an external
    # command) depends on this being true: if you submit a single string in an
    # array containing a command and argument, we split it up and execute the
    # command as expected. --daniel 2012-06-15
    if command.is_a?(Array) and command.length == 1
      command = command.first
    end

    if command.is_a?(String)
      # We end up needing to emulate the Kernel.exec method here, which treats
      # a single string as an invitation to run it through the shell.
      command = ['/bin/sh', '-c', command]
    end

    pb = java.lang.ProcessBuilder.new(command)

    # The Java ProcessBuilder doesn't see changes to the Ruby ENV hash, so we
    # have to manually sync the two of them. Fun times.
    env = pb.environment
    env.clear
    ENV.each {|name, value| env.put(name, value) }

    Puppet::Util::POSIX::USER_ENV_VARS.each {|name| env.remove(name) }

    if option[:override_locale]
      Puppet::Util::POSIX::LOCALE_ENV_VARS.each {|name| env.remove(name.to_s) }
      env.put('LANG', 'C')
      env.put('LC_ALL', 'C')
    end

    if option[:custom_environment]
      option[:custom_environment].each do |k, v|
        if v.nil?
          env.remove(k.to_s)
        else
          env.put(k.to_s, v.to_s)
        end
      end
    end

    begin
      child    = pb.start
      childin  = child.getOutputStream.to_io
      childout = child.getInputStream.to_io
      childerr = child.getErrorStream.to_io

      # Fire up the threads that copy stderr and stdout
      io_threads = { childout => stdout, childerr => stderr }.map do |from, to|
        Thread.new do
          begin
            while data = from.readpartial(8192)
              to.write data
            end
          rescue EOFError
            # normal termination, actually
          end
        end
      end

      # Copy the input stream to the child
      childin.sync = true           # force flushing, eh.
      while data = stdin.read(8192)
        childin.write data
      end

      # ...and signal that we are done.
      childin.close

      # Finally, wait for everything to terminate.
      io_threads.each(&:join)
      child.waitFor
    rescue NativeException => e
      # MRI, thanks to the shell, returns 127 if execution fails because the
      # command is not found. We should emulate this, I suppose, because other
      # parts of the system will fail if we don't.
      return 127 if e.message.include? 'java.io.IOException'
      raise
    end

    # I watched a snail crawl along the edge of a straight razor. That's my
    # dream; that's my nightmare. Crawling, slithering, along the edge of a
    # straight razor... and surviving.
    #
    # What makes me sad is that we only depend on this in, like, one place in
    # the code, and that isn't really used.  So, this is almost entirely to
    # satisfy the dictate of the tests.
    system("/bin/sh -c 'exit #{child.exitValue}'")

    # return the exit status.
    return child.exitValue
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

        stdout.close(true)

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
