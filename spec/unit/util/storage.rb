#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'yaml'
require 'sync'
require 'tempfile'

describe Puppet::Util::Storage do
    before(:all) do
        Puppet[:statedir] = Dir.tmpdir()
        @file_test = Puppet.type(:file).create(:name => "/yayness", :check => %w{checksum type})
        @exec_test = Puppet.type(:exec).create(:name => "/bin/ls /yayness")
        @bogus_objects = [ {}, [], "foo", 42, nil, Tempfile.new('storage_test') ]
    end

    before(:each) do
        Puppet::Util::Storage.clear()
    end

    it "it should return an empty hash when caching a symbol" do
        Puppet::Util::Storage.cache(:yayness).should == {}
        Puppet::Util::Storage.cache(:more_yayness).should == {}
    end
    it "it should add the symbol to it's internal state when caching a symbol" do
        Puppet::Util::Storage.stateinspect().should == {}.inspect()
        Puppet::Util::Storage.cache(:yayness)
        Puppet::Util::Storage.stateinspect().should == {:yayness=>{}}.inspect()
        Puppet::Util::Storage.cache(:bubblyness)
        Puppet::Util::Storage.stateinspect().should == {:yayness=>{},:bubblyness=>{}}.inspect()
    end
    it "it should return an empty hash when caching a Puppet::Type" do
        Puppet::Util::Storage.cache(@file_test).should == {}
        Puppet::Util::Storage.cache(@exec_test).should == {}
    end
    it "it should add the resource ref to it's internal state when caching a Puppet::Type" do
        Puppet::Util::Storage.stateinspect().should == {}.inspect()
        Puppet::Util::Storage.cache(@file_test)
        Puppet::Util::Storage.stateinspect().should == {"File[/yayness]"=>{}}.inspect()
        Puppet::Util::Storage.cache(@exec_test)
        Puppet::Util::Storage.stateinspect().should == {"File[/yayness]"=>{}, "Exec[/bin/ls /yayness]"=>{}}.inspect()
    end

    it "it should raise an ArgumentError when caching invalid objects" do
        @bogus_objects.each do |object|
            proc { Puppet::Util::Storage.cache(object) }.should raise_error()
        end
    end
    it "it should not add anything to it's internal state when caching invalid objects" do
        @bogus_objects.each do |object|
            begin
                Puppet::Util::Storage.cache(object)
            rescue
                Puppet::Util::Storage.stateinspect().should == {}.inspect()
            end
        end
    end

    it "it should clear it's internal state when clear() is called" do
        Puppet::Util::Storage.cache(@file_test)
        Puppet::Util::Storage.cache(:yayness)
        Puppet::Util::Storage.stateinspect().should == {"File[/yayness]"=>{}, :yayness=>{}}.inspect()
        Puppet::Util::Storage.clear()
        Puppet::Util::Storage.stateinspect().should == {}.inspect()
        Puppet::Util::Storage.cache(@exec_test)            
        Puppet::Util::Storage.cache(:bubblyness)
        Puppet::Util::Storage.stateinspect().should == {"Exec[/bin/ls /yayness]"=>{}, :bubblyness=>{}}.inspect()
        Puppet::Util::Storage.clear()
        Puppet::Util::Storage.stateinspect().should == {}.inspect()
    end

    it "it should not fail to load if Puppet[:statedir] does not exist" do
        transient = Tempfile.new('storage_test')
        path = transient.path()
        transient.close!()
        FileTest.exists?(path).should be_false()
        Puppet[:statedir] = path
        proc { Puppet::Util::Storage.load() }.should_not raise_error()
    end

    it "it should not fail to load if Puppet[:statefile] does not exist" do
        transient = Tempfile.new('storage_test')
        path = transient.path()
        transient.close!()
        FileTest.exists?(path).should be_false()
        Puppet[:statefile] = path
        proc { Puppet::Util::Storage.load() }.should_not raise_error()
    end

    it "it should not lose it's internal state if load() is called and Puppet[:statefile] does not exist" do
        transient = Tempfile.new('storage_test')
        path = transient.path()
        transient.close!()
        FileTest.exists?(path).should be_false()

        Puppet::Util::Storage.cache(@file_test)
        Puppet::Util::Storage.cache(:yayness)
        Puppet::Util::Storage.stateinspect().should == {"File[/yayness]"=>{}, :yayness=>{}}.inspect()

        Puppet[:statefile] = path
        proc { Puppet::Util::Storage.load() }.should_not raise_error()

        Puppet::Util::Storage.stateinspect().should == {"File[/yayness]"=>{}, :yayness=>{}}.inspect()
    end

    it "it should overwrite it's internal state if load() is called and Puppet[:statefile] exists" do
        # Should the state be overwritten even if Puppet[:statefile] is not valid YAML?
        state_file = Tempfile.new('storage_test')

        Puppet::Util::Storage.cache(@file_test)
        Puppet::Util::Storage.cache(:yayness)
        Puppet::Util::Storage.stateinspect().should == {"File[/yayness]"=>{}, :yayness=>{}}.inspect()

        Puppet[:statefile] = state_file.path()
        proc { Puppet::Util::Storage.load() }.should_not raise_error()

        Puppet::Util::Storage.stateinspect().should == {}.inspect()

        state_file.close!()
    end

    it "it should restore it's internal state from Puppet[:statefile] if the file contains valid YAML" do
        state_file = Tempfile.new('storage_test')
        Puppet[:statefile] = state_file.path()
        test_yaml = {'File["/yayness"]'=>{"name"=>{:a=>:b,:c=>:d}}}
        YAML.expects(:load).returns(test_yaml)

        proc { Puppet::Util::Storage.load() }.should_not raise_error()
        Puppet::Util::Storage.stateinspect().should == test_yaml.inspect()

        state_file.close!()
    end
    
    it "it should initialize with a clear internal state if the state file does not contain valid YAML" do
        state_file = Tempfile.new('storage_test')
        Puppet[:statefile] = state_file.path()
        state_file.write(:booness)

        proc { Puppet::Util::Storage.load() }.should_not raise_error()
        Puppet::Util::Storage.stateinspect().should == {}.inspect()

        state_file.close!()
    end

    it "it should raise an error if the state file does not contain valid YAML and cannot be renamed" do
        state_file = Tempfile.new('storage_test')
        Puppet[:statefile] = state_file.path()
        state_file.write(:booness)
        File.chmod(0000, state_file.path())

        proc { Puppet::Util::Storage.load() }.should raise_error()

        state_file.close!()
    end

    it "it should attempt to rename the state file if the file is corrupted" do
        # We fake corruption by causing YAML.load to raise an exception
        state_file = Tempfile.new('storage_test')
        Puppet[:statefile] = state_file.path()
        YAML.expects(:load).raises(Puppet::Error)
        File.expects(:rename).at_least_once

        proc { Puppet::Util::Storage.load() }.should_not raise_error()

        state_file.close!()
    end

    it "it should fail gracefully on load() if Puppet[:statefile] is not a regular file" do
        state_file = Tempfile.new('storage_test')
        Puppet[:statefile] = state_file.path()
        state_file.close!()
        Dir.mkdir(Puppet[:statefile])
        File.expects(:rename).returns(0)

        proc { Puppet::Util::Storage.load() }.should_not raise_error()

        Dir.rmdir(Puppet[:statefile])
    end

    it "it should fail gracefully on load() if it cannot get a read lock on Puppet[:statefile]" do
        state_file = Tempfile.new('storage_test')
        Puppet[:statefile] = state_file.path()
        Puppet::Util.expects(:readlock).yields(false)
        test_yaml = {'File["/yayness"]'=>{"name"=>{:a=>:b,:c=>:d}}}
        YAML.expects(:load).returns(test_yaml)

        proc { Puppet::Util::Storage.load() }.should_not raise_error()
        Puppet::Util::Storage.stateinspect().should == test_yaml.inspect()

        state_file.close!()
    end

    it "it should raise an exception on store() if Puppet[:statefile] is not a regular file" do
        state_file = Tempfile.new('storage_test')
        Puppet[:statefile] = state_file.path()
        state_file.close!()
        Dir.mkdir(Puppet[:statefile])
        Puppet::Util::Storage.cache(@file_test)
        Puppet::Util::Storage.cache(:yayness)

        proc { Puppet::Util::Storage.store() }.should raise_error()

        Dir.rmdir(Puppet[:statefile])
    end

    it "it should raise an exception on store() if it cannot get a write lock on Puppet[:statefile]" do
        state_file = Tempfile.new('storage_test')
        Puppet[:statefile] = state_file.path()
        Puppet::Util.expects(:writelock).yields(false)
        Puppet::Util::Storage.cache(@file_test)
        Puppet::Util::Storage.cache(:yayness)

        proc { Puppet::Util::Storage.store() }.should raise_error()

        state_file.close!()
    end

    it "it should load() the same information that it store()s" do
        state_file = Tempfile.new('storage_test')
        Puppet[:statefile] = state_file.path()
        Puppet::Util::Storage.cache(@file_test)
        Puppet::Util::Storage.cache(:yayness)

        Puppet::Util::Storage.stateinspect().should == {"File[/yayness]"=>{}, :yayness=>{}}.inspect()
        proc { Puppet::Util::Storage.store() }.should_not raise_error()

        Puppet::Util::Storage.clear()
        Puppet::Util::Storage.stateinspect().should == {}.inspect()

        proc { Puppet::Util::Storage.load() }.should_not raise_error()
        Puppet::Util::Storage.stateinspect().should == {"File[/yayness]"=>{}, :yayness=>{}}.inspect()

        state_file.close!()
    end

    after(:all) do
        @bogus_objects.last.close!()
    end
end
