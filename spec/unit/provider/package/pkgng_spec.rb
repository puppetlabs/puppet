#!/usr/bin/env ruby -S rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:pkgng)

describe provider_class do
  let(:resource) { Puppet::Type.type(:package).new(:name => "vim") }
  subject        { provider_class.new(resource) }

  describe "#install" do
    before { resource[:ensure] = :absent }

    it "uses pkgin install to install" do
      subject.expects(:pkg).with('install', '-qyL', 'vim')
      subject.install
    end
  end

  describe "#uninstall" do
    before { resource[:ensure] = :present }

    it "uses pkgin remove to uninstall" do
      subject.expects(:pkg).with('remove', 'vim')
      subject.uninstall
    end
  end
end
