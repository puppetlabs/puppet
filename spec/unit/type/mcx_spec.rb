#!/usr/bin/env ruby
#--
# Copyright (C) 2008 Jeffrey J McCune.

# This program and entire repository is free software; you can
# redistribute it and/or modify it under the terms of the GNU
# General Public License as published by the Free Software
# Foundation; either version 2 of the License, or any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

# Author: Jeff McCune <mccune.jeff@gmail.com>

# Most of this code copied from /spec/type/service.rb

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/type/mcx'

mcx_type = Puppet::Type.type(:mcx)

describe mcx_type, "when validating attributes" do

    properties = [:ensure, :content]
    parameters = [:name, :ds_type, :ds_name]

    parameters.each do |p|
        it "should have a #{p} parameter" do
            mcx_type.attrclass(p).ancestors.should be_include(Puppet::Parameter)
        end
        it "should have documentation for its #{p} parameter" do
            mcx_type.attrclass(p).doc.should be_instance_of(String)
        end
    end

    properties.each do |p|
        it "should have a #{p} property" do
            mcx_type.attrclass(p).ancestors.should be_include(Puppet::Property)
        end
        it "should have documentation for its #{p} property" do
            mcx_type.attrclass(p).doc.should be_instance_of(String)
        end
    end

end

describe mcx_type, "default values" do

    before :each do
        provider_class = mcx_type.provider(mcx_type.providers[0])
        mcx_type.stubs(:defaultprovider).returns provider_class
    end

    it "should be nil for :ds_type" do
        mcx_type.new(:name => '/Foo/bar')[:ds_type].should be_nil
    end

    it "should be nil for :ds_name" do
        mcx_type.new(:name => '/Foo/bar')[:ds_name].should be_nil
    end

    it "should be nil for :content" do
        mcx_type.new(:name => '/Foo/bar')[:content].should be_nil
    end

end

describe mcx_type, "when validating properties" do

    before :each do
        provider_class = mcx_type.provider(mcx_type.providers[0])
        mcx_type.stubs(:defaultprovider).returns provider_class
    end

    it "should be able to create an instance" do
        lambda {
            mcx_type.new(:name => '/Foo/bar')
        }.should_not raise_error
    end

    it "should support :present as a value to :ensure" do
        lambda {
            mcx_type.new(:name => "/Foo/bar", :ensure => :present)
        }.should_not raise_error
    end

    it "should support :absent as a value to :ensure" do
        lambda {
            mcx_type.new(:name => "/Foo/bar", :ensure => :absent)
        }.should_not raise_error
    end

end
