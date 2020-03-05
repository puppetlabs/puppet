require 'spec_helper'
require 'puppet/util/package/version/range'

class IntegerVersion
  class ValidationFailure < ArgumentError; end
  include Comparable
  REGEX_FULL    = '(\d+)'.freeze
  REGEX_FULL_RX = /\A#{REGEX_FULL}\Z/.freeze

  def self.parse(ver)
    match, version = *ver.match(REGEX_FULL_RX)
    raise ValidationFailure, "Unable to parse '#{ver}' as a version identifier" unless match

    new(version).freeze
  end

  attr_reader :version

  def initialize(version)
    @version = version.to_i
  end

  def <=>(other)
    @version <=> other.version
  end
end

describe Puppet::Util::Package::Version::Range do
  context 'when creating new version range' do
    it 'should raise unless String is passed' do
      expect { Puppet::Util::Package::Version::Range.parse(:abc, IntegerVersion) }.to raise_error(Puppet::Util::Package::Version::Range::ValidationFailure)
    end
    it 'should raise if operator is not implemented' do
      expect { Puppet::Util::Package::Version::Range.parse('=a', IntegerVersion) }.to raise_error(Puppet::Util::Package::Version::Range::ValidationFailure)
    end
    it 'should raise if operator cannot be parsed' do
      expect { Puppet::Util::Package::Version::Range.parse('~=a', IntegerVersion) }.to raise_error(Puppet::Util::Package::Version::Range::ValidationFailure)
    end
    it 'should raise if version cannot be parsed' do
      expect { Puppet::Util::Package::Version::Range.parse('>=a', IntegerVersion) }.to raise_error(IntegerVersion::ValidationFailure)
    end
  end
  context 'when creating new version range with greater or equal operator' do
    it 'it includes greater version' do
      vr = Puppet::Util::Package::Version::Range.parse('>=3', IntegerVersion)
      v = IntegerVersion.parse('4')
      expect(vr.include?(v)).to eql(true)
    end

    it 'it includes specified version' do
      vr = Puppet::Util::Package::Version::Range.parse('>=3', IntegerVersion)
      v = IntegerVersion.parse('3')
      expect(vr.include?(v)).to eql(true)
    end

    it 'it does not include lower version' do
      vr = Puppet::Util::Package::Version::Range.parse('>=3', IntegerVersion)
      v = IntegerVersion.parse('2')
      expect(vr.include?(v)).to eql(false)
    end
  end

  context 'when creating new version range with greater operator' do
    it 'it includes greater version' do
      vr = Puppet::Util::Package::Version::Range.parse('>3', IntegerVersion)
      v = IntegerVersion.parse('10')
      expect(vr.include?(v)).to eql(true)
    end

    it 'it does not include specified version' do
      vr = Puppet::Util::Package::Version::Range.parse('>3', IntegerVersion)
      v = IntegerVersion.parse('3')
      expect(vr.include?(v)).to eql(false)
    end

    it 'it does not include lower version' do
      vr = Puppet::Util::Package::Version::Range.parse('>3', IntegerVersion)
      v = IntegerVersion.parse('1')
      expect(vr.include?(v)).to eql(false)
    end
  end

  context 'when creating new version range with lower or equal operator' do
    it 'it does not include greater version' do
      vr = Puppet::Util::Package::Version::Range.parse('<=3', IntegerVersion)
      v = IntegerVersion.parse('5')
      expect(vr.include?(v)).to eql(false)
    end

    it 'it includes specified version' do
      vr = Puppet::Util::Package::Version::Range.parse('<=3', IntegerVersion)
      v = IntegerVersion.parse('3')
      expect(vr.include?(v)).to eql(true)
    end

    it 'it includes lower version' do
      vr = Puppet::Util::Package::Version::Range.parse('<=3', IntegerVersion)
      v = IntegerVersion.parse('1')
      expect(vr.include?(v)).to eql(true)
    end
  end

  context 'when creating new version range with lower operator' do
    it 'it does not include greater version' do
      vr = Puppet::Util::Package::Version::Range.parse('<3', IntegerVersion)
      v = IntegerVersion.parse('8')
      expect(vr.include?(v)).to eql(false)
    end

    it 'it does not include specified version' do
      vr = Puppet::Util::Package::Version::Range.parse('<3', IntegerVersion)
      v = IntegerVersion.parse('3')
      expect(vr.include?(v)).to eql(false)
    end

    it 'it includes lower version' do
      vr = Puppet::Util::Package::Version::Range.parse('<3', IntegerVersion)
      v = IntegerVersion.parse('2')
      expect(vr.include?(v)).to eql(true)
    end
  end

  context 'when creating new version range with interval' do
    it 'it does not include greater version' do
      vr = Puppet::Util::Package::Version::Range.parse('>3 <=5', IntegerVersion)
      v = IntegerVersion.parse('7')
      expect(vr.include?(v)).to eql(false)
    end

    it 'it includes specified max interval value' do
      vr = Puppet::Util::Package::Version::Range.parse('>3 <=5', IntegerVersion)
      v = IntegerVersion.parse('5')
      expect(vr.include?(v)).to eql(true)
    end

    it 'it includes in interval version' do
      vr = Puppet::Util::Package::Version::Range.parse('>3 <=5', IntegerVersion)
      v = IntegerVersion.parse('4')
      expect(vr.include?(v)).to eql(true)
    end

    it 'it does not include min interval value ' do
      vr = Puppet::Util::Package::Version::Range.parse('>3 <=5', IntegerVersion)
      v = IntegerVersion.parse('3')
      expect(vr.include?(v)).to eql(false)
    end

    it 'it does not include lower value ' do
      vr = Puppet::Util::Package::Version::Range.parse('>3 <=5', IntegerVersion)
      v = IntegerVersion.parse('2')
      expect(vr.include?(v)).to eql(false)
    end
  end
end
