#!/usr/bin/env ruby

require 'spec_helper'

describe Puppet::Util do
  include PuppetSpec::Files

  if Puppet.features.microsoft_windows?
    def set_mode(mode, file)
      Puppet::Util::Windows::Security.set_mode(mode, file)
    end

    def get_mode(file)
      Puppet::Util::Windows::Security.get_mode(file) & 07777
    end
  else
    def set_mode(mode, file)
      File.chmod(mode, file)
    end

    def get_mode(file)
      Puppet::FileSystem.lstat(file).mode & 07777
    end
  end

  describe "#withenv" do
    before :each do
      @original_path = ENV["PATH"]
      @new_env = {:PATH => "/some/bogus/path"}
    end

    it "should change environment variables within the block then reset environment variables to their original values" do
      Puppet::Util.withenv @new_env do
        ENV["PATH"].should == "/some/bogus/path"
      end
      ENV["PATH"].should == @original_path
    end

    it "should reset environment variables to their original values even if the block fails" do
      begin
        Puppet::Util.withenv @new_env do
          ENV["PATH"].should == "/some/bogus/path"
          raise "This is a failure"
        end
      rescue
      end
      ENV["PATH"].should == @original_path
    end

    it "should reset environment variables even when they are set twice" do
      # Setting Path & Environment parameters in Exec type can cause weirdness
      @new_env["PATH"] = "/someother/bogus/path"
      Puppet::Util.withenv @new_env do
        # When assigning duplicate keys, can't guarantee order of evaluation
        ENV["PATH"].should =~ /\/some.*\/bogus\/path/
      end
      ENV["PATH"].should == @original_path
    end

    it "should remove any new environment variables after the block ends" do
      @new_env[:FOO] = "bar"
      ENV["FOO"] = nil
      Puppet::Util.withenv @new_env do
        ENV["FOO"].should == "bar"
      end
      ENV["FOO"].should == nil
    end

  end

  describe "#absolute_path?" do
    describe "on posix systems", :as_platform => :posix do
      it "should default to the platform of the local system" do
        Puppet::Util.should be_absolute_path('/foo')
        Puppet::Util.should_not be_absolute_path('C:/foo')
      end
    end

    describe "on windows", :as_platform => :windows do
      it "should default to the platform of the local system" do
        Puppet::Util.should be_absolute_path('C:/foo')
        Puppet::Util.should_not be_absolute_path('/foo')
      end
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

  describe "safe_posix_fork" do
    let(:pid) { 5501 }

    before :each do
      # Most of the things this method does are bad to do during specs. :/
      Kernel.stubs(:fork).returns(pid).yields

      $stdin.stubs(:reopen)
      $stdout.stubs(:reopen)
      $stderr.stubs(:reopen)

      # ensure that we don't really close anything!
      (0..256).each {|n| IO.stubs(:new) }
    end

    it "should close all open file descriptors except stdin/stdout/stderr when /proc/self/fd exists" do
      # This is ugly, but I can't really think of a better way to do it without
      # letting it actually close fds, which seems risky
      fds = [".", "..","0","1","2","3","5","100","1000"]
      fds.each do |fd|
        if fd == '.' || fd == '..'
          next
        elsif ['0', '1', '2'].include? fd
          IO.expects(:new).with(fd.to_i).never
        else
          IO.expects(:new).with(fd.to_i).returns mock('io', :close)
        end
      end

      Dir.stubs(:foreach).with('/proc/self/fd').multiple_yields(*fds)
      Puppet::Util.safe_posix_fork
    end

    it "should close all open file descriptors except stdin/stdout/stderr when /proc/self/fd doesn't exists" do
      # This is ugly, but I can't really think of a better way to do it without
      # letting it actually close fds, which seems risky
      (0..2).each {|n| IO.expects(:new).with(n).never}
      (3..256).each { |n| IO.expects(:new).with(n).returns mock('io', :close)  }
      Dir.stubs(:foreach).with('/proc/self/fd') { raise Errno::ENOENT }

      Puppet::Util.safe_posix_fork
    end

    it "should fork a child process to execute the block" do
      Kernel.expects(:fork).returns(pid).yields

      Puppet::Util.safe_posix_fork do
        message = "Fork this!"
      end
    end

    it "should return the pid of the child process" do
      Puppet::Util.safe_posix_fork.should == pid
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

    it "should warn if the user's HOME is not set but their PATH contains a ~" do
      env_path = %w[~/bin /usr/bin /bin].join(File::PATH_SEPARATOR)

      env = {:HOME => nil, :PATH => env_path}
      env.merge!({:HOMEDRIVE => nil, :USERPROFILE => nil}) if Puppet.features.microsoft_windows?

      Puppet::Util.withenv(env) do
        Puppet::Util::Warnings.expects(:warnonce).once
        Puppet::Util.which('foo')
      end
    end

    it "should reject directories" do
      Puppet::Util.which(base).should be_nil
    end

    it "should ignore ~user directories if the user doesn't exist" do
      # Windows treats *any* user as a "user that doesn't exist", which means
      # that this will work correctly across all our platforms, and should
      # behave consistently.  If they ever implement it correctly (eg: to do
      # the lookup for real) it should just work transparently.
      baduser = 'if_this_user_exists_I_will_eat_my_hat'
      Puppet::Util.withenv("PATH" => "~#{baduser}#{File::PATH_SEPARATOR}#{base}") do
        Puppet::Util.which('foo').should == path
      end
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

  describe "hash symbolizing functions" do
    let (:myhash) { { "foo" => "bar", :baz => "bam" } }
    let (:resulthash) { { :foo => "bar", :baz => "bam" } }

    describe "#symbolizehash" do
      it "should return a symbolized hash" do
        newhash = Puppet::Util.symbolizehash(myhash)
        newhash.should == resulthash
      end
    end
  end

  context "#replace_file" do
    subject { Puppet::Util }
    it { should respond_to :replace_file }

    let :target do
      target = Tempfile.new("puppet-util-replace-file")
      target.puts("hello, world")
      target.flush              # make sure content is on disk.
      target.fsync rescue nil
      target.close
      target
    end

    it "should fail if no block is given" do
      expect { subject.replace_file(target.path, 0600) }.to raise_error /block/
    end

    it "should replace a file when invoked" do
      # Check that our file has the expected content.
      File.read(target.path).should == "hello, world\n"

      # Replace the file.
      subject.replace_file(target.path, 0600) do |fh|
        fh.puts "I am the passenger..."
      end

      # ...and check the replacement was complete.
      File.read(target.path).should == "I am the passenger...\n"
    end

    # When running with the same user and group sid, which is the default,
    # Windows collapses the owner and group modes into a single ACE, resulting
    # in set(0600) => get(0660) and so forth. --daniel 2012-03-30
    modes = [0555, 0660, 0770]
    modes += [0600, 0700] unless Puppet.features.microsoft_windows?
    modes.each do |mode|
      it "should copy 0#{mode.to_s(8)} permissions from the target file by default" do
        set_mode(mode, target.path)

        get_mode(target.path).should == mode

        subject.replace_file(target.path, 0000) {|fh| fh.puts "bazam" }

        get_mode(target.path).should == mode
        File.read(target.path).should == "bazam\n"
      end
    end

    it "should copy the permissions of the source file before yielding on Unix", :if => !Puppet.features.microsoft_windows? do
      set_mode(0555, target.path)
      inode = Puppet::FileSystem.stat(target.path).ino

      yielded = false
      subject.replace_file(target.path, 0600) do |fh|
        get_mode(fh.path).should == 0555
        yielded = true
      end
      yielded.should be_true

      Puppet::FileSystem.stat(target.path).ino.should_not == inode
      get_mode(target.path).should == 0555
    end

    it "should use the default permissions if the source file doesn't exist" do
      new_target = target.path + '.foo'
      Puppet::FileSystem.exist?(new_target).should be_false

      begin
        subject.replace_file(new_target, 0555) {|fh| fh.puts "foo" }
        get_mode(new_target).should == 0555
      ensure
        Puppet::FileSystem.unlink(new_target) if Puppet::FileSystem.exist?(new_target)
      end
    end

    it "should not replace the file if an exception is thrown in the block" do
      yielded = false
      threw   = false

      begin
        subject.replace_file(target.path, 0600) do |fh|
          yielded = true
          fh.puts "different content written, then..."
          raise "...throw some random failure"
        end
      rescue Exception => e
        if e.to_s =~ /some random failure/
          threw = true
        else
          raise
        end
      end

      yielded.should be_true
      threw.should be_true

      # ...and check the replacement was complete.
      File.read(target.path).should == "hello, world\n"
    end

    {:string => '664', :number => 0664, :symbolic => "ug=rw-,o=r--" }.each do |label,mode|
      it "should support #{label} format permissions" do
        new_target = target.path + "#{mode}.foo"
        Puppet::FileSystem.exist?(new_target).should be_false

        begin
          subject.replace_file(new_target, mode) {|fh| fh.puts "this is an interesting content" }

          get_mode(new_target).should == 0664
        ensure
          Puppet::FileSystem.unlink(new_target) if Puppet::FileSystem.exist?(new_target)
        end
      end
    end

  end

  describe "#pretty_backtrace" do
    it "should include lines that don't match the standard backtrace pattern" do
      line = "non-standard line\n"
      trace = caller[0..2] + [line] + caller[3..-1]
      Puppet::Util.pretty_backtrace(trace).should =~ /#{line}/
    end

    it "should include function names" do
      Puppet::Util.pretty_backtrace.should =~ /:in `\w+'/
    end

    it "should work with Windows paths" do
      Puppet::Util.pretty_backtrace(["C:/work/puppet/c.rb:12:in `foo'\n"]).
        should == "C:/work/puppet/c.rb:12:in `foo'"
    end
  end

  describe "#execute" do
    let(:command) { 'mycommand' }

    it "should pass arguments through" do
      arguments = 'myarg'
      Puppet::Util::Execution.expects(:execute).with(command, arguments)

      subject.execute(command, arguments)
    end

    it "should not supply default arguments" do
      Puppet::Util::Execution.expects(:execute).with(command)

      subject.execute(command)
    end
  end

  describe "#deterministic_rand" do

    it "should not fiddle with future rand calls" do
      Puppet::Util.deterministic_rand(123,20)
      rand_one = rand()
      Puppet::Util.deterministic_rand(123,20)
      rand().should_not eql(rand_one)
    end

    if defined?(Random) == 'constant' && Random.class == Class
      it "should not fiddle with the global seed" do
        srand(1234)
        Puppet::Util.deterministic_rand(123,20)
        srand().should eql(1234)
      end
    # ruby below 1.9.2 variant
    else
      it "should set a new global seed" do
        srand(1234)
        Puppet::Util.deterministic_rand(123,20)
        srand().should_not eql(1234)
      end
    end
  end
end
