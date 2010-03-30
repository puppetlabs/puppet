#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/configurer'

describe Puppet::Configurer do
    describe "when downloading plugins" do
        it "should use the :pluginsignore setting, split on whitespace, for ignoring remote files" do
            resource = Puppet::Type.type(:notify).new :name => "yay"
            Puppet::Type.type(:file).expects(:new).with { |args| args[:ignore] == Puppet[:pluginsignore].split(/\s+/) }.returns resource

            configurer = Puppet::Configurer.new
            configurer.stubs(:download_plugins?).returns true
            configurer.download_plugins
        end
    end

    describe "when running" do
        it "should send a transaction report with valid data" do
            catalog = Puppet::Resource::Catalog.new
            catalog.add_resource(Puppet::Type.type(:notify).new(:title => "testing"))

            configurer = Puppet::Configurer.new

            Puppet::Transaction::Report.indirection.expects(:save).with do |x, report|
                report.time.class == Time and report.logs.length > 0
            end

            Puppet[:report] = true

            configurer.run :catalog => catalog
        end
    end
end
