#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/rails'
require 'puppettest'
require 'puppettest/railstesting'
require 'puppettest/resourcetesting'

# Don't do any tests w/out this class
if Puppet.features.rails?
class TestRailsResource < Test::Unit::TestCase
    include PuppetTest::RailsTesting
    include PuppetTest::ResourceTesting

    def setup
        super
        railsinit
    end

    def teardown
        railsteardown
        super
    end

    def mktest_resource
        # We need a host for resources
        host = Puppet::Rails::Host.new(:name => "myhost")

        # Now build a resource
        resource = host.resources.create(
            :title => "/tmp/to_resource", 
            :restype => "file",
            :exported => true)

        # Now add some params
        params.each do |param, value|
            pn = resource.params.find_or_create_by_name_and_value(param, value)
            resource.params << pn
        end

        host.save

        return resource
    end
    
    def params
        {"owner" => "root", "mode" => "644"}
    end

    # Create a resource param from a rails parameter
    def test_to_resource
        resource = mktest_resource

        # We need a scope
        interp, scope, source = mkclassframing

        # Find the new resource and include all it's parameters.
        resource = Puppet::Rails::Resource.find_by_id(resource.id, :include => [ :params ])

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

    def test_parameters
        resource = mktest_resource

        setparams = nil
        assert_nothing_raised do
            setparams = resource.parameters
        end
        assert_equal(params, setparams,
            "Did not get the right answer from #parameters")
    end

    # Make sure we can retrieve individual parameters by name.
    def test_parameter
        resource = mktest_resource

        params.each do |p,v|
            assert_equal(v, resource.parameter(p), "%s is not correct" % p)
        end
    end
end
else
    $stderr.puts "Install Rails for Rails and Caching tests"
end

# $Id$

