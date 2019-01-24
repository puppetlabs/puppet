require 'spec_helper'
require 'puppet/util/rubygems'

describe Puppet::Util::RubyGems::Source do
  let(:gem_path) { File.expand_path('/foo/gems') }
  let(:gem_lib) { File.join(gem_path, 'lib') }
  let(:fake_gem) { double(:full_gem_path => gem_path) }

  describe "::new" do
    it "returns NoGemsSource if rubygems is not present" do
      expect(described_class).to receive(:has_rubygems?).and_return(false)
      expect(described_class.new).to be_kind_of(Puppet::Util::RubyGems::NoGemsSource)
    end

    it "returns Gems18Source if Gem::Specification responds to latest_specs" do
      expect(described_class).to receive(:has_rubygems?).and_return(true)
      expect(Gem::Specification).to receive(:respond_to?).with(:latest_specs).and_return(true)
      expect(described_class.new).to be_kind_of(Puppet::Util::RubyGems::Gems18Source)
    end

    it "returns Gems18Source if Gem::Specification does not respond to latest_specs" do
      expect(described_class).to receive(:has_rubygems?).and_return(true)
      expect(Gem::Specification).to receive(:respond_to?).with(:latest_specs).and_return(false)
      expect(described_class.new).to be_kind_of(Puppet::Util::RubyGems::OldGemsSource)
    end
  end

  describe '::NoGemsSource' do
    before(:each) { allow(described_class).to receive(:source).and_return(Puppet::Util::RubyGems::NoGemsSource) }

    it "#directories returns an empty list" do
      expect(described_class.new.directories).to eq([])
    end

    it "#clear_paths returns nil" do
      expect(described_class.new.clear_paths).to be_nil
    end
  end

  describe '::Gems18Source' do
    before(:each) { allow(described_class).to receive(:source).and_return(Puppet::Util::RubyGems::Gems18Source) }

    it "#directories returns the lib subdirs of Gem::Specification.latest_specs" do
      expect(Gem::Specification).to receive(:latest_specs).with(true).and_return([fake_gem])

      expect(described_class.new.directories).to eq([gem_lib])
    end

    it "#clear_paths calls Gem.clear_paths" do
      expect(Gem).to receive(:clear_paths)
      described_class.new.clear_paths
    end
  end

  describe '::OldGemsSource' do
    before(:each) { allow(described_class).to receive(:source).and_return(Puppet::Util::RubyGems::OldGemsSource) }

    it "#directories returns the contents of Gem.latest_load_paths" do
      expect(Gem).to receive(:latest_load_paths).and_return([gem_lib])

      expect(described_class.new.directories).to eq([gem_lib])
    end

    # Older rubygems seem to have a problem with rescanning the gem paths in which they
    # look for a file in the wrong place and expect it to be there. By caching the first
    # set of results we don't trigger this bug. This behavior was seen on ruby 1.8.7-p334
    # using rubygems v1.6.2
    it "caches the gem paths (works around a bug in older rubygems)" do
      expect(Gem).to receive(:latest_load_paths).and_return([gem_lib]).once

      source = described_class.new

      expect(source.directories).to eq([gem_lib])
    end

    it "#clear_paths calls Gem.clear_paths" do
      expect(Gem).to receive(:clear_paths)
      described_class.new.clear_paths
    end
  end
end

