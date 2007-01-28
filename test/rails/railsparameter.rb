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

        # Now create a source
        interp = mkinterp
        source = interp.newclass "myclass"
        
        #FIXME Need to re-add file/line support

        # Use array and non-array values, to make sure we get things back in
        # the same form.
        {"myname" => "myval", "multiple" => %w{one two three}}.each do |name, value|
            param = Puppet::Rails::ParamName.new(:name => name)
            if value.is_a? Array
                values = value
            else
                values = [value]
            end
            valueobjects = values.collect do |v|
                obj = Puppet::Rails::ParamValue.new(:value => v)
                assert_nothing_raised do
                    param.param_values << obj
                end
            end

            assert(param, "Did not create rails parameter")

            # The id doesn't get assigned until we save
            param.save

            # And try to convert our parameter
            pp = nil
            assert_nothing_raised do
                pp = param.to_resourceparam(source)
            end

            assert_instance_of(Puppet::Parser::Resource::Param, pp)
            assert_equal(name.to_sym, pp.name, "parameter name was not equal")
            assert_equal(value,  pp.value, "value was not equal for %s" % value.inspect)
        end
    end
end
else
    $stderr.puts "Install Rails for Rails and Caching tests"
end

# $Id$
