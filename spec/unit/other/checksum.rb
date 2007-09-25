#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-22.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/checksum'

describe Puppet::Checksum do
    it "should have 'Checksum' and the checksum algorithm when converted to a string" do
        inst = Puppet::Checksum.new("whatever", "md5")
        inst.to_s.should == "Checksum<{md5}#{inst.checksum}>"
    end

    it "should convert algorithm names to symbols when they are set after checksum creation" do
        sum = Puppet::Checksum.new("whatever")
        sum.algorithm = "md5"
        sum.algorithm.should == :md5
    end

    it "should return the checksum as the name" do
        sum = Puppet::Checksum.new("whatever")
        sum.checksum.should == sum.name
    end
end

describe Puppet::Checksum, " when initializing" do
    before do
        @content = "this is some content"
        @sum = Puppet::Checksum.new(@content)
    end

    it "should require content" do
        proc { Puppet::Checksum.new(nil) }.should raise_error(ArgumentError)
    end

    it "should set the content appropriately" do
        @sum.content.should == @content
    end

    it "should calculate the checksum" do
        require 'digest/md5'
        Digest::MD5.expects(:hexdigest).with(@content).returns(:mychecksum)
        @sum.checksum.should == :mychecksum
    end

    it "should not calculate the checksum until it is asked for" do
        require 'digest/md5'
        Digest::MD5.expects(:hexdigest).never
        sum = Puppet::Checksum.new(@content, :md5)
    end

    it "should remove the old checksum value if the algorithm is changed" do
        Digest::MD5.expects(:hexdigest).with(@content).returns(:oldsum)
        oldsum = @sum.checksum
        @sum.algorithm = :sha1
        Digest::SHA1.expects(:hexdigest).with(@content).returns(:newsum)
        @sum.checksum.should == :newsum
    end

    it "should default to 'md5' as the checksum algorithm if the algorithm is not in the name" do
        @sum.algorithm.should == :md5
    end

    it "should support specifying the algorithm during initialization" do
        sum = Puppet::Checksum.new(@content, :sha1)
        sum.algorithm.should == :sha1
    end

    it "should fail when an unsupported algorithm is used" do
        proc { Puppet::Checksum.new(@content, :nope) }.should raise_error(ArgumentError)
    end
end

describe Puppet::Checksum, " when using back-ends" do
    it "should redirect using Puppet::Indirector" do
        Puppet::Indirector::Indirection.instance(:checksum).model.should equal(Puppet::Checksum)
    end

    it "should have a :save instance method" do
        Puppet::Checksum.new("mysum").should respond_to(:save)
    end

    it "should respond to :find" do
        Puppet::Checksum.should respond_to(:find)
    end

    it "should respond to :destroy" do
        Puppet::Checksum.should respond_to(:destroy)
    end
end
