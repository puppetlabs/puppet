require 'spec_helper'
require 'puppet/util/rubygems'

describe Puppet::Util::RubyGems::Source do
  let(:gem_path) { File.expand_path('/foo/gems') }
  let(:gem_lib) { File.join(gem_path, 'lib') }
  let(:fake_gem) { stub(:full_gem_path => gem_path) }

  describe "::new" do
    it "returns NoGemsSource if rubygems is not present" do
      described_class.expects(:has_rubygems?).returns(false)
      expect(described_class.new).to be_kind_of(Puppet::Util::RubyGems::NoGemsSource)
    end

    it "returns Gems18Source if Gem::Specification responds to latest_specs" do
      described_class.expects(:has_rubygems?).returns(true)
      Gem::Specification.expects(:respond_to?).with(:latest_specs).returns(true)
      expect(described_class.new).to be_kind_of(Puppet::Util::RubyGems::Gems18Source)
    end

    it "returns Gems18Source if Gem::Specification does not respond to latest_specs" do
      described_class.expects(:has_rubygems?).returns(true)
      Gem::Specification.expects(:respond_to?).with(:latest_specs).returns(false)
      expect(described_class.new).to be_kind_of(Puppet::Util::RubyGems::OldGemsSource)
    end
  end

  describe '::NoGemsSource' do
    before(:each) { described_class.stubs(:source).returns(Puppet::Util::RubyGems::NoGemsSource) }

    it "#directories returns an empty list" do
      expect(described_class.new.directories).to eq([])
    end

    it "#clear_paths returns nil" do
      expect(described_class.new.clear_paths).to be_nil
    end
  end

  describe '::Gems18Source' do
    before(:each) { described_class.stubs(:source).returns(Puppet::Util::RubyGems::Gems18Source) }

    it "#directories returns the lib subdirs of Gem::Specification.latest_specs" do
      Gem::Specification.expects(:latest_specs).with(true).returns([fake_gem])

      expect(described_class.new.directories).to eq([gem_lib])
    end

    it "#clear_paths calls Gem.clear_paths" do
      Gem.expects(:clear_paths)
      described_class.new.clear_paths
    end
  end

  describe '::OldGemsSource' do
    before(:each) { described_class.stubs(:source).returns(Puppet::Util::RubyGems::OldGemsSource) }

    it "#directories returns the contents of Gem.latest_load_paths" do
      Gem.expects(:latest_load_paths).returns([gem_lib])

      expect(described_class.new.directories).to eq([gem_lib])
    end

    # Older rubygems seem to have a problem with rescanning the gem paths in which they
    # look for a file in the wrong place and expect it to be there. By caching the first
    # set of results we don't trigger this bug. This behavior was seen on ruby 1.8.7-p334
    # using rubygems v1.6.2
    it "caches the gem paths (works around a bug in older rubygems)" do
      Gem.expects(:latest_load_paths).returns([gem_lib]).once

      source = described_class.new

      expect(source.directories).to eq([gem_lib])
    end

    it "#clear_paths calls Gem.clear_paths" do
      Gem.expects(:clear_paths)
      described_class.new.clear_paths
    end
  end
end

