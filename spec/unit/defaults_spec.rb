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

  describe 'cfacter' do

    before :each do
      Facter.reset
    end

    it 'should default to false' do
      expect(Puppet.settings[:cfacter]).to be_falsey
    end

    it 'should raise an error if cfacter is not installed' do
      Puppet.features.stubs(:cfacter?).returns false
      expect { Puppet.settings[:cfacter] = true }.to raise_exception ArgumentError, 'cfacter version 0.2.0 or later is not installed.'
    end

    it 'should raise an error if facter has already evaluated facts' do
      Facter[:facterversion]
      Puppet.features.stubs(:cfacter?).returns true
      expect { Puppet.settings[:cfacter] = true }.to raise_exception ArgumentError, 'facter has already evaluated facts.'
    end

    it 'should initialize cfacter when set to true' do
      Puppet.features.stubs(:cfacter?).returns true
      CFacter = mock
      CFacter.stubs(:initialize)
      Puppet.settings[:cfacter] = true
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

  describe 'supported_checksum_types' do
    it 'should default to md5,sha256' do
      expect(Puppet.settings[:supported_checksum_types]).to eq(['md5', 'sha256'])
    end

    it 'should raise an error on an unsupported checksum type' do
      expect { Puppet.settings[:supported_checksum_types] = ['md5', 'foo'] }.to raise_exception ArgumentError, 'Unrecognized checksum types ["foo"] are not supported. Valid values are ["md5", "md5lite", "sha256", "sha256lite", "sha1", "sha1lite", "mtime", "ctime"].'
    end

    it 'should not raise an error on setting a valid list of checksum types' do
      Puppet.settings[:supported_checksum_types] = ['sha256', 'md5lite', 'mtime']
      expect(Puppet.settings[:supported_checksum_types]).to eq(['sha256', 'md5lite', 'mtime'])
    end
  end
end
