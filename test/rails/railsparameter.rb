#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppet/rails'
require 'puppettest'
require 'puppettest/railstesting'

# Don't do any tests w/out this class
if defined? ::ActiveRecord::Base
class TestRailsParameter < Test::Unit::TestCase
  include PuppetTest::RailsTesting

  def params
    {"myname" => "myval", "multiple" => %w{one two three}}
  end

  # Create a resource param from a rails parameter
  def test_to_resourceparam
    railsinit

    # Now create a source
    parser = mkparser
    source = parser.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "myclass")

    host = Puppet::Rails::Host.new(:name => "myhost")

    host.save


      resource = host.resources.create(

        :title => "/tmp/to_resource",
        :restype => "file",

        :exported => true)

    # Use array and non-array values, to make sure we get things back in
    # the same form.
    params.each do |name, value|
      param = Puppet::Rails::ParamName.find_or_create_by_name(name)
      if value.is_a? Array
        values = value
      else
        values = [value]
      end
      valueobjects = values.collect do |v|

        resource.param_values.create(
          :value => v,

            :param_name => param)
      end

      assert(param, "Did not create rails parameter")

      # The id doesn't get assigned until we save
    end

    resource.save

    # And try to convert our parameter
    params.each do |name, value|
      param = Puppet::Rails::ParamName.find_by_name(name)
      pp = nil
      assert_nothing_raised do
        pp = param.to_resourceparam(resource, source)
      end

      assert_instance_of(Puppet::Parser::Resource::Param, pp)
      assert_equal(name.to_sym, pp.name, "parameter name was not equal")
      assert_equal(value,  pp.value, "value was not equal for #{value.inspect}")
    end
  end
end
else
  $stderr.puts "Install Rails for Rails and Caching tests"
end

