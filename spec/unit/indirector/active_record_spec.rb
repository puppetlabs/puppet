#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/rails'
require 'puppet/indirector/active_record'

describe Puppet::Indirector::ActiveRecord do
  before do
    Puppet::Rails.stubs(:init)

    Puppet::Indirector::Terminus.stubs(:register_terminus_class)
    @model = mock 'model'
    @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
    Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

    module Testing; end
    @active_record_class = class Testing::MyActiveRecord < Puppet::Indirector::ActiveRecord
      self
    end

    @ar_model = mock 'ar_model'

    @active_record_class.use_ar_model @ar_model
    @terminus = @active_record_class.new

    @name = "me"
    @instance = stub 'instance', :name => @name

    @request = stub 'request', :key => @name, :instance => @instance
  end

  it "should allow declaration of an ActiveRecord model to use" do
    @active_record_class.use_ar_model "foo"
    @active_record_class.ar_model.should == "foo"
  end

  describe "when initializing" do
    it "should init Rails" do
      Puppet::Rails.expects(:init)
      @active_record_class.new
    end
  end

  describe "when finding an instance" do
    it "should use the ActiveRecord model to find the instance" do
      @ar_model.expects(:find_by_name).with(@name)

      @terminus.find(@request)
    end

    it "should return nil if no instance is found" do
      @ar_model.expects(:find_by_name).with(@name).returns nil
      @terminus.find(@request).should be_nil
    end

    it "should convert the instance to a Puppet object if it is found" do
      instance = mock 'rails_instance'
      instance.expects(:to_puppet).returns "mypuppet"

      @ar_model.expects(:find_by_name).with(@name).returns instance
      @terminus.find(@request).should == "mypuppet"
    end
  end

  describe "when saving an instance" do
    it "should use the ActiveRecord model to convert the instance into a Rails object and then save that rails object" do
      rails_object = mock 'rails_object'
      @ar_model.expects(:from_puppet).with(@instance).returns rails_object

      rails_object.expects(:save)

      @terminus.save(@request)
    end
  end
end
