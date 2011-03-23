#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "Package Provider" do
  Puppet::Type.type(:package).providers.each do |name|
    provider = Puppet::Type.type(:package).provider(name)

    describe name, :if => provider.suitable? do
      it "should fail when asked to install an invalid package" do
        pending("This test hangs forever with recent versions of RubyGems") if provider.name == :gem
        pkg = Puppet::Type.newpackage :name => "nosuch#{provider.name}", :provider => provider.name
        lambda { pkg.provider.install }.should raise_error
      end

      it "should be able to get a list of existing packages" do
        provider.instances.each do |package|
          package.should be_instance_of(provider)
          package.properties[:provider].should == provider.name
        end
      end
    end
  end
end
