#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/resource_template'

describe Puppet::Util::ResourceTemplate do
  describe "when initializing" do
    it "should fail if the template does not exist" do
      FileTest.expects(:exist?).with("/my/template").returns false
      lambda { Puppet::Util::ResourceTemplate.new("/my/template", mock('resource')) }.should raise_error(ArgumentError)
    end

    it "should not create the ERB template" do
      ERB.expects(:new).never
      FileTest.expects(:exist?).with("/my/template").returns true
      Puppet::Util::ResourceTemplate.new("/my/template", mock('resource'))
    end
  end

  describe "when evaluating" do
    before do
      FileTest.stubs(:exist?).returns true
      File.stubs(:read).returns "eh"

      @template = stub 'template', :result => nil
      ERB.stubs(:new).returns @template

      @resource = mock 'resource'
      @wrapper = Puppet::Util::ResourceTemplate.new("/my/template", @resource)
    end

    it "should set all of the resource's parameters as instance variables" do
      @resource.expects(:to_hash).returns(:one => "uno", :two => "dos")
      @template.expects(:result).with do |bind|
        eval("@one", bind) == "uno" and eval("@two", bind) == "dos"
      end
      @wrapper.evaluate
    end

    it "should create a template instance with the contents of the file" do
      File.expects(:read).with("/my/template").returns "yay"
      ERB.expects(:new).with("yay", 0, "-").returns(@template)

      @wrapper.stubs :set_resource_variables

      @wrapper.evaluate
    end

    it "should return the result of the template" do
      @wrapper.stubs :set_resource_variables

      @wrapper.expects(:binding).returns "mybinding"
      @template.expects(:result).with("mybinding").returns "myresult"
      @wrapper.evaluate.should == "myresult"
    end
  end
end
