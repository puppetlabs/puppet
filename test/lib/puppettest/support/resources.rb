#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-11-29.
#  Copyright (c) 2006. All rights reserved.

module PuppetTest::Support::Resources
    def treefile(name)
        Puppet::Type.type(:file).create :path => "/tmp/#{name}", :mode => 0755
    end
    
    def treecomp(name)
        Puppet::Type::Component.create :name => name, :type => "yay"
    end
    
    def treenode(name, *children)
        comp = treecomp name
        children.each do |c| 
            if c.is_a?(String)
                comp.push treefile(c)
            else
                comp.push c
            end
        end
        return comp
    end
    
    def mktree
        one = treenode("one", "a", "b")
        two = treenode("two", "c", "d")
        middle = treenode("middle", "e", "f", two)
        top = treenode("top", "g", "h", middle, one)
        
        return one, two, middle, top
    end
end

# $Id$