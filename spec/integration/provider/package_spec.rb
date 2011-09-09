#!/usr/bin/env rspec
require 'spec_helper'

describe "Package provider", :'fails_on_ruby_1.9.2' => true do
  include PuppetSpec::Files

  Puppet::Type.type(:package).providers.each do |name|
    provider = Puppet::Type.type(:package).provider(name)

    describe name, :if => provider.suitable? do
      it "should fail when asked to install an invalid package" do
        pending("This test hangs forever with recent versions of RubyGems") if provider.name == :gem

        options = {:name => "nosuch#{provider.name}", :provider => provider.name}
        # The MSI provider requires that source be specified as it is
        # what actually determines if the package exists.
        if provider.name == :msi
          options[:source] = tmpfile("msi_package")
        end

        pkg = Puppet::Type.newpackage(options)
        lambda { pkg.provider.install }.should raise_error
      end

      it "should be able to get a list of existing packages", :fails_on_windows => true do
        provider.instances.each do |package|
          package.should be_instance_of(provider)
          package.properties[:provider].should == provider.name
        end
      end
    end
  end
end
