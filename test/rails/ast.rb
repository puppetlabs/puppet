#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/rails'
require 'puppet/parser/parser'
require 'puppettest/resourcetesting'
require 'puppettest/parsertesting'
require 'puppettest/railstesting'
require 'puppettest/support/collection'

class TestRailsAST < PuppetTest::TestCase
    confine "Missing rails" => Puppet.features.rails?
    include PuppetTest::RailsTesting
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    include PuppetTest::Support::Collection

    def test_exported_collexp
        railsinit
        Puppet[:storeconfigs] = true

        @scope = mkscope

        # make a rails resource
        railsresource "file", "/tmp/testing", :owner => "root", :group => "bin",
            :mode => "644" 

        run_collection_queries(:exported) do |string, result, query|
            code = nil
            str = nil

            # We don't support more than one search criteria at the moment.
            retval = nil
            bad = false
            # Figure out if the search is for anything rails will ignore
            if string =~ /\band\b|\bor\b/
                bad = true
            else
                bad = false
            end

            # And if it is, make sure we throw an error.
            if bad
                assert_raise(Puppet::ParseError, "Evaluated '#{string}'") do
                    str, code = query.evaluate :scope => @scope
                end
                next
            else
                assert_nothing_raised("Could not evaluate '#{string}'") do
                    str, code = query.evaluate :scope => @scope
                end
            end
            assert_nothing_raised("Could not find resource") do
                retval = Puppet::Rails::Resource.find(:all,
                    :include => {:param_values => :param_name},
                    :conditions => str) 
            end

            if result
                assert_equal(1, retval.length, "Did not find resource with '#{string}'")
                res = retval.shift

                assert_equal("file", res.restype)
                assert_equal("/tmp/testing", res.title)
            else
                assert_equal(0, retval.length, "found a resource with '#{string}'")
            end
        end
    end
end

