#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/configuration'

describe Puppet::FileServing::Configuration do
    it "should work without a configuration file"
end

describe Puppet::FileServing::Configuration, " when initializing" do
    it "should make :new a private method" do
        pending "Not implemented yet"
        #proc { Puppet::FileServing::Configuration }.should raise_error
    end

    it "should return the same configuration each time :create is called" do
        pending "Not implemented yet"
        #Puppet::FileServing::Configuration.create.should equal(Puppet::FileServing::Configuration.create)
    end
end

describe Puppet::FileServing::Configuration, " when parsing the configuration file" do
    it "should not raise exceptions"

    it "should not replace the mount list until the file is entirely parsed successfully"

    it "should skip comments"

    it "should skip blank lines"

    it "should create a new mount for each section in the configuration"

    it "should only allow mount names that are alphanumeric plus dashes"

    it "should set the mount path to the path attribute from that section"

    it "should refuse to allow a path for the modules mount"

    it "should tell the mount to allow any allow values from the section"

    it "should tell the mount to deny any deny values from the section"

    it "should fail on any attributes other than path, allow, and deny"
end

describe Puppet::FileServing::Configuration, " when finding file metadata" do
    it "should require authorization"

    it "should return nil if the mount cannot be found"

    it "should use the mount object to return a Metadata instance if the mount exists"
end

describe Puppet::FileServing::Configuration, " when finding file content" do
    it "should require authorization"

    it "should return nil if the mount cannot be found"

    it "should use the mount object to return a Content instance if the mount exists"
end

describe Puppet::FileServing::Configuration, " when authorizing" do
    it "should reparse the configuration file when it has changed"
end
