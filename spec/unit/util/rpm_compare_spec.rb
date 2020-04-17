# frozen_string_literal: true

require 'spec_helper'
require 'puppet/util/rpm_compare'

describe Puppet::Util::RpmCompare do
  class RpmTest
    extend Puppet::Util::RpmCompare
  end

  describe '.rpmvercmp' do
    # test cases munged directly from rpm's own
    # tests/rpmvercmp.at
    it { expect(RpmTest.rpmvercmp('1.0', '1.0')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('1.0', '2.0')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('2.0', '1.0')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('2.0.1', '2.0.1')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('2.0', '2.0.1')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('2.0.1', '2.0')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('2.0.1a', '2.0.1a')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('2.0.1a', '2.0.1')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('2.0.1', '2.0.1a')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('5.5p1', '5.5p1')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('5.5p1', '5.5p2')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('5.5p2', '5.5p1')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('5.5p10', '5.5p10')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('5.5p1', '5.5p10')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('5.5p10', '5.5p1')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('10xyz', '10.1xyz')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('10.1xyz', '10xyz')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('xyz10', 'xyz10')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('xyz10', 'xyz10.1')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('xyz10.1', 'xyz10')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('xyz.4', 'xyz.4')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('xyz.4', '8')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('8', 'xyz.4')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('xyz.4', '2')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('2', 'xyz.4')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('5.5p2', '5.6p1')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('5.6p1', '5.5p2')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('5.6p1', '6.5p1')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('6.5p1', '5.6p1')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('6.0.rc1', '6.0')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('6.0', '6.0.rc1')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('10b2', '10a1')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('10a2', '10b2')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('1.0aa', '1.0aa')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('1.0a', '1.0aa')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('1.0aa', '1.0a')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('10.0001', '10.0001')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('10.0001', '10.1')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('10.1', '10.0001')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('10.0001', '10.0039')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('10.0039', '10.0001')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('4.999.9', '5.0')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('5.0', '4.999.9')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('20101121', '20101121')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('20101121', '20101122')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('20101122', '20101121')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('2_0', '2_0')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('2.0', '2_0')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('2_0', '2.0')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('a', 'a')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('a+', 'a+')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('a+', 'a_')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('a_', 'a+')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('+a', '+a')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('+a', '_a')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('_a', '+a')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('+_', '+_')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('_+', '+_')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('_+', '_+')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('+', '_')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('_', '+')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('1.0~rc1', '1.0~rc1')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('1.0~rc1', '1.0')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('1.0', '1.0~rc1')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('1.0~rc1', '1.0~rc2')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('1.0~rc2', '1.0~rc1')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('1.0~rc1~git123', '1.0~rc1~git123')).to eq(0) }
    it { expect(RpmTest.rpmvercmp('1.0~rc1~git123', '1.0~rc1')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('1.0~rc1', '1.0~rc1~git123')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('1.0~rc1', '1.0arc1')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('', '~')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('~', '~~')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('~', '~+~')).to eq(1) }
    it { expect(RpmTest.rpmvercmp('~', '~a')).to eq(-1) }

    # non-upstream test cases
    it { expect(RpmTest.rpmvercmp('405', '406')).to eq(-1) }
    it { expect(RpmTest.rpmvercmp('1', '0')).to eq(1) }
  end

  describe '.rpm_compareEVR' do
    it 'evaluates identical version-release as equal' do
      expect(RpmTest.rpm_compareEVR('1.2.3-1.el5', '1.2.3-1.el5')).to eq(0)
    end

    it 'evaluates identical version as equal' do
      expect(RpmTest.rpm_compareEVR('1.2.3', '1.2.3')).to eq(0)
    end

    it 'evaluates identical version but older release as less' do
      expect(RpmTest.rpm_compareEVR('1.2.3-1.el5', '1.2.3-2.el5')).to eq(-1)
    end

    it 'evaluates identical version but newer release as greater' do
      expect(RpmTest.rpm_compareEVR('1.2.3-3.el5', '1.2.3-2.el5')).to eq(1)
    end

    it 'evaluates a newer epoch as greater' do
      expect(RpmTest.rpm_compareEVR('1:1.2.3-4.5', '1.2.3-4.5')).to eq(1)
    end

    # these tests describe PUP-1244 logic yet to be implemented
    it 'evaluates any version as equal to the same version followed by release' do
      expect(RpmTest.rpm_compareEVR('1.2.3', '1.2.3-2.el5')).to eq(0)
    end

    # test cases for PUP-682
    it 'evaluates same-length numeric revisions numerically' do
      expect(RpmTest.rpm_compareEVR('2.2-405', '2.2-406')).to eq(-1)
    end

    it 'treats no epoch as zero epoch' do
      expect(RpmTest.rpm_compareEVR('1:1.2', '1.4')).to eq(-1)
      expect(RpmTest.rpm_compareEVR('1.4', '1:1.2')).to eq(1)
    end
  end

  describe '.rpm_parse_evr' do
    it 'parses full simple evr' do
      version = RpmTest.rpm_parse_evr('0:1.2.3-4.el5')
      expect([version[:epoch], version[:version], version[:release]]).to \
        eq(['0', '1.2.3', '4.el5'])
    end

    it 'parses version only' do
      version = RpmTest.rpm_parse_evr('1.2.3')
      expect([version[:epoch], version[:version], version[:release]]).to \
        eq([nil, '1.2.3', nil])
    end

    it 'parses version-release' do
      version = RpmTest.rpm_parse_evr('1.2.3-4.5.el6')
      expect([version[:epoch], version[:version], version[:release]]).to \
        eq([nil, '1.2.3', '4.5.el6'])
    end

    it 'parses release with git hash' do
      version = RpmTest.rpm_parse_evr('1.2.3-4.1234aefd')
      expect([version[:epoch], version[:version], version[:release]]).to \
        eq([nil, '1.2.3', '4.1234aefd'])
    end

    it 'parses single integer versions' do
      version = RpmTest.rpm_parse_evr('12345')
      expect([version[:epoch], version[:version], version[:release]]).to \
        eq([nil, '12345', nil])
    end

    it 'parses text in the epoch to 0' do
      version = RpmTest.rpm_parse_evr('foo0:1.2.3-4')
      expect([version[:epoch], version[:version], version[:release]]).to \
        eq([nil, '1.2.3', '4'])
    end

    it 'parses revisions with text' do
      version = RpmTest.rpm_parse_evr('1.2.3-SNAPSHOT20140107')
      expect([version[:epoch], version[:version], version[:release]]).to \
        eq([nil, '1.2.3', 'SNAPSHOT20140107'])
    end

    # test cases for PUP-682
    it 'parses revisions with text and numbers' do
      version = RpmTest.rpm_parse_evr('2.2-SNAPSHOT20121119105647')
      expect([version[:epoch], version[:version], version[:release]]).to \
        eq([nil, '2.2', 'SNAPSHOT20121119105647'])
    end
  end

  describe '.compare_values' do
    it 'treats two nil values as equal' do
      expect(RpmTest.compare_values(nil, nil)).to eq(0)
    end

    it 'treats a nil value as less than a non-nil value' do
      expect(RpmTest.compare_values(nil, '0')).to eq(-1)
    end

    it 'treats a non-nil value as greater than a nil value' do
      expect(RpmTest.compare_values('0', nil)).to eq(1)
    end

    it 'passes two non-nil values on to rpmvercmp' do
      allow(RpmTest).to receive(:rpmvercmp).and_return(0)
      expect(RpmTest).to receive(:rpmvercmp).with('s1', 's2')
      RpmTest.compare_values('s1', 's2')
    end
  end
end
