#!/usr/bin/env ruby

require 'spec_helper'

describe Puppet::Util do
  include PuppetSpec::Files

  # Discriminator for tests that attempts to unset HOME since that, for reasons currently unknown,
  # doesn't work in Ruby >= 2.4.0
  def self.gte_ruby_2_4
    @gte_ruby_2_4 ||= SemanticPuppet::Version.parse(RUBY_VERSION) >= SemanticPuppet::Version.parse('2.4.0')
  end

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

    # document buggy Ruby behavior here for https://bugs.ruby-lang.org/issues/8822
    # Ruby retrieves / stores ENV names in the current codepage
    # when these tests no longer pass, Ruby has fixed its bugs and workarounds can be removed


    # interestingly we would expect some of these tests to fail when codepage is 65001
    # but instead the env values are in Encoding::ASCII_8BIT!
    it "works around Ruby bug 8822 (which fails to preserve UTF-8 properly when accessing ENV) (Ruby <= 2.1) ",
      :if => ((RUBY_VERSION =~ /^(1\.|2\.0\.|2\.1\.)/) && Puppet.features.microsoft_windows?) do

      withenv_utf8 do |utf_8_key, utf_8_value, codepage_key|
        # both a string in UTF-8 and current codepage are deemed valid keys to the hash
        # which is because Ruby compares the BINARY versions of the string, but ignores encoding
        expect(ENV.key?(codepage_key)).to eq(true)
        expect(ENV.key?(utf_8_key)).to eq(true)

        # Ruby's ENV.keys has slightly different behavior than ENV.key?(key)
        # the keys collection in 2.1 has a string with the correct bytes
        # (codepage_key / utf_8_key have same bytes for the sake of searching)
        found = ENV.keys.find { |k| k.bytes == codepage_key.bytes }
        # but the string is actually a binary string
        expect(found.encoding).to eq(Encoding::BINARY)
        # meaning we can't use include? to find it in either UTF-8 or codepage encoding
        expect(ENV.keys.include?(codepage_key)).to eq(false)
        expect(ENV.keys.include?(utf_8_key)).to eq(false)

        # and can only search with a BINARY encoded string
        expect(ENV.keys.include?(utf_8_key.dup.force_encoding(Encoding::BINARY))).to eq(true)

        # similarly the value stored at the real key is in current codepage
        # but won't match real UTF-8 value
        env_value = ENV[utf_8_key]
        expect(env_value).to_not eq(utf_8_value)
        expect(env_value.encoding).to_not eq(Encoding::UTF_8)

        # but it can be forced back to UTF-8 to make it match.. ugh
        converted_value = ENV[utf_8_key].dup.force_encoding(Encoding::UTF_8)
        expect(converted_value).to eq(utf_8_value)
      end
    end

    # but in 2.3, the behavior is mostly correct when external codepage is 65001 / UTF-8
    it "works around Ruby bug 8822 (which fails to preserve UTF-8 properly when accessing ENV) (Ruby >= 2.3.x) ",
      :if => ((match = RUBY_VERSION.match(/^2\.(\d+)\./)) && match.captures[0].to_i >= 3 && Puppet.features.microsoft_windows?) do

      raise 'This test requires a non-UTF8 codepage' if Encoding.default_external == Encoding::UTF_8

      withenv_utf8 do |utf_8_key, utf_8_value, codepage_key|
        # Ruby 2.3 fixes access by the original UTF-8 key, and behaves differently than 2.1
        # keying by local codepage will work only when the UTF-8 can be converted to local codepage
        # the key selected for this test contains characters unavailable to a local codepage, hence doesn't work

        # On Japanese Windows (Code Page 932) this test resolves as true.
        # otherwise the key selected for this test contains characters
        # unavailable to a local codepage, hence doesn't work
        # HACK: tech debt to replace once PUP-7019 is understood
        should_be_found = (Encoding.default_external == Encoding::CP932)
        expect(ENV.key?(codepage_key)).to eq(should_be_found)
        expect(ENV.key?(utf_8_key)).to eq(true)

        # Ruby's ENV.keys has slightly different behavior than ENV.key?(key), and 2.3 differs from 2.1
        # (codepage_key / utf_8_key have same bytes for the sake of searching)
        found = ENV.keys.find { |k| k.bytes == codepage_key.bytes }

        # the keys collection in 2.3 does not have a string with the correct bytes!
        # a corrupt version of the key exists with the bytes [225, 154, 160] replaced with [63]!
        expect(found).to be_nil

        # given the key is corrupted, include? cannot be used to find it in either UTF-8 or codepage encoding
        expect(ENV.keys.include?(codepage_key)).to eq(false)
        expect(ENV.keys.include?(utf_8_key)).to eq(false)

        # The value stored at the UTF-8 key is a corrupted current codepage string and won't match UTF-8 value
        # again the bytes [225, 154, 160] have irreversibly been changed to [63]!
        env_value = ENV[utf_8_key]
        expect(env_value).to_not eq(utf_8_value)
        expect(env_value.encoding).to_not eq(Encoding::UTF_8)

        # the ENV value returned will be in the local codepage which may or may not be able to be
        # encoded to UTF8.  Our test UTF8 data is not convertible to non-Unicode codepages
        converted_value = ENV[utf_8_key].dup.force_encoding(Encoding::UTF_8)
        expect(converted_value).to_not eq(utf_8_value)
      end
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

      # Ruby 1.9.3 URI#to_s has a bug that returns ASCII always
      # despite parts being UTF-8 strings
      expected_encoding = RUBY_VERSION == '1.9.3' ? Encoding::ASCII : Encoding::UTF_8

      expect(uri.to_s.encoding).to eq(expected_encoding)
      expect(uri.path).to eq("/foo+foo%20bar")
      # either + or %20 is correct for an encoded space in query
      # + is usually used for backward compatibility, but %20 is preferred for compat with Uri.unescape
      expect(uri.query).to eq("foo%2Bfoo%20bar")
      # complete roundtrip
      expect(URI.unescape(uri.to_s)).to eq("file:#{path}")
      expect(URI.unescape(uri.to_s).encoding).to eq(expected_encoding)
    end

    it "should perform UTF-8 URI escaping" do
      uri = Puppet::Util.path_to_uri("/#{mixed_utf8}")

      expect(uri.path.encoding).to eq(Encoding::UTF_8)
      expect(uri.path).to eq("/#{mixed_utf8_urlencoded}")
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
        Puppet.features.stubs(:posix).returns true
        Puppet.features.stubs(:microsoft_windows?).returns false
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
        Puppet.features.stubs(:posix).returns false
        Puppet.features.stubs(:microsoft_windows?).returns true
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

    it "should warn if the user's HOME is not set but their PATH contains a ~", :unless => gte_ruby_2_4 do
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

    it "should copy the permissions of the source file after yielding on Unix", :if => !Puppet.features.microsoft_windows? do
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
