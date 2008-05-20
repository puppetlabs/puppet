#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppettest'
require 'puppettest/support/utils'
require 'puppettest/fileparsing'

provider_class = Puppet::Type.type(:ssh_authorized_key).provider(:parsed)

describe provider_class do
    include PuppetTest
    include PuppetTest::FileParsing

    before :each do
        @sshauthkey_class = Puppet.type(:ssh_authorized_key)
        @provider = @sshauthkey_class.provider(:parsed)
    end

    after :each do
        @provider.initvars
    end

    def mkkey(args)
        fakeresource = fakeresource(:ssh_authorized_key, args[:name])

        key = @provider.new(fakeresource)
        args.each do |p,v|
            key.send(p.to_s + "=", v)
        end

        return key
    end

    def genkey(key)
        @provider.filetype = :ram
        file = @provider.default_target

        key.flush
        text = @provider.target_object(file).read
        return text
    end

    it "should be able to parse each example" do
        fakedata("data/providers/ssh_authorized_key/parsed").each { |file|
            puts "Parsing %s" % file
            fakedataparse(file)
        }
    end

    it "should be able to generate a basic authorized_keys file" do
        key = mkkey({
            :name => "Just Testing",
            :key => "AAAAfsfddsjldjgksdflgkjsfdlgkj",
            :type => "ssh-dss",
            :ensure => :present,
            :options => [:absent]
        })

        genkey(key).should == "ssh-dss AAAAfsfddsjldjgksdflgkjsfdlgkj Just Testing\n"
    end

    it "should be able to generate a authorized_keys file with options" do
        key = mkkey({
            :name => "root@localhost",
            :key => "AAAAfsfddsjldjgksdflgkjsfdlgkj",
            :type => "ssh-rsa",
            :ensure => :present,
            :options => ['from="192.168.1.1"', "no-pty", "no-X11-forwarding"]
        })

        genkey(key).should == "from=\"192.168.1.1\",no-pty,no-X11-forwarding ssh-rsa AAAAfsfddsjldjgksdflgkjsfdlgkj root@localhost\n"
    end
end
