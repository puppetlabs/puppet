require 'spec_helper'
require 'puppet/util/rubygems'

describe Puppet::Util::RubyGems do
  describe 'directories' do

    it "should return no directories if rubygems fails to load" do
      # I could not figure out a better way to produce a LoadError, as rubygems
      # is already loaded by the time we get here. 
      Gem::Specification.expects(:latest_specs).raises LoadError
      Puppet::Util::RubyGems.directories.should == []
    end

    context "when rubygems is installed", :if => Puppet.features.rubygems? do
      let :fakegem do
        stub(:full_gem_path => '/foo/gems')
      end

      it "should use Gem::Specification.latest_specs when available" do
        FileTest.expects(:directory?).with('/foo/gems/lib').returns(true)
        Gem::Specification.expects(:latest_specs).returns([fakegem])

        Puppet::Util::RubyGems.directories.should == ['/foo/gems/lib']
      end

      it "should fallback to Gem.latest_load_paths" do
        FileTest.expects(:directory?).with('/foo/gems/lib').returns(true)
        Gem::Specification.expects(:respond_to?).with(:latest_specs).returns(false)
        Gem.expects(:latest_load_paths).returns('/foo/gems/lib')

        Puppet::Util::RubyGems.directories.should == ['/foo/gems/lib']
      end

      it "should return no directories if Gem.latest_load_paths and Gem::Specification.latest_specs not available" do
        FileTest.expects(:directory?).never
        Gem::Specification.expects(:respond_to?).with(:latest_specs).returns(false)
        Gem.expects(:respond_to?).with(:latest_load_paths).returns(false)

        Puppet::Util::RubyGems.directories.should == []
      end
    end
  end
end

