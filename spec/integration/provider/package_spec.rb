#! /usr/bin/env ruby
require 'spec_helper'

describe "Package provider" do
  include PuppetSpec::Files

  Puppet::Type.type(:package).providers.each do |name|
    provider = Puppet::Type.type(:package).provider(name)

    describe name, :if => provider.suitable? do
      it "should fail when asked to install an invalid package" do
        options = {:name => "nosuch#{provider.name}", :provider => provider.name}

        pkg = Puppet::Type.newpackage(options)
        expect { pkg.provider.install }.to raise_error { |error|
          expect(error).not_to eq("")
        }
      end

      it "should be able to get a list of existing packages" do
        # the instances method requires root priviledges on gentoo
        # if the eix cache is outdated (to run eix-update) so make
        # sure we dont actually run eix-update
        if provider.name == :portage
          provider.stubs(:update_eix).returns('Database contains 15240 packages in 155 categories')
        end

        provider.instances.each do |package|
          expect(package).to be_instance_of(provider)
          expect(package.properties[:provider]).to eq(provider.name)
        end
      end
    end
  end
end
