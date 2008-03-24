#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'tempfile'
require 'puppet/util/loadedfile'

describe Puppet::Util::LoadedFile do
    before(:all) do
        # First, save and adjust the timeout so tests don't take forever.
        @saved_filetimeout = Puppet[:filetimeout]
        Puppet[:filetimeout] = 1
    end

    before(:each) do
        @f = Tempfile.new('loadedfile_test')
        @loaded = Puppet::Util::LoadedFile.new(@f.path)
    end

    it "should recognize when the file has not changed" do
        sleep(Puppet[:filetimeout])
        @loaded.changed?.should == false
    end

    it "should recognize when the file has changed" do
        @f.puts "Hello"
        @f.flush
        sleep(Puppet[:filetimeout])
        @loaded.changed?.should be_an_instance_of(Time)
    end

    after(:each) do
        @f.close
    end

    after(:all) do
        # Restore the saved timeout.
        Puppet[:filetimeout] = @saved_filetimeout
    end
end
