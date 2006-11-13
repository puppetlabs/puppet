#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/rails'
require 'puppettest'
require 'puppettest/railstesting'

# Don't do any tests w/out this class
if defined? ActiveRecord::Base
class TestRailsParameter < Test::Unit::TestCase
    include PuppetTest::RailsTesting
    
    # Create a resource param from a rails parameter
    def test_to_resourceparam
        railsinit
        # First create our parameter
        rparam = nil
        hash = { :name => :myparam, :value => "myval",
                :file => __FILE__, :line => __LINE__}
        assert_nothing_raised do
            rparam = Puppet::Rails::RailsParameter.new(hash)
        end

        assert(rparam, "Did not create rails parameter")

        # The id doesn't get assigned until we save
        rparam.save

        # Now create a source
        interp = mkinterp
        source = interp.newclass "myclass"

        # And try to convert our parameter
        pparam = nil
        assert_nothing_raised do
            pparam = rparam.to_resourceparam(source)
        end


        assert_instance_of(Puppet::Parser::Resource::Param, pparam)
        hash.each do |name, value|
            assert_equal(value,  pparam.send(name), "%s was not equal" % name)
        end
    end
end
else
    $stderr.puts "Install Rails for Rails and Caching tests"
end

# $Id$
