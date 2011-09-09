require 'spec_helper'
require 'semver'

describe SemVer do
  describe '::valid?' do
    it 'should validate basic version strings' do
      %w[ 0.0.0 999.999.999 v0.0.0 v999.999.999 ].each do |vstring|
        SemVer.valid?(vstring).should be_true
      end
    end

    it 'should validate special version strings' do
      %w[ 0.0.0foo 999.999.999bar v0.0.0a v999.999.999beta ].each do |vstring|
        SemVer.valid?(vstring).should be_true
      end
    end

    it 'should fail to validate invalid version strings' do
      %w[ nope 0.0foo 999.999 x0.0.0 z.z.z 1.2.3-beta 1.x.y ].each do |vstring|
        SemVer.valid?(vstring).should be_false
      end
    end
  end

  describe '::find_matching' do
    before :all do
      @versions = %w[
        0.0.1
        0.0.2
        1.0.0rc1
        1.0.0rc2
        1.0.0
        1.0.1
        1.1.0
        1.1.1
        1.1.2
        1.1.3
        1.1.4
        1.2.0
        1.2.1
        2.0.0rc1
      ].map { |v| SemVer.new(v) }
    end

    it 'should match exact versions by string' do
      @versions.each do |version|
        SemVer.find_matching(version, @versions).should == version
      end
    end

    it 'should return nil if no versions match' do
      %w[ 3.0.0 2.0.0rc2 1.0.0alpha ].each do |v|
        SemVer.find_matching(v, @versions).should be_nil
      end
    end

    it 'should find the greatest match for partial versions' do
      SemVer.find_matching('1.0', @versions).should == 'v1.0.1'
      SemVer.find_matching('1.1', @versions).should == 'v1.1.4'
      SemVer.find_matching('1', @versions).should   == 'v1.2.1'
      SemVer.find_matching('2', @versions).should   == 'v2.0.0rc1'
      SemVer.find_matching('2.1', @versions).should == nil
    end


    it 'should find the greatest match for versions with placeholders' do
      SemVer.find_matching('1.0.x', @versions).should == 'v1.0.1'
      SemVer.find_matching('1.1.x', @versions).should == 'v1.1.4'
      SemVer.find_matching('1.x', @versions).should   == 'v1.2.1'
      SemVer.find_matching('1.x.x', @versions).should == 'v1.2.1'
      SemVer.find_matching('2.x', @versions).should   == 'v2.0.0rc1'
      SemVer.find_matching('2.x.x', @versions).should == 'v2.0.0rc1'
      SemVer.find_matching('2.1.x', @versions).should == nil
    end
  end

  describe 'instantiation' do
    it 'should raise an exception when passed an invalid version string' do
      expect { SemVer.new('invalidVersion') }.to raise_exception ArgumentError
    end

    it 'should populate the appropriate fields for a basic version string' do
      version = SemVer.new('1.2.3')
      version.major.should   == 1
      version.minor.should   == 2
      version.tiny.should    == 3
      version.special.should == ''
    end

    it 'should populate the appropriate fields for a special version string' do
      version = SemVer.new('3.4.5beta6')
      version.major.should   == 3
      version.minor.should   == 4
      version.tiny.should    == 5
      version.special.should == 'beta6'
    end
  end

  describe '#matched_by?' do
    subject { SemVer.new('v1.2.3beta') }

    describe 'should match against' do
      describe 'literal version strings' do
        it { should be_matched_by('1.2.3beta') }

        it { should_not be_matched_by('1.2.3alpha') }
        it { should_not be_matched_by('1.2.4beta') }
        it { should_not be_matched_by('1.3.3beta') }
        it { should_not be_matched_by('2.2.3beta') }
      end

      describe 'partial version strings' do
        it { should be_matched_by('1.2.3') }
        it { should be_matched_by('1.2') }
        it { should be_matched_by('1') }
      end

      describe 'version strings with placeholders' do
        it { should be_matched_by('1.2.x') }
        it { should be_matched_by('1.x.3') }
        it { should be_matched_by('1.x.x') }
        it { should be_matched_by('1.x') }
      end
    end
  end

  describe 'comparisons' do
    describe 'against a string' do
      it 'should just work' do
        SemVer.new('1.2.3').should == '1.2.3'
      end
    end

    describe 'against a symbol' do
      it 'should just work' do
        SemVer.new('1.2.3').should == :'1.2.3'
      end
    end

    describe 'on a basic version (v1.2.3)' do
      subject { SemVer.new('v1.2.3') }

      it { should == SemVer.new('1.2.3') }

      # Different major versions
      it { should > SemVer.new('0.2.3') }
      it { should < SemVer.new('2.2.3') }

      # Different minor versions
      it { should > SemVer.new('1.1.3') }
      it { should < SemVer.new('1.3.3') }

      # Different tiny versions
      it { should > SemVer.new('1.2.2') }
      it { should < SemVer.new('1.2.4') }

      # Against special versions
      it { should > SemVer.new('1.2.3beta') }
      it { should < SemVer.new('1.2.4beta') }
    end

    describe 'on a special version (v1.2.3beta)' do
      subject { SemVer.new('v1.2.3beta') }

      it { should == SemVer.new('1.2.3beta') }

      # Same version, final release
      it { should < SemVer.new('1.2.3') }

      # Different major versions
      it { should > SemVer.new('0.2.3') }
      it { should < SemVer.new('2.2.3') }

      # Different minor versions
      it { should > SemVer.new('1.1.3') }
      it { should < SemVer.new('1.3.3') }

      # Different tiny versions
      it { should > SemVer.new('1.2.2') }
      it { should < SemVer.new('1.2.4') }

      # Against special versions
      it { should > SemVer.new('1.2.3alpha') }
      it { should < SemVer.new('1.2.3beta2') }
    end
  end
end
