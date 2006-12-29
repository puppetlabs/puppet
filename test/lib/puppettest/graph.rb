#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-11-24.
#  Copyright (c) 2006. All rights reserved.

require 'puppet/util/graph'

class Container
    include Puppet::Util::Graph
    include Enumerable
    attr_accessor :name
    def each
        @children.each do |c| yield c end
    end
    
    def initialize(name, ary)
        @name = name
        @children = ary
    end
    
    def push(*ary)
        ary.each { |c| @children.push(c)}
    end
    
    def to_s
        @name
    end
end
    
module PuppetTest::Graph
    def build_tree
        one = Container.new("one", %w{a b})
        two = Container.new("two", ["c", "d"])
        three = Container.new("three", ["i", "j"])
        middle = Container.new("middle", ["e", "f", two])
        top = Container.new("top", ["g", "h", middle, one, three])
        return one, two, three, middle, top
    end
end

# $Id$
