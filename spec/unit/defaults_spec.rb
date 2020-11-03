require 'spec_helper'
require 'puppet/settings'

describe "Defaults" do
  describe ".default_diffargs" do
    describe "on AIX" do
      before(:each) do
        allow(Facter).to receive(:value).with(:kernel).and_return("AIX")
      end

      describe "on 5.3" do
        before(:each) do
          allow(Facter).to receive(:value).with(:kernelmajversion).and_return("5300")
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
            allow(Facter).to receive(:value).with(:kernelmajversion).and_return(kernel_version)
          end

          it "should be '-u'" do
            expect(Puppet.default_diffargs).to eq("-u")
          end
        end
      end
    end

    describe "on everything else" do
      before(:each) do
        allow(Facter).to receive(:value).with(:kernel).and_return("NOT_AIX")
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
    it 'defaults to sha256 when FIPS is not enabled' do
      allow(Puppet::Util::Platform).to receive(:fips_enabled?).and_return(false)
      expect(Puppet.default_digest_algorithm).to eq('sha256')
    end

    it 'defaults to sha256 when FIPS is enabled' do
      allow(Puppet::Util::Platform).to receive(:fips_enabled?).and_return(true)
      expect(Puppet.default_digest_algorithm).to eq('sha256')
    end
  end

  describe '.supported_checksum_types' do
    it 'defaults to sha256, sha384, sha512, sha224, md5 when FIPS is not enabled' do
      allow(Puppet::Util::Platform).to receive(:fips_enabled?).and_return(false)
      expect(Puppet.default_file_checksum_types).to eq(%w[sha256 sha384 sha512 sha224 md5])
    end

    it 'defaults to sha256, sha384, sha512, sha224 when FIPS is enabled' do
      allow(Puppet::Util::Platform).to receive(:fips_enabled?).and_return(true)
      expect(Puppet.default_file_checksum_types).to eq(%w[sha256 sha384 sha512 sha224])
    end
  end

  describe 'Puppet[:supported_checksum_types]' do
    it 'defaults to sha256, sha512, sha384, sha224, md5' do
      expect(Puppet.settings[:supported_checksum_types]).to eq(%w[sha256 sha384 sha512 sha224 md5])
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
      allow(Puppet::Util::Platform).to receive(:fips_enabled?).and_return(true)
      expect {
        Puppet.settings[:supported_checksum_types] = %w[md5]
      }.to raise_error(ArgumentError,
                       /Invalid value 'md5' for parameter supported_checksum_types. Allowed values are 'sha256'/)
    end
  end

  describe 'manage_internal_file_permissions' do
    describe 'on windows', :if => Puppet::Util::Platform.windows? do
      it 'should default to false' do
        expect(Puppet.settings[:manage_internal_file_permissions]).to be false
      end
    end

    describe 'on non-windows', :if => ! Puppet::Util::Platform.windows? do
      it 'should default to true' do
        expect(Puppet.settings[:manage_internal_file_permissions]).to be true
      end
    end
  end

  describe 'basemodulepath' do
    it 'includes the user and system modules', :unless => Puppet::Util::Platform.windows? do
      expect(
        Puppet[:basemodulepath]
      ).to match(%r{.*/code/modules:/opt/puppetlabs/puppet/modules$})
    end

    describe 'on windows', :if => Puppet::Util::Platform.windows? do
      let(:installdir) { 'C:\Program Files\Puppet Labs\Puppet' }

      it 'includes user and system modules' do
        allow(ENV).to receive(:[]).with("FACTER_env_windows_installdir").and_return(installdir)

        expect(
          Puppet.default_basemodulepath
        ).to eq('$codedir/modules;C:\Program Files\Puppet Labs\Puppet/puppet/modules')
      end

      it 'includes user modules if installdir fact is missing' do
        allow(ENV).to receive(:[]).with("FACTER_env_windows_installdir").and_return(nil)

        expect(
          Puppet.default_basemodulepath
        ).to eq('$codedir/modules')
      end
    end
  end

  describe 'vendormoduledir' do
    it 'includes the default vendormoduledir', :unless => Puppet::Util::Platform.windows? do
      expect(
        Puppet[:vendormoduledir]
      ).to eq('/opt/puppetlabs/puppet/vendor_modules')
    end

    describe 'on windows', :if => Puppet::Util::Platform.windows? do
      let(:installdir) { 'C:\Program Files\Puppet Labs\Puppet' }

      it 'includes the default vendormoduledir' do
        allow(ENV).to receive(:[]).with("FACTER_env_windows_installdir").and_return(installdir)

        expect(
          Puppet.default_vendormoduledir
        ).to eq('C:\Program Files\Puppet Labs\Puppet\puppet\vendor_modules')
      end

      it 'is nil if installdir fact is missing' do
        allow(ENV).to receive(:[]).with("FACTER_env_windows_installdir").and_return(nil)

        expect(Puppet.default_vendormoduledir).to be_nil
      end
    end
  end

  describe "deprecated settings" do
    it 'does not issue a deprecation warning by default' do
      expect(Puppet).to receive(:deprecation_warning).never

      Puppet.initialize_settings
    end
  end

  describe "the call hook for the cadir setting", unless: Puppet::Util::Platform.windows? do
    it 'does not warn when the cadir is outside the puppet ssldir' do
      FileUtils.mkdir_p(Puppet[:confdir])
      # This is fun; in order to get the confdir setting from the spec_helper to
      # not be deleted by the #unsafe_clear in Puppet::Settings#parse_config,
      # we can code it into the confdir itself, and thus we can avoid getting
      # that setting wiped out during Puppet.initialize_settings.
      File.write(File.join(Puppet[:confdir], 'puppet.conf'),
                 "cadir = /my/cool/path/for/my/cadir\n
                  confdir = #{Puppet[:confdir]}")
      expect(Puppet).to_not receive(:log_ca_migration_warning)
      Puppet.initialize_settings
      expect(Puppet[:cadir]).to eq("/my/cool/path/for/my/cadir")
    end

    it 'does warn when the cadir is inside the puppet ssldir' do
      FileUtils.mkdir_p(Puppet[:confdir])
      cadir_location = File.join(Puppet[:ssldir], 'still_inside_ssldir')
      # This is fun; in order to get the confdir setting from the spec_helper to
      # not be deleted by the #unsafe_clear in Puppet::Settings#parse_config,
      # we can code it into the confdir itself, and thus we can avoid getting
      # that setting wiped out during Puppet.initialize_settings.
      File.write(File.join(Puppet[:confdir], 'puppet.conf'),
                 "cadir = #{cadir_location}\n
                  confdir = #{Puppet[:confdir]}")
      expect(Puppet).to receive(:log_ca_migration_warning).twice
      Puppet.initialize_settings
      expect(Puppet[:cadir]).to eq(cadir_location)
      end
  end

  describe "the default cadir", :unless => Puppet::Util::Platform.windows?  do
    it 'defaults to the puppetserver confdir' do
      Puppet.initialize_settings
      expect(Puppet[:cadir]).to eq('/etc/puppetlabs/puppetserver/ca')
    end

    it 'returns an empty string for Windows platforms', :if => Puppet::Util::Platform.windows? do
      Puppet.initialize_settings
      expect(Puppet[:cadir]).to eq("")
    end
  end

  describe '#default_cadir', :unless => Puppet::Util::Platform.windows?  do
    it 'returns the new puppetserver directory when no ca dir is present' do
      expect(Puppet).to_not receive(:log_ca_migration_warning)
      expect(Puppet.default_cadir).to eq('/etc/puppetlabs/puppetserver/ca')
    end

    it 'warns when a CA dir exists in the current ssldir' do
      cadir = File.join(Puppet[:ssldir], 'ca')
      FileUtils.mkdir_p(cadir)
      expect(Puppet).to receive(:log_ca_migration_warning)
      expect(Puppet.default_cadir).to eq(cadir)
    end

    it 'warns when the cadir is a symlink still inside the ssldir' do
      another_dir = File.join(Puppet[:ssldir], 'another_dir')
      cadir = File.join(Puppet[:ssldir], 'ca')
      FileUtils.mkdir_p(another_dir)
      File.symlink(another_dir, cadir)
      expect(Puppet).to receive(:log_ca_migration_warning)
      expect(Puppet.default_cadir).to eq(another_dir)
    end

    it 'does not warn when the cadir is a symlink targeted outside the ssldir' do
      another_dir = Dir.mktmpdir
      cadir = File.join(Puppet[:ssldir], 'ca')
      FileUtils.mkdir_p(Puppet[:ssldir])
      File.symlink(another_dir, cadir)
      expect(Puppet).to_not receive(:log_ca_migration_warning)
      expect(Puppet.default_cadir).to eq(another_dir)
    end
  end
end
