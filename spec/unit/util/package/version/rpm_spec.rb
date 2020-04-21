require 'spec_helper'
require 'puppet/util/package/version/rpm'

describe Puppet::Util::Package::Version::Rpm do

  context "when parsing an invalid version" do
    it "raises ArgumentError" do
      expect { described_class.parse(:absent)}.to raise_error(ArgumentError)
    end
  end

  context "when creating new version" do
    it "is parsing basic version" do
      v = described_class.parse('1:2.8.8-1.el6')
      expect([v.epoch, v.version, v.release, v.arch ]).to eq(['1', '2.8.8', '1.el6' , nil])
    end

    it "is parsing no epoch basic version" do
      v = described_class.parse('2.8.8-1.el6')
      expect([v.epoch, v.version, v.release, v.arch ]).to eq([nil, '2.8.8', '1.el6', nil])
    end

    it "is parsing no epoch basic short version" do
      v = described_class.parse('7.15-8.fc29')
      expect([v.epoch, v.version, v.release, v.arch ]).to eq([nil, '7.15', '8.fc29', nil])
    end

    it "is parsing no epoch and no release basic version" do
      v = described_class.parse('2.8.8')
      expect([v.epoch, v.version, v.release, v.arch ]).to eq([nil, '2.8.8', nil, nil])
    end

    it "is parsing no epoch complex version" do
      v = described_class.parse('1.4-0.24.20120830CVS.fc31')
      expect([v.epoch, v.version, v.release, v.arch ]).to eq([nil, '1.4', '0.24.20120830CVS.fc31', nil])
    end
  end

  context "when comparing two versions" do
    context 'with invalid version' do
      it 'raises ArgumentError' do
        version = described_class.parse('0:1.5.3-3.el6')
        invalid = 'invalid'
        expect { version < invalid }.to \
          raise_error(ArgumentError, 'Cannot compare, as invalid is not a Rpm Version')
      end
    end

    context 'with valid versions' do
      it "epoch has precedence" do
        lower = described_class.parse('0:1.5.3-3.el6')
        higher = described_class.parse('1:1.7.0-15.fc29')
        expect(lower).to be < higher
      end

      it 'handles no epoch as 0 epoch' do
        lower = described_class.parse('1.5.3-3.el6')
        higher = described_class.parse('1:1.7.0-15.fc29')
        expect(lower).to be < higher
      end

      it "handles equals letters-only versions" do
        first = described_class.parse('abd-def')
        second = described_class.parse('abd-def')
        expect(first).to eq(second)
      end

      it "shorter version is smaller letters-only versions" do
        lower = described_class.parse('ab')
        higher = described_class.parse('abd')
        expect(lower).to be < higher
      end

      it "shorter version is smaller even with digits" do
        lower = described_class.parse('1.7')
        higher = described_class.parse('1.7.0')
        expect(lower).to be < higher
      end

      it "shorter version is smaller when number is less" do
        lower = described_class.parse('1.7.0')
        higher = described_class.parse('1.7.1')
        expect(lower).to be < higher
      end

      it "shorter release is smaller " do
        lower = described_class.parse('1.7.0-11.fc26')
        higher = described_class.parse('1.7.0-11.fc27')
        expect(lower).to be < higher
      end

      it "release letters are smaller letters-only" do
        lower = described_class.parse('1.7.0-abc')
        higher = described_class.parse('1.7.0-abd')
        expect(lower).to be < higher
      end

      it "shorter release is smaller" do
        lower = described_class.parse('1.7.0-11.fc2')
        higher = described_class.parse('1.7.0-11.fc17')
        expect(lower).to be < higher
      end

      it "handles equal release" do
        first = described_class.parse('1.7.0-11.fc27')
        second = described_class.parse('1.7.0-11.fc27')
        expect(first).to eq(second)
      end
    end

    context 'when one has no epoch' do
      it 'handles no epoch as zero' do
        version1 = described_class.parse('1:1.2')
        version2 = described_class.parse('1.4')

        expect(version1).to be > version2
        expect(version2).to be < version1
      end
    end
  end
end
