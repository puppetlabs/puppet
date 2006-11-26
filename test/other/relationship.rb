#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-11-24.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/relationship'

class TestRelationship < Test::Unit::TestCase
    include PuppetTest
    
    def test_initialize
        rel = Puppet::Relationship
        
        [["source", "target", "label"],
         ["source", "target", {:event => :nothing}]
        ].each do |ary|
            # Make sure the label is required
            assert_raise(Puppet::DevError) do
                rel.new(*ary)
            end
        end
    end
    
    def test_attributes
        rel = Puppet::Relationship
        
        i = nil
        assert_nothing_raised do
            i = rel.new "source", "target", :event => :yay, :callback => :boo
        end
        
        assert_equal(:yay, i.event, "event was not retrieved")
        assert_equal(:boo, i.callback, "callback was not retrieved")
        
        # Now try it with nil values
        assert_nothing_raised("failed to create with no event or callback") {
            i = rel.new "source", "target"
        }
        
        assert_nil(i.event, "event was not nil")
        assert_nil(i.callback, "callback was not nil")
    end
end

# $Id$