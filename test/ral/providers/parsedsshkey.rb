#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/fileparsing'
require 'puppet/type/sshkey'

class TestParsedSSHKey < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::FileParsing

    def setup
        super
        @provider = Puppet.type(:sshkey).provider(:parsed)

        @oldfiletype = @provider.filetype
    end

    def teardown
        Puppet::Util::FileType.filetype(:ram).clear
        @provider.filetype = @oldfiletype
        @provider.clear
        super
    end
    
    def mkkey(name = "host.domain.com")
        if defined? @pcount
            @pcount += 1
        else
            @pcount = 1
        end
        args = {
            :name => name || "/fspuppet%s" % @pcount,
            :key => "thisismykey%s" % @pcount,
            :alias => ["host1.domain.com","192.168.0.1"],
            :type => "dss",
            :ensure => :present
        }

        fakemodel = fakemodel(:sshkey, args[:name])

        key = @provider.new(fakemodel)
        args.each do |p,v|
            key.send(p.to_s + "=", v)
        end

        return key
    end

    def test_keysparse
        fakedata("data/types/sshkey").each { |file|
            fakedataparse(file)
        }
    end
    
    def test_simplekey
        @provider.filetype = :ram
        file = @provider.default_target
        
        key = nil
        assert_nothing_raised do
            key = mkkey
        end
        
        assert(key, "did not create key")
        
        assert_nothing_raised do
            key.flush
        end
        
        assert(key.alias, "No alias set for key")
        
        hash = key.property_hash.dup
        text = @provider.target_object(file).read
        names = [key.name, key.alias].flatten.join(",")
        
        assert_equal("#{names} #{key.type} #{key.key}\n", text)
        
        assert_nothing_raised do
            @provider.prefetch
        end
        
        hash.each do |p, v|
            next unless key.respond_to?(p)
            assert_equal(v, key.send(p), "%s did not match" % p)
        end
        
        assert(key.name !~ /,/, "Aliases were not split out during parsing")
    end
end

# $Id$
