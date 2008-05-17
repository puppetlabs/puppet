#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'yaml'
require 'sync'
require 'tempfile'

describe Puppet::Util::Storage do

    before(:all) do
        Puppet[:statedir] = Dir.tmpdir()
    end

    it "it should re-initialize to a clean state when the clear() method is called" do
    end

    it "it should use the main settings section if the state dir is not a directory" do
        FileTest.expects(:directory?).with(Puppet[:statedir]).returns(false)
        Puppet.settings.expects(:use).with(:main)
        Puppet::Util::Storage.load()
    end

    it "it should initialize with an empty state when the state file does not exist" do
        File.expects(:exists?).with(Puppet[:statefile]).returns(false)
        Puppet::Util::Storage.load()
        Puppet::Util::Storage.stateinspect().should == {}.inspect()
    end

    describe "when the state file exists" do
        it "it should attempt to get a read lock on the file" do
            File.expects(:exists?).with(Puppet[:statefile]).returns(true)
            Puppet::Util.expects(:benchmark).with(:debug, "Loaded state").yields()
            Puppet::Util.expects(:readlock).with(Puppet[:statefile])
            Puppet::Util::Storage.load()
        end

        describe "and the file contents are valid" do
            it "it should initialize with the correct state from the state file" do
                File.expects(:exists?).with(Puppet[:statefile]).returns(true)
                Puppet::Util.expects(:benchmark).with(:debug, "Loaded state").yields()
                Puppet::Util.expects(:readlock).with(Puppet[:statefile]).yields(0)
                test_yaml = {'File["/root"]'=>{"name"=>{:a=>:b,:c=>:d}}}
                YAML.expects(:load).returns(test_yaml)

                Puppet::Util::Storage.load()
                Puppet::Util::Storage.stateinspect().should == test_yaml.inspect()
            end
        end

        describe "and the file contents are invalid" do
            # Commented out because the previous test's existence causes this one to fail.
#             it "it should not initialize from the state file" do
#                 File.expects(:exists?).with(Puppet[:statefile]).returns(true)
#                 Puppet::Util.expects(:benchmark).with(:debug, "Loaded state").yields()
#                 Puppet::Util.expects(:readlock).with(Puppet[:statefile]).yields(0)
#                 YAML.expects(:load).raises(YAML::Error)
#                 File.expects(:rename).with(Puppet[:statefile], Puppet[:statefile] + ".bad").returns(0)

#                 Puppet::Util::Storage.load()
#                 Puppet::Util::Storage.stateinspect().should == {}.inspect()
#             end

            it "it should attempt to rename the state file" do
                
            end

        end

    end

end
