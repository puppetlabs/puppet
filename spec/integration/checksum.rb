#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-22.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/checksum'

describe Puppet::Checksum, " when using the file terminus" do
    before do
        Puppet::Checksum.terminus_class = :file
        @content = "this is some content"
        @sum = Puppet::Checksum.new(@content)

        @file = Puppet::Checksum.indirection.terminus.path(@sum.checksum)
    end

    it "should store content at a path determined by its checksum" do
        File.stubs(:directory?).returns(true)
        filehandle = mock 'filehandle'
        filehandle.expects(:print).with(@content)
        File.expects(:open).with(@file, "w").yields(filehandle)

        @sum.save
    end

    it "should retrieve stored content when the checksum is provided as the key" do
        File.stubs(:exist?).returns(true)
        File.expects(:read).with(@file).returns(@content)

        newsum = Puppet::Checksum.find(@sum.checksum)

        newsum.content.should == @content
    end

    it "should remove specified files when asked" do
        File.stubs(:exist?).returns(true)
        File.expects(:unlink).with(@file)

        Puppet::Checksum.destroy(@sum.name)
    end

    after do
        Puppet.settings.clear
    end
end
