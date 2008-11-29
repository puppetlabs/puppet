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
 
require "puppet/type/mcx"

describe Puppet::Type.type(:mcx), "when validating attributes" do

    [:name, :ds_type, :ds_name].each do |param|
        it "should have a #{param} parameter" do
            Puppet::Type.type(:mcx).attrtype(param).should == :param
        end
    end

    [:ensure, :content].each do |param|
        it "should have a #{param} property" do
            Puppet::Type.type(:mcx).attrtype(param).should == :property
        end
    end

end

describe Puppet::Type.type(:mcx), "when validating attribute values" do

    before do
        @provider = stub 'provider', :class => Puppet::Type.type(:mcx).defaultprovider, :clear => nil, :controllable? => false
        Puppet::Type.type(:mcx).defaultprovider.stubs(:new).returns(@provider)
    end

    after do
        Puppet::Type.type(:mcx).clear
    end

    it "should support :present as a value to :ensure" do
        Puppet::Type.type(:mcx).create(:name => "/Foo/bar", :ensure => :present)
    end

    it "should support :absent as a value to :ensure" do
        Puppet::Type.type(:mcx).create(:name => "/Foo/bar", :ensure => :absent)
    end

end
