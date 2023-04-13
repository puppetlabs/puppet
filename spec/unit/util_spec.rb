require 'spec_helper'

describe Puppet::Util do
  include PuppetSpec::Files

  if Puppet::Util::Platform.windows?
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
    let(:mode) { Puppet::Util::Platform.windows? ? :windows : :posix }

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

    it "accepts symbolic keys" do
      Puppet::Util.withenv(:FOO => "bar") do
        expect(ENV["FOO"]).to eq("bar")
      end
    end

    it "coerces invalid keys to strings" do
      Puppet::Util.withenv(12345678 => "bar") do
        expect(ENV["12345678"]).to eq("bar")
      end
    end

    it "rejects keys with leading equals" do
      expect {
        Puppet::Util.withenv("=foo" => "bar") {}
      }.to raise_error(Errno::EINVAL, /Invalid argument/)
    end

    it "includes keys with unicode replacement characters" do
      Puppet::Util.withenv("foo\uFFFD" => "bar") do
        expect(ENV).to be_include("foo\uFFFD")
      end
    end

    it "accepts a unicode key" do
      key = "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA\u16B3\u16A2\u16D7"

      Puppet::Util.withenv(key => "bar") do
        expect(ENV[key]).to eq("bar")
      end
    end

    it "accepts a unicode value" do
      value = "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA\u16B3\u16A2\u16D7"

      Puppet::Util.withenv("runes" => value) do
        expect(ENV["runes"]).to eq(value)
      end
    end

    it "rejects a non-string value" do
      expect {
        Puppet::Util.withenv("reject" => 123) {}
      }.to raise_error(TypeError, /no implicit conversion of Integer into String/)
    end

    it "accepts a nil value" do
      Puppet::Util.withenv("foo" => nil) do
        expect(ENV["foo"]).to eq(nil)
      end
    end
  end

  describe "#withenv on POSIX", :unless => Puppet::Util::Platform.windows? do
    it "compares keys case sensitively" do
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

  describe "#withenv on Windows", :if => Puppet::Util::Platform.windows? do
    let(:process) { Puppet::Util::Windows::Process }

    it "compares keys case-insensitively" do
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

    def withenv_utf8(&block)
      env_var_name = SecureRandom.uuid
      utf_8_bytes = [225, 154, 160] # rune ᚠ

      utf_8_key = env_var_name + utf_8_bytes.pack('c*').force_encoding(Encoding::UTF_8)
      utf_8_value = utf_8_key + 'value'
      codepage_key = utf_8_key.dup.force_encoding(Encoding.default_external)

      Puppet::Util.withenv({utf_8_key => utf_8_value}, :windows) do
        # the true Windows environment APIs see the variables correctly
        expect(process.get_environment_strings[utf_8_key]).to eq(utf_8_value)

        # the string contain the same bytes, but have different Ruby metadata
        expect(utf_8_key.bytes.to_a).to eq(codepage_key.bytes.to_a)

        yield utf_8_key, utf_8_value, codepage_key
      end

      # real environment shouldn't have env var anymore
      expect(process.get_environment_strings[utf_8_key]).to eq(nil)
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

    describe "on windows", :if => Puppet::Util::Platform.windows? do
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
    # different UTF-8 widths
    # 1-byte A
    # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
    # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
    # 4-byte ܎ - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
    let (:mixed_utf8) { "A\u06FF\u16A0\u{2070E}" } # Aۿᚠ܎
    let (:mixed_utf8_urlencoded) { "A%DB%BF%E1%9A%A0%F0%A0%9C%8E" }

    %w[. .. foo foo/bar foo/../bar].each do |path|
      it "should reject relative path: #{path}" do
        expect { Puppet::Util.path_to_uri(path) }.to raise_error(Puppet::Error)
      end
    end

    it "should perform URI escaping" do
      expect(Puppet::Util.path_to_uri("/foo bar").path).to eq("/foo%20bar")
    end

    it "should properly URI encode + and space in path" do
      expect(Puppet::Util.path_to_uri("/foo+foo bar").path).to eq("/foo+foo%20bar")
    end

    # reserved characters are different for each part
    # https://web.archive.org/web/20151229061347/http://blog.lunatech.com/2009/02/03/what-every-web-developer-must-know-about-url-encoding#Thereservedcharactersaredifferentforeachpart
    # "?" is allowed unescaped anywhere within a query part,
    # "/" is allowed unescaped anywhere within a query part,
    # "=" is allowed unescaped anywhere within a path parameter or query parameter value, and within a path segment,
    # ":@-._~!$&'()*+,;=" are allowed unescaped anywhere within a path segment part,
    # "/?:@-._~!$&'()*+,;=" are allowed unescaped anywhere within a fragment part.
    it "should properly URI encode + and space in path and query" do
      path = "/foo+foo bar?foo+foo bar"
      uri = Puppet::Util.path_to_uri(path)

      expected_encoding = Encoding::UTF_8
      expect(uri.to_s.encoding).to eq(expected_encoding)
      expect(uri.path).to eq("/foo+foo%20bar")
      # either + or %20 is correct for an encoded space in query
      # + is usually used for backward compatibility, but %20 is preferred for compat with Puppet::Util.uri_unescape
      expect(uri.query).to eq("foo%2Bfoo%20bar")
      # complete roundtrip
      expect(Puppet::Util.uri_unescape(uri.to_s).sub(%r{^file:(//)?}, '')).to eq(path)
      expect(Puppet::Util.uri_unescape(uri.to_s).encoding).to eq(expected_encoding)
    end

    it "should perform UTF-8 URI escaping" do
      uri = Puppet::Util.path_to_uri("/#{mixed_utf8}")

      expect(uri.path.encoding).to eq(Encoding::UTF_8)
      expect(uri.path).to eq("/#{mixed_utf8_urlencoded}")
    end

    describe "when using platform :posix" do
      before :each do
        allow(Puppet.features).to receive(:posix?).and_return(true)
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)
      end

      %w[/ /foo /foo/../bar].each do |path|
        it "should convert #{path} to URI" do
          expect(Puppet::Util.path_to_uri(path).path).to eq(path)
        end
      end
    end

    describe "when using platform :windows" do
      before :each do
        allow(Puppet.features).to receive(:posix?).and_return(false)
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(true)
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
          expect(uri.path).to eq('/' + Puppet::Util.uri_encode(path))
        end
      end
    end
  end

  describe "#uri_query_encode" do
    # different UTF-8 widths
    # 1-byte A
    # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
    # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
    # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
    let (:mixed_utf8) { "A\u06FF\u16A0\u{2070E}" } # Aۿᚠ𠜎
    let (:mixed_utf8_urlencoded) { "A%DB%BF%E1%9A%A0%F0%A0%9C%8E" }

    it "should perform basic URI escaping that includes space and +" do
      expect(Puppet::Util.uri_query_encode("foo bar+foo")).to eq("foo%20bar%2Bfoo")
    end

    it "should URI encode any special characters: = + <space> & * and #" do
      expect(Puppet::Util.uri_query_encode("foo=bar+foo baz&bar=baz qux&special= *&qux=not fragment#")).to eq("foo%3Dbar%2Bfoo%20baz%26bar%3Dbaz%20qux%26special%3D%20%2A%26qux%3Dnot%20fragment%23")
    end

    [
      "A\u06FF\u16A0\u{2070E}",
      "A\u06FF\u16A0\u{2070E}".force_encoding(Encoding::BINARY)
    ].each do |uri_string|
      it "should perform UTF-8 URI escaping, even when input strings are not UTF-8" do
        uri = Puppet::Util.uri_query_encode(mixed_utf8)

        expect(uri.encoding).to eq(Encoding::UTF_8)
        expect(uri).to eq(mixed_utf8_urlencoded)
      end
    end

    it "should be usable by URI::parse" do
      uri = URI::parse("puppet://server/path?" + Puppet::Util.uri_query_encode(mixed_utf8))

      expect(uri.scheme).to eq('puppet')
      expect(uri.host).to eq('server')
      expect(uri.path).to eq('/path')
      expect(uri.query).to eq(mixed_utf8_urlencoded)
    end

    it "should be usable by URI::Generic.build" do
      params = {
        :scheme => 'file',
        :host => 'foobar',
        :path => '/path/to',
        :query => Puppet::Util.uri_query_encode(mixed_utf8)
      }

      uri = URI::Generic.build(params)

      expect(uri.scheme).to eq('file')
      expect(uri.host).to eq('foobar')
      expect(uri.path).to eq("/path/to")
      expect(uri.query).to eq(mixed_utf8_urlencoded)
    end
  end

  describe "#uri_encode" do
    # different UTF-8 widths
    # 1-byte A
    # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
    # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
    # 4-byte ܎ - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
    let (:mixed_utf8) { "A\u06FF\u16A0\u{2070E}" } # Aۿᚠ܎
    let (:mixed_utf8_urlencoded) { "A%DB%BF%E1%9A%A0%F0%A0%9C%8E" }

    it "should perform URI escaping" do
      expect(Puppet::Util.uri_encode("/foo bar")).to eq("/foo%20bar")
    end

    [
      "A\u06FF\u16A0\u{2070E}",
      "A\u06FF\u16A0\u{2070E}".force_encoding(Encoding::BINARY)
    ].each do |uri_string|
      it "should perform UTF-8 URI escaping, even when input strings are not UTF-8" do
        uri = Puppet::Util.uri_encode(mixed_utf8)

        expect(uri.encoding).to eq(Encoding::UTF_8)
        expect(uri).to eq(mixed_utf8_urlencoded)
      end
    end

    it "should treat & and = as delimiters in a query string, but URI encode other special characters: + <space> * and #" do
      input = "http://foo.bar.com/path?foo=bar+foo baz&bar=baz qux&special= *&qux=not fragment#"
      expected_output = "http://foo.bar.com/path?foo=bar%2Bfoo%20baz&bar=baz%20qux&special=%20%2A&qux=not%20fragment%23"
      expect(Puppet::Util.uri_encode(input)).to eq(expected_output)
    end

    it "should be usable by URI::parse" do
      uri = URI::parse(Puppet::Util.uri_encode("puppet://server/path/to/#{mixed_utf8}"))

      expect(uri.scheme).to eq('puppet')
      expect(uri.host).to eq('server')
      expect(uri.path).to eq("/path/to/#{mixed_utf8_urlencoded}")
    end

    it "should be usable by URI::Generic.build" do
      params = {
        :scheme => 'file',
        :host => 'foobar',
        :path => Puppet::Util.uri_encode("/path/to/#{mixed_utf8}")
      }

      uri = URI::Generic.build(params)

      expect(uri.scheme).to eq('file')
      expect(uri.host).to eq('foobar')
      expect(uri.path).to eq("/path/to/#{mixed_utf8_urlencoded}")
    end

    describe "when using platform :posix" do
      before :each do
        allow(Puppet.features).to receive(:posix?).and_return(true)
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)
      end

      %w[/ /foo /foo/../bar].each do |path|
        it "should not replace / in #{path} with %2F" do
          expect(Puppet::Util.uri_encode(path)).to eq(path)
        end
      end
    end

    describe "with fragment support" do
      context "disabled by default" do
        it "should encode # as %23 in path" do
          encoded = Puppet::Util.uri_encode("/foo bar#fragment")
          expect(encoded).to eq("/foo%20bar%23fragment")
        end

        it "should encode # as %23 in query" do
          encoded = Puppet::Util.uri_encode("/foo bar?baz+qux#fragment")
          expect(encoded).to eq("/foo%20bar?baz%2Bqux%23fragment")
        end
      end

      context "optionally enabled" do
        it "should leave fragment delimiter # after encoded paths" do
          encoded = Puppet::Util.uri_encode("/foo bar#fragment", { :allow_fragment => true })
          expect(encoded).to eq("/foo%20bar#fragment")
        end

        it "should leave fragment delimiter # after encoded query" do
          encoded = Puppet::Util.uri_encode("/foo bar?baz+qux#fragment", { :allow_fragment => true })
          expect(encoded).to eq("/foo%20bar?baz%2Bqux#fragment")
        end
      end
    end

    describe "when using platform :windows" do
      before :each do
        allow(Puppet.features).to receive(:posix?).and_return(false)
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(true)
      end

      it "should url encode \\ as %5C, but not replace : as %3F" do
        expect(Puppet::Util.uri_encode('c:\\foo\\bar\\baz')).to eq('c:%5Cfoo%5Cbar%5Cbaz')
      end

      %w[C:/ C:/foo/bar].each do |path|
        it "should not replace / in #{path} with %2F" do
          expect(Puppet::Util.uri_encode(path)).to eq(path)
        end
      end
    end
  end

  describe ".uri_to_path" do
    require 'uri'

    # different UTF-8 widths
    # 1-byte A
    # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
    # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
    # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
    let (:mixed_utf8) { "A\u06FF\u16A0\u{2070E}" } # Aۿᚠ𠜎

    it "should strip host component" do
      expect(Puppet::Util.uri_to_path(URI.parse('http://foo/bar'))).to eq('/bar')
    end

    it "should accept puppet URLs" do
      expect(Puppet::Util.uri_to_path(URI.parse('puppet:///modules/foo'))).to eq('/modules/foo')
    end

    it "should return unencoded path" do
      expect(Puppet::Util.uri_to_path(URI.parse('http://foo/bar%20baz'))).to eq('/bar baz')
    end

    [
      "http://foo/A%DB%BF%E1%9A%A0%F0%A0%9C%8E",
      "http://foo/A%DB%BF%E1%9A%A0%F0%A0%9C%8E".force_encoding(Encoding::ASCII)
    ].each do |uri_string|
      it "should return paths as UTF-8" do
        path = Puppet::Util.uri_to_path(URI.parse(uri_string))

        expect(path).to eq("/#{mixed_utf8}")
        expect(path.encoding).to eq(Encoding::UTF_8)
      end
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

    describe "when using platform :windows", :if => Puppet::Util::Platform.windows? do
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

  describe "safe_posix_fork on Windows and JRuby", if: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
    it "raises not implemented error" do
      expect {
        Puppet::Util.safe_posix_fork
      }.to raise_error(NotImplementedError, /fork/)
    end
  end

  describe "safe_posix_fork", unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
    let(:pid) { 5501 }

    before :each do
      # Most of the things this method does are bad to do during specs. :/
      allow(Kernel).to receive(:fork).and_return(pid).and_yield

      allow($stdin).to receive(:reopen)
      allow($stdout).to receive(:reopen)
      allow($stderr).to receive(:reopen)

      # ensure that we don't really close anything!
      allow(IO).to receive(:new)
    end

    it "should close all open file descriptors except stdin/stdout/stderr when /proc/self/fd exists" do
      # This is ugly, but I can't really think of a better way to do it without
      # letting it actually close fds, which seems risky
      fds = [".", "..","0","1","2","3","5","100","1000"]
      fds.each do |fd|
        if fd == '.' || fd == '..'
          next
        elsif ['0', '1', '2'].include? fd
          expect(IO).not_to receive(:new).with(fd.to_i)
        else
          expect(IO).to receive(:new).with(fd.to_i).and_return(double('io', close: nil))
        end
      end

      dir_expectation = receive(:foreach).with('/proc/self/fd')
      fds.each do |fd|
        dir_expectation = dir_expectation.and_yield(fd)
      end
      allow(Dir).to dir_expectation
      Puppet::Util.safe_posix_fork
    end

    it "should close all open file descriptors except stdin/stdout/stderr when /proc/self/fd doesn't exist" do
      # This is ugly, but I can't really think of a better way to do it without
      # letting it actually close fds, which seems risky
      (0..2).each {|n| expect(IO).not_to receive(:new).with(n)}
      (3..256).each {|n| expect(IO).to receive(:new).with(n).and_return(double('io', close: nil))  }
      allow(Dir).to receive(:foreach).with('/proc/self/fd').and_raise(Errno::ENOENT)

      Puppet::Util.safe_posix_fork
    end

    it "should close all open file descriptors except stdin/stdout/stderr when /proc/self is not a directory" do
      # This is ugly, but I can't really think of a better way to do it without
      # letting it actually close fds, which seems risky
      (0..2).each {|n| expect(IO).not_to receive(:new).with(n)}
      (3..256).each {|n| expect(IO).to receive(:new).with(n).and_return(double('io', close: nil))  }
      allow(Dir).to receive(:foreach).with('/proc/self/fd').and_raise(Errno::ENOTDIR)

      Puppet::Util.safe_posix_fork
    end

    it "should fork a child process to execute the block" do
      expect(Kernel).to receive(:fork).and_return(pid).and_yield

      Puppet::Util.safe_posix_fork do
        "Fork this!"
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
      allow(FileTest).to receive(:file?).and_return(false)
      allow(FileTest).to receive(:file?).with(path).and_return(true)

      allow(FileTest).to receive(:executable?).and_return(false)
      allow(FileTest).to receive(:executable?).with(path).and_return(true)
    end

    it "should accept absolute paths" do
      expect(Puppet::Util.which(path)).to eq(path)
    end

    it "should return nil if no executable found" do
      expect(Puppet::Util.which('doesnotexist')).to be_nil
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
        allow(Puppet.features).to receive(:posix?).and_return(true)
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)
      end

      it "should walk the search PATH returning the first executable" do
        allow(ENV).to receive(:[]).with('PATH').and_return(File.expand_path('/bin'))
        allow(ENV).to receive(:[]).with('PATHEXT').and_return(nil)

        expect(Puppet::Util.which('foo')).to eq(path)
      end
    end

    describe "on Windows systems" do
      let(:path) { File.expand_path(File.join(base, 'foo.CMD')) }

      before :each do
        allow(Puppet.features).to receive(:posix?).and_return(false)
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(true)
      end

      describe "when a file extension is specified" do
        it "should walk each directory in PATH ignoring PATHEXT" do
          allow(ENV).to receive(:[]).with('PATH').and_return(%w[/bar /bin].map{|dir| File.expand_path(dir)}.join(File::PATH_SEPARATOR))
          allow(ENV).to receive(:[]).with('PATHEXT').and_return('.FOOBAR')

          expect(FileTest).to receive(:file?).with(File.join(File.expand_path('/bar'), 'foo.CMD')).and_return(false)

          expect(Puppet::Util.which('foo.CMD')).to eq(path)
        end
      end

      describe "when a file extension is not specified" do
        it "should walk each extension in PATHEXT until an executable is found" do
          bar = File.expand_path('/bar')
          allow(ENV).to receive(:[]).with('PATH').and_return("#{bar}#{File::PATH_SEPARATOR}#{base}")
          allow(ENV).to receive(:[]).with('PATHEXT').and_return(".EXE#{File::PATH_SEPARATOR}.CMD")

          expect(FileTest).to receive(:file?).ordered().with(File.join(bar, 'foo.EXE')).and_return(false)
          expect(FileTest).to receive(:file?).ordered().with(File.join(bar, 'foo.CMD')).and_return(false)
          expect(FileTest).to receive(:file?).ordered().with(File.join(base, 'foo.EXE')).and_return(false)
          expect(FileTest).to receive(:file?).ordered().with(path).and_return(true)

          expect(Puppet::Util.which('foo')).to eq(path)
        end

        it "should walk the default extension path if the environment variable is not defined" do
          allow(ENV).to receive(:[]).with('PATH').and_return(base)
          allow(ENV).to receive(:[]).with('PATHEXT').and_return(nil)

          %w[.COM .EXE .BAT].each do |ext|
            expect(FileTest).to receive(:file?).ordered().with(File.join(base, "foo#{ext}")).and_return(false)
          end
          expect(FileTest).to receive(:file?).ordered().with(path).and_return(true)

          expect(Puppet::Util.which('foo')).to eq(path)
        end

        it "should fall back if no extension matches" do
          allow(ENV).to receive(:[]).with('PATH').and_return(base)
          allow(ENV).to receive(:[]).with('PATHEXT').and_return(".EXE")

          allow(FileTest).to receive(:file?).with(File.join(base, 'foo.EXE')).and_return(false)
          allow(FileTest).to receive(:file?).with(File.join(base, 'foo')).and_return(true)
          allow(FileTest).to receive(:executable?).with(File.join(base, 'foo')).and_return(true)

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
      expect { subject.replace_file(target.path, 0600) }.to raise_error(/block/)
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
    modes += [0600, 0700] unless Puppet::Util::Platform.windows?
    modes.each do |mode|
      it "should copy 0#{mode.to_s(8)} permissions from the target file by default" do
        set_mode(mode, target.path)

        expect(get_mode(target.path)).to eq(mode)

        subject.replace_file(target.path, 0000) {|fh| fh.puts "bazam" }

        expect(get_mode(target.path)).to eq(mode)
        expect(File.read(target.path)).to eq("bazam\n")
      end
    end

    it "should copy the permissions of the source file after yielding on Unix", :if => !Puppet::Util::Platform.windows? do
      set_mode(0555, target.path)
      inode = Puppet::FileSystem.stat(target.path).ino

      yielded = false
      subject.replace_file(target.path, 0660) do |fh|
        expect(get_mode(fh.path)).to eq(0600)
        yielded = true
      end
      expect(yielded).to be_truthy

      expect(Puppet::FileSystem.stat(target.path).ino).not_to eq(inode)
      expect(get_mode(target.path)).to eq(0555)
    end

    it "should be able to create a new file with read-only permissions when it doesn't already exist" do
      temp_file = Tempfile.new('puppet-util-replace-file')
      temp_path = temp_file.path
      temp_file.close
      temp_file.unlink

      subject.replace_file(temp_path, 0440) do |fh|
        fh.puts('some text in there')
      end

      expect(File.read(temp_path)).to eq("some text in there\n")
      expect(get_mode(temp_path)).to eq(0440)
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

    it "should use a temporary staging location if provided" do
      new_target = File.join(tmpdir('new_file'), 'new_file.baz')
      staging_target = tmpdir('staging_file')

      subject.replace_file(new_target, 0555, staging_location: staging_target) do |fh|
        expect(File.dirname(fh.path)).to eq(staging_target)
          fh.puts "foo"
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

    it "should not fiddle with the global seed" do
      srand(1234)
      Puppet::Util.deterministic_rand(123,20)
      expect(srand()).to eql(1234)
    end
  end
end
