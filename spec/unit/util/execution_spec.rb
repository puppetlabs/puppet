# encoding: UTF-8
require 'spec_helper'
require 'puppet/file_system/uniquefile'
require 'puppet_spec/character_encoding'

describe Puppet::Util::Execution, if: !Puppet::Util::Platform.jruby? do
  include Puppet::Util::Execution

  # utility methods to help us test some private methods without being quite so verbose
  def call_exec_posix(command, arguments, stdin, stdout, stderr)
    Puppet::Util::Execution.send(:execute_posix, command, arguments, stdin, stdout, stderr)
  end

  def call_exec_windows(command, arguments, stdin, stdout, stderr)
    Puppet::Util::Execution.send(:execute_windows, command, arguments, stdin, stdout, stderr)
  end

  describe "execution methods" do
    let(:pid) { 5501 }
    let(:process_handle) { 0xDEADBEEF }
    let(:thread_handle) { 0xCAFEBEEF }
    let(:proc_info_stub) { double('processinfo', :process_handle => process_handle, :thread_handle => thread_handle, :process_id => pid) }
    let(:null_file) { Puppet::Util::Platform.windows? ? 'NUL' : '/dev/null' }

    def stub_process_wait(exitstatus)
      if Puppet::Util::Platform.windows?
        allow(Puppet::Util::Windows::Process).to receive(:wait_process).with(process_handle).and_return(exitstatus)
        allow(FFI::WIN32).to receive(:CloseHandle).with(process_handle)
        allow(FFI::WIN32).to receive(:CloseHandle).with(thread_handle)
      else
        allow(Process).to receive(:waitpid2).with(pid, Process::WNOHANG).and_return(nil, [pid, double('child_status', :exitstatus => exitstatus)])
        allow(Process).to receive(:waitpid2).with(pid).and_return([pid, double('child_status', :exitstatus => exitstatus)])
      end
    end

    describe "#execute_posix (stubs)", :unless => Puppet::Util::Platform.windows? do
      before :each do
        # Most of the things this method does are bad to do during specs. :/
        allow(Kernel).to receive(:fork).and_return(pid).and_yield
        allow(Process).to receive(:setsid)
        allow(Kernel).to receive(:exec)
        allow(Puppet::Util::SUIDManager).to receive(:change_user)
        allow(Puppet::Util::SUIDManager).to receive(:change_group)

        # ensure that we don't really close anything!
        allow(IO).to receive(:new)

        allow($stdin).to receive(:reopen)
        allow($stdout).to receive(:reopen)
        allow($stderr).to receive(:reopen)

        @stdin  = File.open(null_file, 'r')
        @stdout = Puppet::FileSystem::Uniquefile.new('stdout')
        @stderr = File.open(null_file, 'w')

        # there is a danger here that ENV will be modified by exec_posix.  Normally it would only affect the ENV
        #  of a forked process, but here, we're stubbing Kernel.fork, so the method has the ability to override the
        #  "real" ENV.  To guard against this, we'll capture a snapshot of ENV before each test.
        @saved_env = ENV.to_hash

        # Now, we're going to effectively "mock" the magic ruby 'ENV' variable by creating a local definition of it
        #  inside of the module we're testing.
        Puppet::Util::Execution::ENV = {}
      end

      after :each do
        # And here we remove our "mock" version of 'ENV', which will allow us to validate that the real ENV has been
        #  left unharmed.
        Puppet::Util::Execution.send(:remove_const, :ENV)

        # capture the current environment and make sure it's the same as it was before the test
        cur_env = ENV.to_hash

        # we will get some fairly useless output if we just use the raw == operator on the hashes here, so we'll
        #  be a bit more explicit and laborious in the name of making the error more useful...
        @saved_env.each_pair { |key,val| expect(cur_env[key]).to eq(val) }
        expect(cur_env.keys - @saved_env.keys).to eq([])

      end


      it "should fork a child process to execute the command" do
        expect(Kernel).to receive(:fork).and_return(pid).and_yield
        expect(Kernel).to receive(:exec).with('test command')

        call_exec_posix('test command', {}, @stdin, @stdout, @stderr)
      end

      it "should start a new session group" do
        expect(Process).to receive(:setsid)

        call_exec_posix('test command', {}, @stdin, @stdout, @stderr)
      end

      it "should permanently change to the correct user and group if specified" do
        expect(Puppet::Util::SUIDManager).to receive(:change_group).with(55, true)
        expect(Puppet::Util::SUIDManager).to receive(:change_user).with(50, true)

        call_exec_posix('test command', {:uid => 50, :gid => 55}, @stdin, @stdout, @stderr)
      end

      it "should exit failure if there is a problem execing the command" do
        expect(Kernel).to receive(:exec).with('test command').and_raise("failed to execute!")
        allow(Puppet::Util::Execution).to receive(:puts)
        expect(Puppet::Util::Execution).to receive(:exit!).with(1)

        call_exec_posix('test command', {}, @stdin, @stdout, @stderr)
      end

      it "should properly execute commands specified as arrays" do
        expect(Kernel).to receive(:exec).with('test command', 'with', 'arguments')

        call_exec_posix(['test command', 'with', 'arguments'], {:uid => 50, :gid => 55}, @stdin, @stdout, @stderr)
      end

      it "should properly execute string commands with embedded newlines" do
        expect(Kernel).to receive(:exec).with("/bin/echo 'foo' ; \n /bin/echo 'bar' ;")

        call_exec_posix("/bin/echo 'foo' ; \n /bin/echo 'bar' ;", {:uid => 50, :gid => 55}, @stdin, @stdout, @stderr)
      end

      context 'cwd option' do
        let(:cwd) { 'cwd' }

        it 'should run the command in the specified working directory' do
          expect(Dir).to receive(:chdir).with(cwd)
          expect(Kernel).to receive(:exec).with('test command')

          call_exec_posix('test command', { :cwd => cwd }, @stdin, @stdout, @stderr)
        end

        it "should not change the current working directory if cwd is unspecified" do
          expect(Dir).to receive(:chdir).never
          expect(Kernel).to receive(:exec).with('test command')

          call_exec_posix('test command', {}, @stdin, @stdout, @stderr)
        end
      end

      it "should return the pid of the child process" do
        expect(call_exec_posix('test command', {}, @stdin, @stdout, @stderr)).to eq(pid)
      end
    end

    describe "#execute_windows (stubs)", :if => Puppet::Util::Platform.windows? do
      before :each do
        allow(Process).to receive(:create).and_return(proc_info_stub)
        stub_process_wait(0)

        @stdin  = File.open(null_file, 'r')
        @stdout = Puppet::FileSystem::Uniquefile.new('stdout')
        @stderr = File.open(null_file, 'w')
      end

      it "should create a new process for the command" do
        expect(Process).to receive(:create).with(
          :command_line => "test command",
          :startup_info => {:stdin => @stdin, :stdout => @stdout, :stderr => @stderr},
          :close_handles => false
        ).and_return(proc_info_stub)

        call_exec_windows('test command', {}, @stdin, @stdout, @stderr)
      end

      context 'cwd option' do
        let(:cwd) { 'cwd' }
        it "should execute the command in the specified working directory" do
          expect(Process).to receive(:create).with(
            :command_line => "test command",
            :startup_info => {
              :stdin => @stdin,
              :stdout => @stdout,
              :stderr => @stderr
            },
            :close_handles => false,
            :cwd => cwd
          )

          call_exec_windows('test command', { :cwd => cwd }, @stdin, @stdout, @stderr)
        end

        it "should not change the current working directory if cwd is unspecified" do
          expect(Dir).to receive(:chdir).never
          expect(Process).to receive(:create) do |args|
            expect(args[:cwd]).to be_nil
          end

          call_exec_windows('test command', {}, @stdin, @stdout, @stderr)
        end
      end

      context 'suppress_window option' do
        let(:cwd) { 'cwd' }
        it "should execute the command in the specified working directory" do
          expect(Process).to receive(:create).with(
            :command_line => "test command",
            :startup_info => {
              :stdin => @stdin,
              :stdout => @stdout,
              :stderr => @stderr
            },
            :close_handles => false,
            :creation_flags => Puppet::Util::Windows::Process::CREATE_NO_WINDOW
          )

          call_exec_windows('test command', { :suppress_window => true }, @stdin, @stdout, @stderr)
        end
      end

      it "should return the process info of the child process" do
        expect(call_exec_windows('test command', {}, @stdin, @stdout, @stderr)).to eq(proc_info_stub)
      end

      it "should quote arguments containing spaces if command is specified as an array" do
        expect(Process).to receive(:create).with(hash_including(command_line: '"test command" with some "arguments \"with spaces"')).and_return(proc_info_stub)

        call_exec_windows(['test command', 'with', 'some', 'arguments "with spaces'], {}, @stdin, @stdout, @stderr)
      end
    end

    describe "#execute (stubs)" do
      before :each do
        stub_process_wait(0)
      end

      describe "when an execution stub is specified" do
        before :each do
          Puppet::Util::ExecutionStub.set do |command,args,stdin,stdout,stderr|
            "execution stub output"
          end
        end

        it "should call the block on the stub" do
          expect(Puppet::Util::Execution.execute("/usr/bin/run_my_execute_stub")).to eq("execution stub output")
        end

        it "should not actually execute anything" do
          expect(Puppet::Util::Execution).not_to receive(:execute_posix)
          expect(Puppet::Util::Execution).not_to receive(:execute_windows)

          Puppet::Util::Execution.execute("/usr/bin/run_my_execute_stub")
        end
      end

      describe "when setting up input and output files" do
        include PuppetSpec::Files
        let(:executor) { Puppet::Util::Platform.windows? ? 'execute_windows' : 'execute_posix' }
        let(:rval) { Puppet::Util::Platform.windows? ? proc_info_stub : pid }

        before :each do
          allow(Puppet::Util::Execution).to receive(:wait_for_output)
        end

        it "should set stdin to the stdin argument if specified" do
          input = tmpfile('stdin')
          FileUtils.touch(input)

          expect(Puppet::Util::Execution).to receive(executor) do |_,_,stdin,_,_|
            expect(stdin.path).to eq(input)
            rval
          end

          Puppet::Util::Execution.execute('test command', :stdin => input)
        end

        it "should set stdin to a pipe if the stdin argument is a StringIO" do
          expect(Puppet::Util::Execution).to receive(executor) do |_,_,stdin,_,_|
            expect(stdin.class).to eq(IO)
            rval
          end

          Puppet::Util::Execution.execute('test command', :stdin => StringIO.new)
        end

        it "should set stdin to the stdinfile if specified" do
          input = tmpfile('stdin')
          FileUtils.touch(input)

          expect(Puppet::Util::Execution).to receive(executor) do |_,_,stdin,_,_|
            expect(stdin.path).to eq(input)
            rval
          end

          Puppet::Util::Execution.execute('test command', :stdinfile => input)
        end

        it "should set stdin to the null file if not specified" do
          expect(Puppet::Util::Execution).to receive(executor) do |_,_,stdin,_,_|
            expect(stdin.path).to eq(null_file)
            rval
          end

          Puppet::Util::Execution.execute('test command')
        end

        it "should set stdin to a pipe if stdin_yield is specified" do
          expect(Puppet::Util::Execution).to receive(executor) do |_,_,stdin,_,_|
            expect(stdin.class).to eq(IO)
            rval
          end

          Puppet::Util::Execution.execute('test command', :stdin_yield => true) { |_,_,_| }
        end

        describe "when squelch is set" do
          it "should set stdout and stderr to the null file" do
            expect(Puppet::Util::Execution).to receive(executor) do |_,_,_,stdout,stderr|
              expect(stdout.path).to eq(null_file)
              expect(stderr.path).to eq(null_file)
              rval
            end

            Puppet::Util::Execution.execute('test command', :squelch => true)
          end
        end

        describe "cwd option" do
          def expect_cwd_to_be(cwd)
            expect(Puppet::Util::Execution).to receive(executor).with(
              anything,
              hash_including(cwd: cwd),
              anything,
              anything,
              anything
            ).and_return(rval)
          end

          it 'should raise an ArgumentError if the specified working directory does not exist' do
            cwd = 'cwd'
            allow(Puppet::FileSystem).to receive(:directory?).with(cwd).and_return(false)

            expect {
              Puppet::Util::Execution.execute('test command', cwd: cwd)
            }.to raise_error do |error|
              expect(error).to be_a(ArgumentError)
              expect(error.message).to match(cwd)
            end
          end

          it "should set the cwd to the user-specified one" do
            allow(Puppet::FileSystem).to receive(:directory?).with('cwd').and_return(true)
            expect_cwd_to_be('cwd')
            Puppet::Util::Execution.execute('test command', cwd: 'cwd')
          end
        end

        describe "on POSIX", :if => Puppet.features.posix? do
          describe "when squelch is not set" do
            it "should set stdout to a pipe" do
              expect(Puppet::Util::Execution).to receive(executor).with(anything, anything, anything, be_a(IO), anything).and_return(rval)

              Puppet::Util::Execution.execute('test command', :squelch => false)
            end

            it "should set stderr to the same file as stdout if combine is true" do
              expect(Puppet::Util::Execution).to receive(executor) do |_,_,_,stdout,stderr|
                expect(stdout).to eq(stderr)
                rval
              end

              Puppet::Util::Execution.execute('test command', :squelch => false, :combine => true)
            end

            it "should set stderr to the null device if combine is false" do
              expect(Puppet::Util::Execution).to receive(executor) do |_,_,_,stdout,stderr|
                expect(stdout.class).to eq(IO)
                expect(stderr.path).to eq(null_file)
                rval
              end

              Puppet::Util::Execution.execute('test command', :squelch => false, :combine => false)
            end

            it "should default combine to true when no options are specified" do
              expect(Puppet::Util::Execution).to receive(executor) do |_,_,_,stdout,stderr|
                expect(stdout).to eq(stderr)
                rval
              end

              Puppet::Util::Execution.execute('test command')
            end

            it "should default combine to false when options are specified, but combine is not" do
              expect(Puppet::Util::Execution).to receive(executor) do |_,_,_,stdout,stderr|
                expect(stdout.class).to eq(IO)
                expect(stderr.path).to eq(null_file)
                rval
              end

              Puppet::Util::Execution.execute('test command', :failonfail => false)
            end

            it "should default combine to false when an empty hash of options is specified" do
              expect(Puppet::Util::Execution).to receive(executor) do |_,_,_,stdout,stderr|
                expect(stdout.class).to eq(IO)
                expect(stderr.path).to eq(null_file)
                rval
              end

              Puppet::Util::Execution.execute('test command', {})
            end
          end
        end

        describe "on Windows", :if => Puppet::Util::Platform.windows? do
          describe "when squelch is not set" do
            it "should set stdout to a temporary output file" do
              outfile = Puppet::FileSystem::Uniquefile.new('stdout')
              allow(Puppet::FileSystem::Uniquefile).to receive(:new).and_return(outfile)

              expect(Puppet::Util::Execution).to receive(executor) do |_,_,_,stdout,_|
                expect(stdout.path).to eq(outfile.path)
                rval
              end

              Puppet::Util::Execution.execute('test command', :squelch => false)
            end

            it "should set stderr to the same file as stdout if combine is true" do
              outfile = Puppet::FileSystem::Uniquefile.new('stdout')
              allow(Puppet::FileSystem::Uniquefile).to receive(:new).and_return(outfile)

              expect(Puppet::Util::Execution).to receive(executor) do |_,_,_,stdout,stderr|
                expect(stdout.path).to eq(outfile.path)
                expect(stderr.path).to eq(outfile.path)
                rval
              end

              Puppet::Util::Execution.execute('test command', :squelch => false, :combine => true)
            end

            it "should set stderr to the null device if combine is false" do
              outfile = Puppet::FileSystem::Uniquefile.new('stdout')
              allow(Puppet::FileSystem::Uniquefile).to receive(:new).and_return(outfile)

              expect(Puppet::Util::Execution).to receive(executor) do |_,_,_,stdout,stderr|
                expect(stdout.path).to eq(outfile.path)
                expect(stderr.path).to eq(null_file)
                rval
              end

              Puppet::Util::Execution.execute('test command', :squelch => false, :combine => false)
            end

            it "should combine stdout and stderr if combine is true" do
              outfile = Puppet::FileSystem::Uniquefile.new('stdout')
              allow(Puppet::FileSystem::Uniquefile).to receive(:new).and_return(outfile)

              expect(Puppet::Util::Execution).to receive(executor) do |_,_,_,stdout,stderr|
                expect(stdout.path).to eq(outfile.path)
                expect(stderr.path).to eq(outfile.path)
                rval
              end

              Puppet::Util::Execution.execute('test command', :combine => true)
            end

            it "should default combine to true when no options are specified" do
              outfile = Puppet::FileSystem::Uniquefile.new('stdout')
              allow(Puppet::FileSystem::Uniquefile).to receive(:new).and_return(outfile)

              expect(Puppet::Util::Execution).to receive(executor) do |_,_,_,stdout,stderr|
                expect(stdout.path).to eq(outfile.path)
                expect(stderr.path).to eq(outfile.path)
                rval
              end

              Puppet::Util::Execution.execute('test command')
            end

            it "should default combine to false when options are specified, but combine is not" do
              outfile = Puppet::FileSystem::Uniquefile.new('stdout')
              allow(Puppet::FileSystem::Uniquefile).to receive(:new).and_return(outfile)

              expect(Puppet::Util::Execution).to receive(executor) do |_,_,_,stdout,stderr|
                expect(stdout.path).to eq(outfile.path)
                expect(stderr.path).to eq(null_file)
                rval
              end

              Puppet::Util::Execution.execute('test command', :failonfail => false)
            end

            it "should default combine to false when an empty hash of options is specified" do
              outfile = Puppet::FileSystem::Uniquefile.new('stdout')
              allow(Puppet::FileSystem::Uniquefile).to receive(:new).and_return(outfile)

              expect(Puppet::Util::Execution).to receive(executor) do |_,_,_,stdout,stderr|
                expect(stdout.path).to eq(outfile.path)
                expect(stderr.path).to eq(null_file)
                rval
              end

              Puppet::Util::Execution.execute('test command', {})
            end
          end
        end
      end

      describe "on Windows", :if => Puppet::Util::Platform.windows? do
        it "should always close the process and thread handles" do
          allow(Puppet::Util::Execution).to receive(:execute_windows).and_return(proc_info_stub)

          expect(Puppet::Util::Windows::Process).to receive(:wait_process).with(process_handle).and_raise('whatever')
          expect(FFI::WIN32).to receive(:CloseHandle).with(thread_handle)
          expect(FFI::WIN32).to receive(:CloseHandle).with(process_handle)

          expect { Puppet::Util::Execution.execute('test command') }.to raise_error(RuntimeError)
        end

        it "should return the correct exit status even when exit status is greater than 256" do
          real_exit_status = 3010

          allow(Puppet::Util::Execution).to receive(:execute_windows).and_return(proc_info_stub)
          stub_process_wait(real_exit_status)
          allow(Puppet::Util::Execution).to receive(:exitstatus).and_return(real_exit_status % 256) # The exitstatus is changed to be mod 256 so that ruby can fit it into 8 bits.

          expect(Puppet::Util::Execution.execute('test command', :failonfail => false).exitstatus).to eq(real_exit_status)
        end
      end
    end

    describe "#execute (posix locale)", :unless => Puppet::Util::Platform.windows? do
      before :each do
        # there is a danger here that ENV will be modified by exec_posix.  Normally it would only affect the ENV
        #  of a forked process, but, in some of the previous tests in this file we're stubbing Kernel.fork., which could
        #  allow the method to override the "real" ENV.  This shouldn't be a problem for these tests because they are
        #  not stubbing Kernel.fork, but, better safe than sorry... so, to guard against this, we'll capture a snapshot
        #  of ENV before each test.
        @saved_env = ENV.to_hash
      end

      after :each do
        # capture the current environment and make sure it's the same as it was before the test
        cur_env = ENV.to_hash
        # we will get some fairly useless output if we just use the raw == operator on the hashes here, so we'll
        #  be a bit more explicit and laborious in the name of making the error more useful...
        @saved_env.each_pair { |key,val| expect(cur_env[key]).to eq(val) }
        expect(cur_env.keys - @saved_env.keys).to eq([])
      end

      # build up a printf-style string that contains a command to get the value of an environment variable
      # from the operating system.  We can substitute into this with the names of the desired environment variables later.
      get_env_var_cmd = 'echo $%s'

      # a sentinel value that we can use to emulate what locale environment variables might be set to on an international
      # system.
      lang_sentinel_value = "en_US.UTF-8"
      # a temporary hash that contains sentinel values for each of the locale environment variables that we override in
      # "execute"
      locale_sentinel_env = {}
      Puppet::Util::POSIX::LOCALE_ENV_VARS.each { |var| locale_sentinel_env[var] = lang_sentinel_value }

      it "should override the locale environment variables when :override_locale is not set (defaults to true)" do
        # temporarily override the locale environment vars with a sentinel value, so that we can confirm that
        # execute is actually setting them.
        Puppet::Util.withenv(locale_sentinel_env) do
          Puppet::Util::POSIX::LOCALE_ENV_VARS.each do |var|
            # we expect that all of the POSIX vars will have been cleared except for LANG and LC_ALL
            expected_value = (['LANG', 'LC_ALL'].include?(var)) ? "C" : ""
            expect(Puppet::Util::Execution.execute(get_env_var_cmd % var).strip).to eq(expected_value)
          end
        end
      end

      it "should override the LANG environment variable when :override_locale is set to true" do
        # temporarily override the locale environment vars with a sentinel value, so that we can confirm that
        # execute is actually setting them.
        Puppet::Util.withenv(locale_sentinel_env) do
          Puppet::Util::POSIX::LOCALE_ENV_VARS.each do |var|
            # we expect that all of the POSIX vars will have been cleared except for LANG and LC_ALL
            expected_value = (['LANG', 'LC_ALL'].include?(var)) ? "C" : ""
            expect(Puppet::Util::Execution.execute(get_env_var_cmd % var, {:override_locale => true}).strip).to eq(expected_value)
          end
        end
      end

      it "should *not* override the LANG environment variable when :override_locale is set to false" do
        # temporarily override the locale environment vars with a sentinel value, so that we can confirm that
        # execute is not setting them.
        Puppet::Util.withenv(locale_sentinel_env) do
          Puppet::Util::POSIX::LOCALE_ENV_VARS.each do |var|
            expect(Puppet::Util::Execution.execute(get_env_var_cmd % var, {:override_locale => false}).strip).to eq(lang_sentinel_value)
          end
        end
      end

      it "should have restored the LANG and locale environment variables after execution" do
        # we'll do this once without any sentinel values, to give us a little more test coverage
        orig_env_vals = {}
        Puppet::Util::POSIX::LOCALE_ENV_VARS.each do |var|
          orig_env_vals[var] = ENV[var]
        end
        # now we can really execute any command--doesn't matter what it is...
        Puppet::Util::Execution.execute(get_env_var_cmd % 'anything', {:override_locale => true})
        # now we check and make sure the original environment was restored
        Puppet::Util::POSIX::LOCALE_ENV_VARS.each do |var|
          expect(ENV[var]).to eq(orig_env_vals[var])
        end

        # now, once more... but with our sentinel values
        Puppet::Util.withenv(locale_sentinel_env) do
          # now we can really execute any command--doesn't matter what it is...
          Puppet::Util::Execution.execute(get_env_var_cmd % 'anything', {:override_locale => true})
          # now we check and make sure the original environment was restored
          Puppet::Util::POSIX::LOCALE_ENV_VARS.each do |var|
            expect(ENV[var]).to eq(locale_sentinel_env[var])
          end
        end

      end
    end

    describe "#execute (posix user env vars)", :unless => Puppet::Util::Platform.windows? do
      # build up a printf-style string that contains a command to get the value of an environment variable
      # from the operating system.  We can substitute into this with the names of the desired environment variables later.
      get_env_var_cmd = 'echo $%s'

      # a sentinel value that we can use to emulate what locale environment variables might be set to on an international
      # system.
      user_sentinel_value = "Abracadabra"
      # a temporary hash that contains sentinel values for each of the locale environment variables that we override in
      # "execute"
      user_sentinel_env = {}
      Puppet::Util::POSIX::USER_ENV_VARS.each { |var| user_sentinel_env[var] = user_sentinel_value }

      it "should unset user-related environment vars during execution" do
        # first we set up a temporary execution environment with sentinel values for the user-related environment vars
        # that we care about.
        Puppet::Util.withenv(user_sentinel_env) do
          # with this environment, we loop over the vars in question
          Puppet::Util::POSIX::USER_ENV_VARS.each do |var|
            # ensure that our temporary environment is set up as we expect
            expect(ENV[var]).to eq(user_sentinel_env[var])

            # run an "exec" via the provider and ensure that it unsets the vars
            expect(Puppet::Util::Execution.execute(get_env_var_cmd % var).strip).to eq("")

            # ensure that after the exec, our temporary env is still intact
            expect(ENV[var]).to eq(user_sentinel_env[var])
          end
        end
      end

      it "should have restored the user-related environment variables after execution" do
        # we'll do this once without any sentinel values, to give us a little more test coverage
        orig_env_vals = {}
        Puppet::Util::POSIX::USER_ENV_VARS.each do |var|
          orig_env_vals[var] = ENV[var]
        end
        # now we can really execute any command--doesn't matter what it is...
        Puppet::Util::Execution.execute(get_env_var_cmd % 'anything')
        # now we check and make sure the original environment was restored
        Puppet::Util::POSIX::USER_ENV_VARS.each do |var|
          expect(ENV[var]).to eq(orig_env_vals[var])
        end

        # now, once more... but with our sentinel values
        Puppet::Util.withenv(user_sentinel_env) do
          # now we can really execute any command--doesn't matter what it is...
          Puppet::Util::Execution.execute(get_env_var_cmd % 'anything')
          # now we check and make sure the original environment was restored
          Puppet::Util::POSIX::USER_ENV_VARS.each do |var|
            expect(ENV[var]).to eq(user_sentinel_env[var])
          end
        end
      end
    end

    describe "#execute (debug logging)" do
      before :each do
        Puppet[:log_level] = 'debug'

        stub_process_wait(0)

        if Puppet::Util::Platform.windows?
          allow(Puppet::Util::Execution).to receive(:execute_windows).and_return(proc_info_stub)
        else
          allow(Puppet::Util::Execution).to receive(:execute_posix).and_return(pid)
        end
      end

      it "should log if no uid or gid specified" do
        expect(Puppet).to receive(:send_log).with(:debug, "Executing: 'echo hello'")
        Puppet::Util::Execution.execute('echo hello')
      end

      it "should log numeric uid if specified" do
        expect(Puppet).to receive(:send_log).with(:debug, "Executing with uid=100: 'echo hello'")
        Puppet::Util::Execution.execute('echo hello', {:uid => 100})
      end

      it "should log numeric gid if specified" do
        expect(Puppet).to receive(:send_log).with(:debug, "Executing with gid=500: 'echo hello'")
        Puppet::Util::Execution.execute('echo hello', {:gid => 500})
      end

      it "should log numeric uid and gid if specified" do
        expect(Puppet).to receive(:send_log).with(:debug, "Executing with uid=100 gid=500: 'echo hello'")
        Puppet::Util::Execution.execute('echo hello', {:uid => 100, :gid => 500})
      end

      it "should log string uid if specified" do
        expect(Puppet).to receive(:send_log).with(:debug, "Executing with uid=myuser: 'echo hello'")
        Puppet::Util::Execution.execute('echo hello', {:uid => 'myuser'})
      end

      it "should log string gid if specified" do
        expect(Puppet).to receive(:send_log).with(:debug, "Executing with gid=mygroup: 'echo hello'")
        Puppet::Util::Execution.execute('echo hello', {:gid => 'mygroup'})
      end

      it "should log string uid and gid if specified" do
        expect(Puppet).to receive(:send_log).with(:debug, "Executing with uid=myuser gid=mygroup: 'echo hello'")
        Puppet::Util::Execution.execute('echo hello', {:uid => 'myuser', :gid => 'mygroup'})
      end

      it "should log numeric uid and string gid if specified" do
        expect(Puppet).to receive(:send_log).with(:debug, "Executing with uid=100 gid=mygroup: 'echo hello'")
        Puppet::Util::Execution.execute('echo hello', {:uid => 100, :gid => 'mygroup'})
      end

      it 'should redact commands in debug output when passed sensitive option' do
        expect(Puppet).to receive(:send_log).with(:debug, "Executing: '[redacted]'")
        Puppet::Util::Execution.execute('echo hello', {:sensitive => true})
      end
    end

    describe "after execution" do
      before :each do
        stub_process_wait(0)

        if Puppet::Util::Platform.windows?
          allow(Puppet::Util::Execution).to receive(:execute_windows).and_return(proc_info_stub)
        else
          allow(Puppet::Util::Execution).to receive(:execute_posix).and_return(pid)
        end
      end

      it "should wait for the child process to exit" do
        allow(Puppet::Util::Execution).to receive(:wait_for_output)

        Puppet::Util::Execution.execute('test command')
      end

      it "should close the stdin/stdout/stderr files used by the child" do
        stdin = double('file')
        stdout = double('file')
        stderr = double('file')
        [stdin, stdout, stderr].each {|io| expect(io).to receive(:close).at_least(:once)}

        expect(File).to receive(:open).
            exactly(3).times().
            and_return(stdin, stdout, stderr)

        Puppet::Util::Execution.execute('test command', {:squelch => true, :combine => false})
      end

      describe "on POSIX", :if => Puppet.features.posix? do
        context "reading the output" do
          before :each do
            r, w = IO.pipe
            expect(IO).to receive(:pipe).and_return([r, w])
            w.write("My expected \u2744 command output")
          end

          it "should return output with external encoding ISO_8859_1" do
            result = PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::ISO_8859_1) do
              Puppet::Util::Execution.execute('test command')
            end
            expect(result.encoding).to eq(Encoding::ISO_8859_1)
            expect(result).to eq("My expected \u2744 command output".force_encoding(Encoding::ISO_8859_1))
          end

          it "should return output with external encoding UTF_8" do
            result = PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::UTF_8) do
              Puppet::Util::Execution.execute('test command')
            end
            expect(result.encoding).to eq(Encoding::UTF_8)
            expect(result).to eq("My expected \u2744 command output")
          end
        end

        it "should not read the output if squelch is true" do
          expect(IO).not_to receive(:pipe)

          expect(Puppet::Util::Execution.execute('test command', :squelch => true)).to eq('')
        end

        it "should close the pipe used for output if squelch is false" do
          r, w = IO.pipe
          expect(IO).to receive(:pipe).and_return([r, w])

          expect(Puppet::Util::Execution.execute('test command')).to eq("")
          expect(r.closed?)
          expect(w.closed?)
        end

        it "should close the pipe used for output if squelch is false and an error is raised" do
          r, w = IO.pipe
          expect(IO).to receive(:pipe).and_return([r, w])

          if Puppet::Util::Platform.windows?
            expect(Puppet::Util::Execution).to receive(:execute_windows).and_raise(Exception, 'execution failed')
          else
            expect(Puppet::Util::Execution).to receive(:execute_posix).and_raise(Exception, 'execution failed')
          end

          expect {
            subject.execute('fail command')
          }.to raise_error(Exception, 'execution failed')
          expect(r.closed?)
          expect(w.closed?)
        end
      end

      describe "on Windows", :if => Puppet::Util::Platform.windows? do
        context "reading the output" do
          before :each do
            stdout = Puppet::FileSystem::Uniquefile.new('test')
            allow(Puppet::FileSystem::Uniquefile).to receive(:new).and_return(stdout)
            stdout.write("My expected \u2744 command output")
          end

          it "should return output with external encoding ISO_8859_1" do
            result = PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::ISO_8859_1) do
              Puppet::Util::Execution.execute('test command')
            end
            expect(result.encoding).to eq(Encoding::ISO_8859_1)
            expect(result).to eq("My expected \u2744 command output".force_encoding(Encoding::ISO_8859_1))
          end

          it "should return output with external encoding UTF_8" do
            result = PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::UTF_8) do
              Puppet::Util::Execution.execute('test command')
            end
            expect(result.encoding).to eq(Encoding::UTF_8)
            expect(result).to eq("My expected \u2744 command output")
          end
        end

        it "should not read the output if squelch is true" do
          stdout = Puppet::FileSystem::Uniquefile.new('test')
          allow(Puppet::FileSystem::Uniquefile).to receive(:new).and_return(stdout)
          stdout.write("My expected command output")

          expect(Puppet::Util::Execution.execute('test command', :squelch => true)).to eq('')
        end

        it "should delete the file used for output if squelch is false" do
          stdout = Puppet::FileSystem::Uniquefile.new('test')
          path = stdout.path
          allow(Puppet::FileSystem::Uniquefile).to receive(:new).and_return(stdout)

          Puppet::Util::Execution.execute('test command')

          expect(Puppet::FileSystem.exist?(path)).to be_falsey
        end

        it "should not raise an error if the file is open" do
          stdout = Puppet::FileSystem::Uniquefile.new('test')
          allow(Puppet::FileSystem::Uniquefile).to receive(:new).and_return(stdout)

          Puppet::Util::Execution.execute('test command')
        end
      end

      it "should raise an error if failonfail is true and the child failed" do
        stub_process_wait(1)

        expect {
          subject.execute('fail command', :failonfail => true)
        }.to raise_error(Puppet::ExecutionFailure, /Execution of 'fail command' returned 1/)
      end

      it "should raise an error with redacted sensitive command if failonfail is true and the child failed" do
        stub_process_wait(1)

        expect {
          subject.execute('fail command', :failonfail => true, :sensitive => true)
        }.to raise_error(Puppet::ExecutionFailure, /Execution of '\[redacted\]' returned 1/)
      end

      it "should not raise an error if failonfail is false and the child failed" do
        stub_process_wait(1)

        subject.execute('fail command', :failonfail => false)
      end

      it "should not raise an error if failonfail is true and the child succeeded" do
        stub_process_wait(0)

        subject.execute('fail command', :failonfail => true)
      end

      it "should not raise an error if failonfail is false and the child succeeded" do
        stub_process_wait(0)

        subject.execute('fail command', :failonfail => false)
      end

      it "should default failonfail to true when no options are specified" do
        stub_process_wait(1)

        expect {
          subject.execute('fail command')
        }.to raise_error(Puppet::ExecutionFailure, /Execution of 'fail command' returned 1/)
      end

      it "should default failonfail to false when options are specified, but failonfail is not" do
        stub_process_wait(1)

        subject.execute('fail command', { :combine => true })
      end

      it "should default failonfail to false when an empty hash of options is specified" do
        stub_process_wait(1)

        subject.execute('fail command', {})
      end

      it "should raise an error if a nil option is specified" do
        expect {
          Puppet::Util::Execution.execute('fail command', nil)
        }.to raise_error(TypeError, /(can\'t convert|no implicit conversion of) nil into Hash/)
      end
    end
  end

  describe "#execpipe" do
    it "should execute a string as a string" do
      expect(Puppet::Util::Execution).to receive(:open).with('| echo hello 2>&1').and_return('hello')
      expect(Puppet::Util::Execution).to receive(:exitstatus).and_return(0)
      expect(Puppet::Util::Execution.execpipe('echo hello')).to eq('hello')
    end

    it "should print meaningful debug message for string argument" do
      Puppet[:log_level] = 'debug'
      expect(Puppet).to receive(:send_log).with(:debug, "Executing 'echo hello'")
      expect(Puppet::Util::Execution).to receive(:open).with('| echo hello 2>&1').and_return('hello')
      expect(Puppet::Util::Execution).to receive(:exitstatus).and_return(0)
      Puppet::Util::Execution.execpipe('echo hello')
    end

    it "should print meaningful debug message for array argument" do
      Puppet[:log_level] = 'debug'
      expect(Puppet).to receive(:send_log).with(:debug, "Executing 'echo hello'")
      expect(Puppet::Util::Execution).to receive(:open).with('| echo hello 2>&1').and_return('hello')
      expect(Puppet::Util::Execution).to receive(:exitstatus).and_return(0)
      Puppet::Util::Execution.execpipe(['echo','hello'])
    end

    it "should execute an array by pasting together with spaces" do
      expect(Puppet::Util::Execution).to receive(:open).with('| echo hello 2>&1').and_return('hello')
      expect(Puppet::Util::Execution).to receive(:exitstatus).and_return(0)
      expect(Puppet::Util::Execution.execpipe(['echo', 'hello'])).to eq('hello')
    end

    it "should fail if asked to fail, and the child does" do
      allow(Puppet::Util::Execution).to receive(:open).with('| echo hello 2>&1').and_return('error message')
      expect(Puppet::Util::Execution).to receive(:exitstatus).and_return(1)
      expect {
        Puppet::Util::Execution.execpipe('echo hello')
      }.to raise_error Puppet::ExecutionFailure, /error message/
    end

    it "should not fail if asked not to fail, and the child does" do
      allow(Puppet::Util::Execution).to receive(:open).and_return('error message')
      expect(Puppet::Util::Execution.execpipe('echo hello', false)).to eq('error message')
    end
  end

  describe "execfail" do
    it "returns the executed command output" do
      allow(Puppet::Util::Execution).to receive(:execute)
        .and_return(Puppet::Util::Execution::ProcessOutput.new("process output", 0))
      expect(Puppet::Util::Execution.execfail('echo hello', Puppet::Error)).to eq('process output')
    end

    it "raises a caller-specified exception on failure with the backtrace" do
      allow(Puppet::Util::Execution).to receive(:execute).and_raise(Puppet::ExecutionFailure, "failed to execute")
      expect {
        Puppet::Util::Execution.execfail("this will fail", Puppet::Error)
      }.to raise_error(Puppet::Error, /failed to execute/)
    end

    it "raises exceptions that don't extend ExecutionFailure" do
      allow(Puppet::Util::Execution).to receive(:execute).and_raise(ArgumentError, "failed to execute")
      expect {
        Puppet::Util::Execution.execfail("this will fail", Puppet::Error)
      }.to raise_error(ArgumentError, /failed to execute/)
    end

    it "raises a TypeError if the exception class is nil" do
      allow(Puppet::Util::Execution).to receive(:execute).and_raise(Puppet::ExecutionFailure, "failed to execute")
      expect {
        Puppet::Util::Execution.execfail('echo hello', nil)
      }.to raise_error(TypeError, /exception class\/object expected/)
    end
  end
end
