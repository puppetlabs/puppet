#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/type/selmodule'

describe Puppet.type(:selmodule), " when checking policy modules" do
	before :each do
		@module = Puppet::Type::Selmodule.create(
			:name => "foo",
			:selmoduledir => "/some/path",
			:selmodulepath => "/some/path/foo.pp",
			:syncversion => true)
	end
	it "should be able to access :name" do
		@module[:name].should == "foo"
	end
	it "should be able to access :selmoduledir" do
		@module[:selmoduledir].should == "/some/path"
	end
	it "should be able to access :selmodulepath" do
		@module[:selmodulepath].should == "/some/path/foo.pp"
	end
	it "should be able to access :syncversion" do
		@module.property(:syncversion).should == :true
	end
	it "should set the syncversion value to false" do
		@module[:syncversion] = :false
		@module.property(:syncversion).should == :false
	end
	after :each do
		Puppet::Type::Selmodule.clear()
	end
end

