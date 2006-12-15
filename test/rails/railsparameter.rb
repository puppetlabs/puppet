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
        #FIXME Need to re-add file/line support
        pname = { :name => "myname" }
        pvalue = { :value => "myval" }
            pn = Puppet::Rails::ParamName.new(:name => pname[:name])
            pv = Puppet::Rails::ParamValue.new(:value => pvalue[:value])
        assert_nothing_raised do
            pn.param_values << pv
        end

        assert(pn, "Did not create rails parameter")

        # The id doesn't get assigned until we save
        pn.save

        # Now create a source
        interp = mkinterp
        source = interp.newclass "myclass"

        # And try to convert our parameter
        #FIXME Why does this assert prevent the block from executing?
        #assert_nothing_raised do
            pp = pn.to_resourceparam(source)
        #end

        assert_instance_of(Puppet::Parser::Resource::Param, pp)
        pname.each do |name, value|
            assert_equal(value.to_sym,  pp.send(name), "%s was not equal" % name)
        end
    end
end
else
    $stderr.puts "Install Rails for Rails and Caching tests"
end

# $Id$
