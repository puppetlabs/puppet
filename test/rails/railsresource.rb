#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/rails'
require 'puppettest'
require 'puppettest/railstesting'
require 'puppettest/resourcetesting'

# Don't do any tests w/out this class
if defined? ActiveRecord::Base
class TestRailsResource < Test::Unit::TestCase
    include PuppetTest::RailsTesting
    include PuppetTest::ResourceTesting
    
    # Create a resource param from a rails parameter
    def test_to_resource
        railsinit
        
        # We need a host for resources
        host = Puppet::Rails::Host.new(:name => "myhost")

        # Now build a resource
        resource = host.resources.create(
            :title => "/tmp/to_resource", 
            :exported => true)
        
        # For some reason the child class doesn't exist until after the resource is created.
        # Probably an issue with the dynamic class generation.
        resource.type = "PuppetFile"  
        resource.save
  
        # Now add some params
        {"owner" => "root", "mode" => "644"}.each do |param, value|
            pn = resource.param_names.find_or_create_by_name(param)
            pv = pn.param_values.find_or_create_by_value(value)
            resource.param_names << pn
        end

        # Now save the whole thing
        host.save


        # We need a scope
        interp, scope, source = mkclassframing

        # Find the new resource and include all it's parameters.
        resource = Puppet::Rails::Resource.find_by_id(resource.id, :include => [ :param_names, :param_values ])

        # Now, try to convert our resource to a real resource
        res = nil
        assert_nothing_raised do
            res = resource.to_resource(scope)
        end
        assert_instance_of(Puppet::Parser::Resource, res)
        assert_equal("root", res[:owner])
        assert_equal("644", res[:mode])
        assert_equal("/tmp/to_resource", res.title)
        assert_equal(source, res.source)
    end
end
else
    $stderr.puts "Install Rails for Rails and Caching tests"
end

# $Id$
