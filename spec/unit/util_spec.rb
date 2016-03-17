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
    let(:mode) { Puppet.features.microsoft_windows? ? :windows : :posix }

    before :each do
      @original_path = ENV["PATH"]
      @new_env = {:PATH => "/some/bogus/path"}
    end

    it "should change environment variables within the block then reset environment variables to their original values" do
      Puppet::Util.withenv @new_env, mode do
        expect(ENV["PATH"]).to eq("/some/bogus/path")
      end
      expect(ENV["PATH"]).to eq(@original_path)
    end

    it "should reset environment variables to their original values even if the block fails" do
      begin
        Puppet::Util.withenv @new_env, mode do
          expect(ENV["PATH"]).to eq("/some/bogus/path")
          raise "This is a failure"
        end
      rescue
      end
      expect(ENV["PATH"]).to eq(@original_path)
    end

    it "should reset environment variables even when they are set twice" do
      # Setting Path & Environment parameters in Exec type can cause weirdness
      @new_env["PATH"] = "/someother/bogus/path"
      Puppet::Util.withenv @new_env, mode do
        # When assigning duplicate keys, can't guarantee order of evaluation
        expect(ENV["PATH"]).to match(/\/some.*\/bogus\/path/)
      end
      expect(ENV["PATH"]).to eq(@original_path)
    end

    it "should remove any new environment variables after the block ends" do
      @new_env[:FOO] = "bar"
      ENV["FOO"] = nil
      Puppet::Util.withenv @new_env, mode do
        expect(ENV["FOO"]).to eq("bar")
      end
      expect(ENV["FOO"]).to eq(nil)
    end
  end

  describe "#withenv on POSIX", :unless => Puppet.features.microsoft_windows? do
    it "should preserve case" do
      # start with lower case key,
      env_key = SecureRandom.uuid.downcase

      begin
        original_value = 'hello'
        ENV[env_key] = original_value
        new_value = 'goodbye'

        Puppet::Util.withenv({env_key.upcase => new_value}, :posix) do
          expect(ENV[env_key]).to eq(original_value)
          expect(ENV[env_key.upcase]).to eq(new_value)
        end

        expect(ENV[env_key]).to eq(original_value)
        expect(ENV[env_key.upcase]).to be_nil
      ensure
        ENV.delete(env_key)
      end
    end
  end

  describe "#withenv on Windows", :if => Puppet.features.microsoft_windows? do

    let(:process) { Puppet::Util::Windows::Process }

    it "should ignore case" do
      # start with lower case key, ensuring string is not entirely numeric
      env_key = SecureRandom.uuid.downcase + 'a'

      begin
        original_value = 'hello'
        ENV[env_key] = original_value
        new_value = 'goodbye'

        Puppet::Util.withenv({env_key.upcase => new_value}, :windows) do
          expect(ENV[env_key]).to eq(new_value)
          expect(ENV[env_key.upcase]).to eq(new_value)
        end

        expect(ENV[env_key]).to eq(original_value)
        expect(ENV[env_key.upcase]).to eq(original_value)
      ensure
        ENV.delete(env_key)
      end
    end

    it "works around Ruby bug 8822 (which fails to preserve UTF-8 properly when accessing ENV)" do
      env_var_name = SecureRandom.uuid
      utf_8_bytes = [225, 154, 160] # rune ᚠ
      utf_8_str = env_var_name + utf_8_bytes.pack('c*').force_encoding(Encoding::UTF_8)

      Puppet::Util.withenv({utf_8_str => utf_8_str}, :windows) do
        # the true Windows environemnt APIs see the variables correctly
        expect(process.get_environment_strings[utf_8_str]).to eq(utf_8_str)

        # document buggy Ruby behavior here for https://bugs.ruby-lang.org/issues/8822
        # Ruby retrieves / stores ENV names in the current codepage
        # when these tests no longer pass, Ruby has fixed its bugs and workarounds can be removed
        # interestingly we would expect some of these tests to fail when codepage is 65001
        # but instead the env values are in Encoding::ASCII_8BIT!

        # both a string in UTF-8 and current codepage are deemed valid keys to the hash
        # which in a sane world shouldn't be true
        codepage_key = utf_8_str.dup.force_encoding(Encoding.default_external)
        expect(ENV.key?(codepage_key)).to eq(true)
        expect(ENV.key?(utf_8_str)).to eq(true)
        # similarly the value stored at the key is in current codepage and won't match UTF-8 value
        env_value = ENV[utf_8_str]
        expect(env_value).to_not eq(utf_8_str)
        expect(env_value.encoding).to_not eq(Encoding::UTF_8)
        # but it can be forced back to UTF-8 to make it match.. ugh
        converted_value = ENV[utf_8_str].dup.force_encoding(Encoding::UTF_8)
        expect(converted_value).to eq(utf_8_str)
      end

      # real environment shouldn't have env var anymore
      expect(process.get_environment_strings[utf_8_str]).to eq(nil)
    end

    it "should preseve existing environment and should not corrupt UTF-8 environment variables" do
      env_var_name = SecureRandom.uuid
      utf_8_bytes = [225, 154, 160] # rune ᚠ
      utf_8_str = env_var_name + utf_8_bytes.pack('c*').force_encoding(Encoding::UTF_8)
      env_var_name_utf_8 = utf_8_str

      begin
        # UTF-8 name and value
        process.set_environment_variable(env_var_name_utf_8, utf_8_str)
        # ASCII name / UTF-8 value
        process.set_environment_variable(env_var_name, utf_8_str)

        original_keys = process.get_environment_strings.keys.to_a
        Puppet::Util.withenv({}, :windows) { }

        env = process.get_environment_strings

        expect(env[env_var_name]).to eq(utf_8_str)
        expect(env[env_var_name_utf_8]).to eq(utf_8_str)
        expect(env.keys.to_a).to eq(original_keys)
      ensure
        process.set_environment_variable(env_var_name_utf_8, nil)
        process.set_environment_variable(env_var_name, nil)
      end
    end
  end

  describe "#absolute_path?" do
    describe "on posix systems", :if => Puppet.features.posix? do
      it "should default to the platform of the local system" do
        expect(Puppet::Util).to be_absolute_path('/foo')
        expect(Puppet::Util).not_to be_absolute_path('C:/foo')
      end
    end

    describe "on windows", :if => Puppet.features.microsoft_windows? do
      it "should default to the platform of the local system" do
        expect(Puppet::Util).to be_absolute_path('C:/foo')
        expect(Puppet::Util).not_to be_absolute_path('/foo')
      end
    end

    describe "when using platform :posix" do
      %w[/ /foo /foo/../bar //foo //Server/Foo/Bar //?/C:/foo/bar /\Server/Foo /foo//bar/baz].each do |path|
        it "should return true for #{path}" do
          expect(Puppet::Util).to be_absolute_path(path, :posix)
        end
      end

      %w[. ./foo \foo C:/foo \\Server\Foo\Bar \\?\C:\foo\bar \/?/foo\bar \/Server/foo foo//bar/baz].each do |path|
        it "should return false for #{path}" do
          expect(Puppet::Util).not_to be_absolute_path(path, :posix)
        end
      end
    end

    describe "when using platform :windows" do
      %w[C:/foo C:\foo \\\\Server\Foo\Bar \\\\?\C:\foo\bar //Server/Foo/Bar //?/C:/foo/bar /\?\C:/foo\bar \/Server\Foo/Bar c:/foo//bar//baz].each do |path|
        it "should return true for #{path}" do
          expect(Puppet::Util).to be_absolute_path(path, :windows)
        end
      end

      %w[/ . ./foo \foo /foo /foo/../bar //foo C:foo/bar foo//bar/baz].each do |path|
        it "should return false for #{path}" do
          expect(Puppet::Util).not_to be_absolute_path(path, :windows)
        end
      end
    end
  end

  describe "#path_to_uri" do
    %w[. .. foo foo/bar foo/../bar].each do |path|
      it "should reject relative path: #{path}" do
        expect { Puppet::Util.path_to_uri(path) }.to raise_error(Puppet::Error)
      end
    end

    it "should perform URI escaping" do
      expect(Puppet::Util.path_to_uri("/foo bar").path).to eq("/foo%20bar")
    end

    describe "when using platform :posix" do
      before :each do
        Puppet.features.stubs(:posix).returns true
        Puppet.features.stubs(:microsoft_windows?).returns false
      end

      %w[/ /foo /foo/../bar].each do |path|
        it "should convert #{path} to URI" do
          expect(Puppet::Util.path_to_uri(path).path).to eq(path)
        end
      end
    end

    describe "when using platform :windows" do
      before :each do
        Puppet.features.stubs(:posix).returns false
        Puppet.features.stubs(:microsoft_windows?).returns true
      end

      it "should normalize backslashes" do
        expect(Puppet::Util.path_to_uri('c:\\foo\\bar\\baz').path).to eq('/' + 'c:/foo/bar/baz')
      end

      %w[C:/ C:/foo/bar].each do |path|
        it "should convert #{path} to absolute URI" do
          expect(Puppet::Util.path_to_uri(path).path).to eq('/' + path)
        end
      end

      %w[share C$].each do |path|
        it "should convert UNC #{path} to absolute URI" do
          uri = Puppet::Util.path_to_uri("\\\\server\\#{path}")
          expect(uri.host).to eq('server')
          expect(uri.path).to eq('/' + path)
        end
      end
    end
  end

  describe ".uri_to_path" do
    require 'uri'

    it "should strip host component" do
      expect(Puppet::Util.uri_to_path(URI.parse('http://foo/bar'))).to eq('/bar')
    end

    it "should accept puppet URLs" do
      expect(Puppet::Util.uri_to_path(URI.parse('puppet:///modules/foo'))).to eq('/modules/foo')
    end

    it "should return unencoded path" do
      expect(Puppet::Util.uri_to_path(URI.parse('http://foo/bar%20baz'))).to eq('/bar baz')
    end

    it "should be nil-safe" do
      expect(Puppet::Util.uri_to_path(nil)).to be_nil
    end

    describe "when using platform :posix",:if => Puppet.features.posix? do
      it "should accept root" do
        expect(Puppet::Util.uri_to_path(URI.parse('file:/'))).to eq('/')
      end

      it "should accept single slash" do
        expect(Puppet::Util.uri_to_path(URI.parse('file:/foo/bar'))).to eq('/foo/bar')
      end

      it "should accept triple slashes" do
        expect(Puppet::Util.uri_to_path(URI.parse('file:///foo/bar'))).to eq('/foo/bar')
      end
    end

    describe "when using platform :windows", :if => Puppet.features.microsoft_windows? do
      it "should accept root" do
        expect(Puppet::Util.uri_to_path(URI.parse('file:/C:/'))).to eq('C:/')
      end

      it "should accept single slash" do
        expect(Puppet::Util.uri_to_path(URI.parse('file:/C:/foo/bar'))).to eq('C:/foo/bar')
      end

      it "should accept triple slashes" do
        expect(Puppet::Util.uri_to_path(URI.parse('file:///C:/foo/bar'))).to eq('C:/foo/bar')
      end

      it "should accept file scheme with double slashes as a UNC path" do
        expect(Puppet::Util.uri_to_path(URI.parse('file://host/share/file'))).to eq('//host/share/file')
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
      expect(Puppet::Util.safe_posix_fork).to eq(pid)
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
      expect(Puppet::Util.which(path)).to eq(path)
    end

    it "should return nil if no executable found" do
      expect(Puppet::Util.which('doesnotexist')).to be_nil
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
      expect(Puppet::Util.which(base)).to be_nil
    end

    it "should ignore ~user directories if the user doesn't exist" do
      # Windows treats *any* user as a "user that doesn't exist", which means
      # that this will work correctly across all our platforms, and should
      # behave consistently.  If they ever implement it correctly (eg: to do
      # the lookup for real) it should just work transparently.
      baduser = 'if_this_user_exists_I_will_eat_my_hat'
      Puppet::Util.withenv("PATH" => "~#{baduser}#{File::PATH_SEPARATOR}#{base}") do
        expect(Puppet::Util.which('foo')).to eq(path)
      end
    end

    describe "on POSIX systems" do
      before :each do
        Puppet.features.stubs(:posix?).returns true
        Puppet.features.stubs(:microsoft_windows?).returns false
      end

      it "should walk the search PATH returning the first executable" do
        Puppet::Util.stubs(:get_env).with('PATH').returns(File.expand_path('/bin'))
        Puppet::Util.stubs(:get_env).with('PATHEXT').returns(nil)

        expect(Puppet::Util.which('foo')).to eq(path)
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
          Puppet::Util.stubs(:get_env).with('PATH').returns(%w[/bar /bin].map{|dir| File.expand_path(dir)}.join(File::PATH_SEPARATOR))
          Puppet::Util.stubs(:get_env).with('PATHEXT').returns('.FOOBAR')

          FileTest.expects(:file?).with(File.join(File.expand_path('/bar'), 'foo.CMD')).returns false

          expect(Puppet::Util.which('foo.CMD')).to eq(path)
        end
      end

      describe "when a file extension is not specified" do
        it "should walk each extension in PATHEXT until an executable is found" do
          bar = File.expand_path('/bar')
          Puppet::Util.stubs(:get_env).with('PATH').returns("#{bar}#{File::PATH_SEPARATOR}#{base}")
          Puppet::Util.stubs(:get_env).with('PATHEXT').returns(".EXE#{File::PATH_SEPARATOR}.CMD")

          exts = sequence('extensions')
          FileTest.expects(:file?).in_sequence(exts).with(File.join(bar, 'foo.EXE')).returns false
          FileTest.expects(:file?).in_sequence(exts).with(File.join(bar, 'foo.CMD')).returns false
          FileTest.expects(:file?).in_sequence(exts).with(File.join(base, 'foo.EXE')).returns false
          FileTest.expects(:file?).in_sequence(exts).with(path).returns true

          expect(Puppet::Util.which('foo')).to eq(path)
        end

        it "should walk the default extension path if the environment variable is not defined" do
          Puppet::Util.stubs(:get_env).with('PATH').returns(base)
          Puppet::Util.stubs(:get_env).with('PATHEXT').returns(nil)

          exts = sequence('extensions')
          %w[.COM .EXE .BAT].each do |ext|
            FileTest.expects(:file?).in_sequence(exts).with(File.join(base, "foo#{ext}")).returns false
          end
          FileTest.expects(:file?).in_sequence(exts).with(path).returns true

          expect(Puppet::Util.which('foo')).to eq(path)
        end

        it "should fall back if no extension matches" do
          Puppet::Util.stubs(:get_env).with('PATH').returns(base)
          Puppet::Util.stubs(:get_env).with('PATHEXT').returns(".EXE")

          FileTest.stubs(:file?).with(File.join(base, 'foo.EXE')).returns false
          FileTest.stubs(:file?).with(File.join(base, 'foo')).returns true
          FileTest.stubs(:executable?).with(File.join(base, 'foo')).returns true

          expect(Puppet::Util.which('foo')).to eq(File.join(base, 'foo'))
        end
      end
    end
  end

  describe "hash symbolizing functions" do
    let (:myhash) { { "foo" => "bar", :baz => "bam" } }
    let (:resulthash) { { :foo => "bar", :baz => "bam" } }

    describe "#symbolizehash" do
      it "should return a symbolized hash" do
        newhash = Puppet::Util.symbolizehash(myhash)
        expect(newhash).to eq(resulthash)
      end
    end
  end

  context "#replace_file" do
    subject { Puppet::Util }
    it { is_expected.to respond_to :replace_file }

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
      expect(File.read(target.path)).to eq("hello, world\n")

      # Replace the file.
      subject.replace_file(target.path, 0600) do |fh|
        fh.puts "I am the passenger..."
      end

      # ...and check the replacement was complete.
      expect(File.read(target.path)).to eq("I am the passenger...\n")
    end

    # When running with the same user and group sid, which is the default,
    # Windows collapses the owner and group modes into a single ACE, resulting
    # in set(0600) => get(0660) and so forth. --daniel 2012-03-30
    modes = [0555, 0660, 0770]
    modes += [0600, 0700] unless Puppet.features.microsoft_windows?
    modes.each do |mode|
      it "should copy 0#{mode.to_s(8)} permissions from the target file by default" do
        set_mode(mode, target.path)

        expect(get_mode(target.path)).to eq(mode)

        subject.replace_file(target.path, 0000) {|fh| fh.puts "bazam" }

        expect(get_mode(target.path)).to eq(mode)
        expect(File.read(target.path)).to eq("bazam\n")
      end
    end

    it "should copy the permissions of the source file before yielding on Unix", :if => !Puppet.features.microsoft_windows? do
      set_mode(0555, target.path)
      inode = Puppet::FileSystem.stat(target.path).ino

      yielded = false
      subject.replace_file(target.path, 0600) do |fh|
        expect(get_mode(fh.path)).to eq(0555)
        yielded = true
      end
      expect(yielded).to be_truthy

      expect(Puppet::FileSystem.stat(target.path).ino).not_to eq(inode)
      expect(get_mode(target.path)).to eq(0555)
    end

    it "should use the default permissions if the source file doesn't exist" do
      new_target = target.path + '.foo'
      expect(Puppet::FileSystem.exist?(new_target)).to be_falsey

      begin
        subject.replace_file(new_target, 0555) {|fh| fh.puts "foo" }
        expect(get_mode(new_target)).to eq(0555)
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

      expect(yielded).to be_truthy
      expect(threw).to be_truthy

      # ...and check the replacement was complete.
      expect(File.read(target.path)).to eq("hello, world\n")
    end

    {:string => '664', :number => 0664, :symbolic => "ug=rw-,o=r--" }.each do |label,mode|
      it "should support #{label} format permissions" do
        new_target = target.path + "#{mode}.foo"
        expect(Puppet::FileSystem.exist?(new_target)).to be_falsey

        begin
          subject.replace_file(new_target, mode) {|fh| fh.puts "this is an interesting content" }

          expect(get_mode(new_target)).to eq(0664)
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
      expect(Puppet::Util.pretty_backtrace(trace)).to match(/#{line}/)
    end

    it "should include function names" do
      expect(Puppet::Util.pretty_backtrace).to match(/:in `\w+'/)
    end

    it "should work with Windows paths" do
      expect(Puppet::Util.pretty_backtrace(["C:/work/puppet/c.rb:12:in `foo'\n"])).
        to eq("C:/work/puppet/c.rb:12:in `foo'")
    end
  end

  describe "#deterministic_rand" do

    it "should not fiddle with future rand calls" do
      Puppet::Util.deterministic_rand(123,20)
      rand_one = rand()
      Puppet::Util.deterministic_rand(123,20)
      expect(rand()).not_to eql(rand_one)
    end

    if defined?(Random) == 'constant' && Random.class == Class
      it "should not fiddle with the global seed" do
        srand(1234)
        Puppet::Util.deterministic_rand(123,20)
        expect(srand()).to eql(1234)
      end
    # ruby below 1.9.2 variant
    else
      it "should set a new global seed" do
        srand(1234)
        Puppet::Util.deterministic_rand(123,20)
        expect(srand()).not_to eql(1234)
      end
    end
  end
end
