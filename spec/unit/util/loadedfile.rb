#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'tempfile'
require 'puppet/util/loadedfile'

describe Puppet::Util::LoadedFile do
    before(:all) do
        # First, save and adjust the timeout so tests don't take forever.
        @saved_filetimeout = Puppet[:filetimeout]
        Puppet[:filetimeout] = 5
    end

    before(:each) do
        @f = Tempfile.new('loadedfile_test')
        @f.puts "yayness"
        @f.flush
        @loaded = Puppet::Util::LoadedFile.new(@f.path)
    end

    it "should recognize when the file has not changed" do
        sleep(Puppet[:filetimeout])
        @loaded.changed?.should == false
    end

    it "should recognize when the file has changed" do
        @f.puts "booness"
        @f.flush
        sleep(Puppet[:filetimeout])
        @loaded.changed?.should be_an_instance_of(Time)
    end

    it "should not catch a change until the timeout has elapsed" do
        @f.puts "yay"
        @f.flush
        @loaded.changed?.should be(false)
        sleep(Puppet[:filetimeout])
        @loaded.changed?.should_not be(false)
    end

    it "should consider a file changed when that file is missing" do
        @f.close!
        sleep(Puppet[:filetimeout])
        @loaded.changed?.should_not be(false)
    end

    it "should disable checking if Puppet[:filetimeout] is negative" do
        Puppet[:filetimeout] = -1
        @loaded.changed?.should_not be(false)
    end

    after(:each) do
        @f.close
    end

    after(:all) do
        # Restore the saved timeout.
        Puppet[:filetimeout] = @saved_filetimeout
    end
end
