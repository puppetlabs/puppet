require 'spec_helper'
require 'puppet/settings'

describe "Defaults" do
  describe ".default_diffargs" do
    describe "on AIX" do
      before(:each) do
        Facter.stubs(:value).with(:kernel).returns("AIX")
      end
      describe "on 5.3" do
        before(:each) do
          Facter.stubs(:value).with(:kernelmajversion).returns("5300")
        end
        it "should be empty" do
          expect(Puppet.default_diffargs).to eq("")
        end
      end
      [ "",
        nil,
        "6300",
        "7300",
      ].each do |kernel_version|
        describe "on kernel version #{kernel_version.inspect}" do
          before(:each) do
            Facter.stubs(:value).with(:kernelmajversion).returns(kernel_version)
          end

          it "should be '-u'" do
            expect(Puppet.default_diffargs).to eq("-u")
          end
        end
      end
    end
    describe "on everything else" do
      before(:each) do
        Facter.stubs(:value).with(:kernel).returns("NOT_AIX")
      end

      it "should be '-u'" do
        expect(Puppet.default_diffargs).to eq("-u")
      end
    end
  end

  describe 'strict' do
    it 'should accept the valid value :off' do
      expect {Puppet.settings[:strict] = 'off'}.to_not raise_exception
    end

    it 'should accept the valid value :warning' do
      expect {Puppet.settings[:strict] = 'warning'}.to_not raise_exception
    end

    it 'should accept the valid value :error' do
      expect {Puppet.settings[:strict] = 'error'}.to_not raise_exception
    end

    it 'should fail if given an invalid value' do
      expect {Puppet.settings[:strict] = 'ignore'}.to raise_exception(/Invalid value 'ignore' for parameter strict\./)
    end
  end

  describe '.default_digest_algorithm' do
    it 'defaults to md5 when FIPS is not enabled' do
      Puppet::Util::Platform.stubs(:fips_enabled?).returns false
      expect(Puppet.default_digest_algorithm).to eq('md5')
    end

    it 'defaults to sha256 when FIPS is enabled' do
      Puppet::Util::Platform.stubs(:fips_enabled?).returns true
      expect(Puppet.default_digest_algorithm).to eq('sha256')
    end
  end

  describe '.supported_checksum_types' do
    it 'defaults to md5, sha256, sha384, sha512, sha224 when FIPS is not enabled' do
      Puppet::Util::Platform.stubs(:fips_enabled?).returns false
      expect(Puppet.default_file_checksum_types).to eq(%w[md5 sha256 sha384 sha512 sha224])
    end

    it 'defaults to sha256, sha384, sha512, sha224 when FIPS is enabled' do
      Puppet::Util::Platform.stubs(:fips_enabled?).returns true
      expect(Puppet.default_file_checksum_types).to eq(%w[sha256 sha384 sha512 sha224])
    end
  end

  describe 'Puppet[:supported_checksum_types]' do
    it 'defaults to md5, sha256, sha512, sha384, sha224' do
      expect(Puppet.settings[:supported_checksum_types]).to eq(%w[md5 sha256 sha384 sha512 sha224])
    end

    it 'should raise an error on an unsupported checksum type' do
      expect {
        Puppet.settings[:supported_checksum_types] = %w[md5 foo]
      }.to raise_exception ArgumentError,
                           /Invalid value 'foo' for parameter supported_checksum_types. Allowed values are/
    end

    it 'should not raise an error on setting a valid list of checksum types' do
      Puppet.settings[:supported_checksum_types] = %w[sha256 md5lite mtime]
      expect(Puppet.settings[:supported_checksum_types]).to eq(%w[sha256 md5lite mtime])
    end

    it 'raises when setting md5 in FIPS mode' do
      Puppet::Util::Platform.stubs(:fips_enabled?).returns true
      expect {
        Puppet.settings[:supported_checksum_types] = %w[md5]
      }.to raise_error(ArgumentError,
                       /Invalid value 'md5' for parameter supported_checksum_types. Allowed values are 'sha256'/)
    end
  end

  describe 'server vs server_list' do
    it 'should warn when both settings are set in code' do
      Puppet.expects(:deprecation_warning).with('Attempted to set both server and server_list. Server setting will not be used.', :SERVER_DUPLICATION)
      Puppet.settings[:server] = 'test_server'
      Puppet.settings[:server_list] = ['one', 'two']
    end

    it 'should warn when both settings are set by command line' do
      Puppet.expects(:deprecation_warning).with('Attempted to set both server and server_list. Server setting will not be used.', :SERVER_DUPLICATION)
      Puppet.settings.handlearg("--server_list", "one,two")
      Puppet.settings.handlearg("--server", "test_server")
    end
  end
end
