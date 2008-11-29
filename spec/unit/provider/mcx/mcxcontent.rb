#! /usr/bin/env ruby
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

require File.dirname(__FILE__) + '/../../../spec_helper'

provider_class = Puppet::Type.type(:mcx).provider(:mcxcontent)

describe provider_class do

    before :each do
        # Create a mock resource
        @resource = stub 'resource'

        @provider = provider_class.new
        @attached_to = "/Users/katie"

        # A catch all; no parameters set
        @resource.stubs(:[]).returns(nil)

        # But set name, ensure and enable
        @resource.stubs(:[]).with(:name).returns @attached_to
        @resource.stubs(:[]).with(:enable).returns :true
        @resource.stubs(:ref).returns "Mcx[#{@attached_to}]"

        # stub out the provider methods that actually touch the filesystem
        # or execute commands
        @provider.stubs(:execute).returns("")
        @provider.stubs(:resource).returns @resource
    end

    it "should have a create method." do
        @provider.should respond_to(:create)
    end

    it "should have a destroy method." do
        @provider.should respond_to(:destroy)
    end

    it "should have an exists? method." do
        @provider.should respond_to(:exists?)
    end

    it "should have an content method." do
        @provider.should respond_to(:content)
    end

    it "should have an content= method." do
        @provider.should respond_to(:content=)
    end

end
