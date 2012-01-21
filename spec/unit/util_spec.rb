#!/usr/bin/env ruby

require 'spec_helper'

describe Puppet::Util do
  include PuppetSpec::Files

  def process_status(exitstatus)
    return exitstatus if Puppet.features.microsoft_windows?

    stub('child_status', :exitstatus => exitstatus)
  end

  describe "#absolute_path?" do
    it "should default to the platform of the local system" do
      Puppet.features.stubs(:posix?).returns(true)
      Puppet.features.stubs(:microsoft_windows?).returns(false)

      Puppet::Util.should be_absolute_path('/foo')
      Puppet::Util.should_not be_absolute_path('C:/foo')

      Puppet.features.stubs(:posix?).returns(false)
      Puppet.features.stubs(:microsoft_windows?).returns(true)

      Puppet::Util.should be_absolute_path('C:/foo')
      Puppet::Util.should_not be_absolute_path('/foo')
    end

    describe "when using platform :posix" do
      %w[/ /foo /foo/../bar //foo //Server/Foo/Bar //?/C:/foo/bar /\Server/Foo /foo//bar/baz].each do |path|
        it "should return true for #{path}" do
          Puppet::Util.should be_absolute_path(path, :posix)
        end
      end

      %w[. ./foo \foo C:/foo \\Server\Foo\Bar \\?\C:\foo\bar \/?/foo\bar \/Server/foo foo//bar/baz].each do |path|
        it "should return false for #{path}" do
          Puppet::Util.should_not be_absolute_path(path, :posix)
        end
      end
    end

    describe "when using platform :windows" do
      %w[C:/foo C:\foo \\\\Server\Foo\Bar \\\\?\C:\foo\bar //Server/Foo/Bar //?/C:/foo/bar /\?\C:/foo\bar \/Server\Foo/Bar c:/foo//bar//baz].each do |path|
        it "should return true for #{path}" do
          Puppet::Util.should be_absolute_path(path, :windows)
        end
      end

      %w[/ . ./foo \foo /foo /foo/../bar //foo C:foo/bar foo//bar/baz].each do |path|
        it "should return false for #{path}" do
          Puppet::Util.should_not be_absolute_path(path, :windows)
        end
      end
    end
  end

  describe "#path_to_uri" do
    %w[. .. foo foo/bar foo/../bar].each do |path|
      it "should reject relative path: #{path}" do
        lambda { Puppet::Util.path_to_uri(path) }.should raise_error(Puppet::Error)
      end
    end

    it "should perform URI escaping" do
      Puppet::Util.path_to_uri("/foo bar").path.should == "/foo%20bar"
    end

    describe "when using platform :posix" do
      before :each do
        Puppet.features.stubs(:posix).returns true
        Puppet.features.stubs(:microsoft_windows?).returns false
      end

      %w[/ /foo /foo/../bar].each do |path|
        it "should convert #{path} to URI" do
          Puppet::Util.path_to_uri(path).path.should == path
        end
      end
    end

    describe "when using platform :windows" do
      before :each do
        Puppet.features.stubs(:posix).returns false
        Puppet.features.stubs(:microsoft_windows?).returns true
      end

      it "should normalize backslashes" do
        Puppet::Util.path_to_uri('c:\\foo\\bar\\baz').path.should == '/' + 'c:/foo/bar/baz'
      end

      %w[C:/ C:/foo/bar].each do |path|
        it "should convert #{path} to absolute URI" do
          Puppet::Util.path_to_uri(path).path.should == '/' + path
        end
      end

      %w[share C$].each do |path|
        it "should convert UNC #{path} to absolute URI" do
          uri = Puppet::Util.path_to_uri("\\\\server\\#{path}")
          uri.host.should == 'server'
          uri.path.should == '/' + path
        end
      end
    end
  end

  describe ".uri_to_path" do
    require 'uri'

    it "should strip host component" do
      Puppet::Util.uri_to_path(URI.parse('http://foo/bar')).should == '/bar'
    end

    it "should accept puppet URLs" do
      Puppet::Util.uri_to_path(URI.parse('puppet:///modules/foo')).should == '/modules/foo'
    end

    it "should return unencoded path" do
      Puppet::Util.uri_to_path(URI.parse('http://foo/bar%20baz')).should == '/bar baz'
    end

    it "should be nil-safe" do
      Puppet::Util.uri_to_path(nil).should be_nil
    end

    describe "when using platform :posix",:if => Puppet.features.posix? do
      it "should accept root" do
        Puppet::Util.uri_to_path(URI.parse('file:/')).should == '/'
      end

      it "should accept single slash" do
        Puppet::Util.uri_to_path(URI.parse('file:/foo/bar')).should == '/foo/bar'
      end

      it "should accept triple slashes" do
        Puppet::Util.uri_to_path(URI.parse('file:///foo/bar')).should == '/foo/bar'
      end
    end

    describe "when using platform :windows", :if => Puppet.features.microsoft_windows? do
      it "should accept root" do
        Puppet::Util.uri_to_path(URI.parse('file:/C:/')).should == 'C:/'
      end

      it "should accept single slash" do
        Puppet::Util.uri_to_path(URI.parse('file:/C:/foo/bar')).should == 'C:/foo/bar'
      end

      it "should accept triple slashes" do
        Puppet::Util.uri_to_path(URI.parse('file:///C:/foo/bar')).should == 'C:/foo/bar'
      end

      it "should accept file scheme with double slashes as a UNC path" do
        Puppet::Util.uri_to_path(URI.parse('file://host/share/file')).should == '//host/share/file'
      end
    end
  end

  describe "execution methods" do
    let(:pid) { 5501 }
    let(:null_file) { Puppet.features.microsoft_windows? ? 'NUL' : '/dev/null' }

    describe "#execute_posix" do
      before :each do
        # Most of the things this method does are bad to do during specs. :/
        Kernel.stubs(:fork).returns(pid).yields
        Process.stubs(:setsid)
        Kernel.stubs(:exec)
        Puppet::Util::SUIDManager.stubs(:change_user)
        Puppet::Util::SUIDManager.stubs(:change_group)

        $stdin.stubs(:reopen)
        $stdout.stubs(:reopen)
        $stderr.stubs(:reopen)

        @stdin  = File.open(null_file, 'r')
        @stdout = Tempfile.new('stdout')
        @stderr = File.open(null_file, 'w')
      end

      it "should fork a child process to execute the command" do
        Kernel.expects(:fork).returns(pid).yields
        Kernel.expects(:exec).with('test command')

        Puppet::Util.execute_posix('test command', {}, @stdin, @stdout, @stderr)
      end

      it "should start a new session group" do
        Process.expects(:setsid)

        Puppet::Util.execute_posix('test command', {}, @stdin, @stdout, @stderr)
      end

      it "should close all open file descriptors except stdin/stdout/stderr" do
        # This is ugly, but I can't really think of a better way to do it without
        # letting it actually close fds, which seems risky
        (0..2).each {|n| IO.expects(:new).with(n).never}
        (3..256).each {|n| IO.expects(:new).with(n).returns mock('io', :close) }

        Puppet::Util.execute_posix('test command', {}, @stdin, @stdout, @stderr)
      end

      it "should permanently change to the correct user and group if specified" do
        Puppet::Util::SUIDManager.expects(:change_group).with(55, true)
        Puppet::Util::SUIDManager.expects(:change_user).with(50, true)

        Puppet::Util.execute_posix('test command', {:uid => 50, :gid => 55}, @stdin, @stdout, @stderr)
      end

      it "should exit failure if there is a problem execing the command" do
        Kernel.expects(:exec).with('test command').raises("failed to execute!")
        Puppet::Util.stubs(:puts)
        Puppet::Util.expects(:exit!).with(1)

        Puppet::Util.execute_posix('test command', {}, @stdin, @stdout, @stderr)
      end

      it "should properly execute commands specified as arrays" do
        Kernel.expects(:exec).with('test command', 'with', 'arguments')

        Puppet::Util.execute_posix(['test command', 'with', 'arguments'], {:uid => 50, :gid => 55}, @stdin, @stdout, @stderr)
      end

      it "should properly execute string commands with embedded newlines" do
        Kernel.expects(:exec).with("/bin/echo 'foo' ; \n /bin/echo 'bar' ;")

        Puppet::Util.execute_posix("/bin/echo 'foo' ; \n /bin/echo 'bar' ;", {:uid => 50, :gid => 55}, @stdin, @stdout, @stderr)
      end

      it "should return the pid of the child process" do
        Puppet::Util.execute_posix('test command', {}, @stdin, @stdout, @stderr).should == pid
      end
    end

    describe "#execute_windows" do
      let(:proc_info_stub) { stub 'processinfo', :process_id => pid }

      before :each do
        Process.stubs(:create).returns(proc_info_stub)
        Process.stubs(:waitpid2).with(pid).returns([pid, process_status(0)])

        @stdin  = File.open(null_file, 'r')
        @stdout = Tempfile.new('stdout')
        @stderr = File.open(null_file, 'w')
      end

      it "should create a new process for the command" do
        Process.expects(:create).with(
          :command_line => "test command",
          :startup_info => {:stdin => @stdin, :stdout => @stdout, :stderr => @stderr}
        ).returns(proc_info_stub)

        Puppet::Util.execute_windows('test command', {}, @stdin, @stdout, @stderr)
      end

      it "should return the pid of the child process" do
        Puppet::Util.execute_windows('test command', {}, @stdin, @stdout, @stderr).should == pid
      end

      it "should quote arguments containing spaces if command is specified as an array" do
        Process.expects(:create).with do |args|
          args[:command_line] == '"test command" with some "arguments \"with spaces"'
        end.returns(proc_info_stub)

        Puppet::Util.execute_windows(['test command', 'with', 'some', 'arguments "with spaces'], {}, @stdin, @stdout, @stderr)
      end
    end

    describe "#execute" do
      before :each do
        Process.stubs(:waitpid2).with(pid).returns([pid, process_status(0)])
      end

      describe "when an execution stub is specified" do
        before :each do
          Puppet::Util::ExecutionStub.set do |command,args,stdin,stdout,stderr|
            "execution stub output"
          end
        end

        it "should call the block on the stub" do
          Puppet::Util.execute("/usr/bin/run_my_execute_stub").should == "execution stub output"
        end

        it "should not actually execute anything" do
          Puppet::Util.expects(:execute_posix).never
          Puppet::Util.expects(:execute_windows).never

          Puppet::Util.execute("/usr/bin/run_my_execute_stub")
        end
      end

      describe "when setting up input and output files" do
        include PuppetSpec::Files
        let(:executor) { Puppet.features.microsoft_windows? ? 'execute_windows' : 'execute_posix' }

        before :each do
          Puppet::Util.stubs(:wait_for_output)
        end

        it "should set stdin to the stdinfile if specified" do
          input = tmpfile('stdin')
          FileUtils.touch(input)

          Puppet::Util.expects(executor).with do |_,_,stdin,_,_|
            stdin.path == input
          end.returns(pid)

          Puppet::Util.execute('test command', :stdinfile => input)
        end

        it "should set stdin to the null file if not specified" do
          Puppet::Util.expects(executor).with do |_,_,stdin,_,_|
            stdin.path == null_file
          end.returns(pid)

          Puppet::Util.execute('test command')
        end

        describe "when squelch is set" do
          it "should set stdout and stderr to the null file" do
            Puppet::Util.expects(executor).with do |_,_,_,stdout,stderr|
              stdout.path == null_file and stderr.path == null_file
            end.returns(pid)

            Puppet::Util.execute('test command', :squelch => true)
          end
        end

        describe "when squelch is not set" do
          it "should set stdout to a temporary output file" do
            outfile = Tempfile.new('stdout')
            Tempfile.stubs(:new).returns(outfile)

            Puppet::Util.expects(executor).with do |_,_,_,stdout,_|
              stdout.path == outfile.path
            end.returns(pid)

            Puppet::Util.execute('test command', :squelch => false)
          end

          it "should set stderr to the same file as stdout if combine is true" do
            outfile = Tempfile.new('stdout')
            Tempfile.stubs(:new).returns(outfile)

            Puppet::Util.expects(executor).with do |_,_,_,stdout,stderr|
              stdout.path == outfile.path and stderr.path == outfile.path
            end.returns(pid)

            Puppet::Util.execute('test command', :squelch => false, :combine => true)
          end

          it "should set stderr to the null device if combine is false" do
            outfile = Tempfile.new('stdout')
            Tempfile.stubs(:new).returns(outfile)

            Puppet::Util.expects(executor).with do |_,_,_,stdout,stderr|
              stdout.path == outfile.path and stderr.path == null_file
            end.returns(pid)

            Puppet::Util.execute('test command', :squelch => false, :combine => false)
          end
        end
      end
    end

    describe "after execution" do
      let(:executor) { Puppet.features.microsoft_windows? ? 'execute_windows' : 'execute_posix' }

      before :each do
        Process.stubs(:waitpid2).with(pid).returns([pid, process_status(0)])

        Puppet::Util.stubs(executor).returns(pid)
      end

      it "should wait for the child process to exit" do
        Puppet::Util.stubs(:wait_for_output)

        Process.expects(:waitpid2).with(pid).returns([pid, process_status(0)])

        Puppet::Util.execute('test command')
      end

      it "should close the stdin/stdout/stderr files used by the child" do
        stdin = mock 'file', :close
        stdout = mock 'file', :close
        stderr = mock 'file', :close

        File.expects(:open).
          times(3).
          returns(stdin).
          then.returns(stdout).
          then.returns(stderr)

        Puppet::Util.execute('test command', :squelch => true)
      end

      it "should read and return the output if squelch is false" do
        stdout = Tempfile.new('test')
        Tempfile.stubs(:new).returns(stdout)
        stdout.write("My expected command output")

        Puppet::Util.execute('test command').should == "My expected command output"
      end

      it "should not read the output if squelch is true" do
        stdout = Tempfile.new('test')
        Tempfile.stubs(:new).returns(stdout)
        stdout.write("My expected command output")

        Puppet::Util.execute('test command', :squelch => true).should == nil
      end

      it "should delete the file used for output if squelch is false" do
        stdout = Tempfile.new('test')
        path = stdout.path
        Tempfile.stubs(:new).returns(stdout)

        Puppet::Util.execute('test command')

        File.should_not be_exist(path)
      end

      it "should raise an error if failonfail is true and the child failed" do
        Process.expects(:waitpid2).with(pid).returns([pid, process_status(1)])

        expect {
          Puppet::Util.execute('fail command', :failonfail => true)
        }.to raise_error(Puppet::ExecutionFailure, /Execution of 'fail command' returned 1/)
      end

      it "should not raise an error if failonfail is false and the child failed" do
        Process.expects(:waitpid2).with(pid).returns([pid, process_status(1)])

        expect {
          Puppet::Util.execute('fail command', :failonfail => false)
        }.not_to raise_error
      end

      it "should not raise an error if failonfail is true and the child succeeded" do
        Process.expects(:waitpid2).with(pid).returns([pid, process_status(0)])

        expect {
          Puppet::Util.execute('fail command', :failonfail => true)
        }.not_to raise_error
      end
    end
  end

  describe "#which" do
    let(:base) { File.expand_path('/bin') }
    let(:path) { File.join(base, 'foo') }

    before :each do
      FileTest.stubs(:file?).returns false
      FileTest.stubs(:file?).with(path).returns true

      FileTest.stubs(:executable?).returns false
      FileTest.stubs(:executable?).with(path).returns true
    end

    it "should accept absolute paths" do
      Puppet::Util.which(path).should == path
    end

    it "should return nil if no executable found" do
      Puppet::Util.which('doesnotexist').should be_nil
    end

    it "should reject directories" do
      Puppet::Util.which(base).should be_nil
    end

    describe "on POSIX systems" do
      before :each do
        Puppet.features.stubs(:posix?).returns true
        Puppet.features.stubs(:microsoft_windows?).returns false
      end

      it "should walk the search PATH returning the first executable" do
        ENV.stubs(:[]).with('PATH').returns(File.expand_path('/bin'))

        Puppet::Util.which('foo').should == path
      end
    end

    describe "on Windows systems" do
      let(:path) { File.expand_path(File.join(base, 'foo.CMD')) }

      before :each do
        Puppet.features.stubs(:posix?).returns false
        Puppet.features.stubs(:microsoft_windows?).returns true
      end

      describe "when a file extension is specified" do
        it "should walk each directory in PATH ignoring PATHEXT" do
          ENV.stubs(:[]).with('PATH').returns(%w[/bar /bin].map{|dir| File.expand_path(dir)}.join(File::PATH_SEPARATOR))

          FileTest.expects(:file?).with(File.join(File.expand_path('/bar'), 'foo.CMD')).returns false

          ENV.expects(:[]).with('PATHEXT').never
          Puppet::Util.which('foo.CMD').should == path
        end
      end

      describe "when a file extension is not specified" do
        it "should walk each extension in PATHEXT until an executable is found" do
          bar = File.expand_path('/bar')
          ENV.stubs(:[]).with('PATH').returns("#{bar}#{File::PATH_SEPARATOR}#{base}")
          ENV.stubs(:[]).with('PATHEXT').returns(".EXE#{File::PATH_SEPARATOR}.CMD")

          exts = sequence('extensions')
          FileTest.expects(:file?).in_sequence(exts).with(File.join(bar, 'foo.EXE')).returns false
          FileTest.expects(:file?).in_sequence(exts).with(File.join(bar, 'foo.CMD')).returns false
          FileTest.expects(:file?).in_sequence(exts).with(File.join(base, 'foo.EXE')).returns false
          FileTest.expects(:file?).in_sequence(exts).with(path).returns true

          Puppet::Util.which('foo').should == path
        end

        it "should walk the default extension path if the environment variable is not defined" do
          ENV.stubs(:[]).with('PATH').returns(base)
          ENV.stubs(:[]).with('PATHEXT').returns(nil)

          exts = sequence('extensions')
          %w[.COM .EXE .BAT].each do |ext|
            FileTest.expects(:file?).in_sequence(exts).with(File.join(base, "foo#{ext}")).returns false
          end
          FileTest.expects(:file?).in_sequence(exts).with(path).returns true

          Puppet::Util.which('foo').should == path
        end

        it "should fall back if no extension matches" do
          ENV.stubs(:[]).with('PATH').returns(base)
          ENV.stubs(:[]).with('PATHEXT').returns(".EXE")

          FileTest.stubs(:file?).with(File.join(base, 'foo.EXE')).returns false
          FileTest.stubs(:file?).with(File.join(base, 'foo')).returns true
          FileTest.stubs(:executable?).with(File.join(base, 'foo')).returns true

          Puppet::Util.which('foo').should == File.join(base, 'foo')
        end
      end
    end
  end

  describe "#binread" do
    let(:contents) { "foo\r\nbar" }

    it "should preserve line endings" do
      path = tmpfile('util_binread')
      File.open(path, 'wb') { |f| f.print contents }

      Puppet::Util.binread(path).should == contents
    end

    it "should raise an error if the file doesn't exist" do
      expect { Puppet::Util.binread('/path/does/not/exist') }.to raise_error(Errno::ENOENT)
    end
  end
end
