#!/usr/bin/env ruby

require 'spec_helper'

describe Puppet::Util do
  include PuppetSpec::Files


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
      Puppet::Util.withenv @new_env do
        ENV["FOO"].should == "bar"
      end
      ENV["FOO"].should == nil
    end

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

      Puppet::Util.withenv({:HOME => nil, :PATH => env_path}) do
        Puppet::Util::Warnings.expects(:warnonce).once
        Puppet::Util.which('foo')
      end
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
end
