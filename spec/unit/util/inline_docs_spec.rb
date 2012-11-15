#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/inline_docs'

class InlineDoccer
  include Puppet::Util::InlineDocs
end

describe Puppet::Util::InlineDocs do
  describe "when included" do
    it "should create a class method for specifying that docs should be associated" do
      InlineDoccer.expects(:use_docs=).with true
      InlineDoccer.associates_doc
    end

    it "should default to not associating docs" do
      (!! InlineDoccer.use_docs).should be_false
    end

    it "should create an instance method for setting documentation" do
      instance = InlineDoccer.new
      instance.doc = "foo"
      instance.doc.should == "foo"
    end

    it "should default to an empty string for docs" do
      InlineDoccer.new.doc.should == ""
    end
  end
end
