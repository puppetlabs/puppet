#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/support/resources'

# $Id$

class TestComponent < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::Support::Resources
    def setup
        super
        @@used = {}
        @type = Puppet::Type::Component
        @file = Puppet::Type.type(:file)
    end

    def randnum(limit)
        num = nil
        looped = 0
        loop do
            looped += 1
            if looped > 2000
                raise "Reached limit of looping"
                break
            end
            num = rand(limit)
            unless @@used.include?(num)
                @@used[num] = true
                break
            end
        end

        num
    end

    def mkfile(num = nil)
        unless num
            num = randnum(1000)
        end
        name = tempfile() + num.to_s

        file = Puppet.type(:file).create(
            :path => name,
            :checksum => "md5"
        )
        @@tmpfiles << name
        file
    end

    def mkcomp
        Puppet.type(:component).create(:name => "component_" + randnum(1000).to_s)
    end

    def mkrandcomp(numfiles, numdivs)
        comp = mkcomp
        hash = {}
        found = 0

        divs = {}

        numdivs.times { |i|
            num = i + 2
            divs[num] = nil
        }
        while found < numfiles
            num = randnum(numfiles)
            found += 1
            f = mkfile(num)
            hash[f.name] = f
            reqd = []
            divs.each { |n,obj|
                if rand(50) % n == 0
                    if obj
                        unless reqd.include?(obj.object_id)
                            f[:require] = [[obj.class.name, obj.name]]
                            reqd << obj.object_id
                        end
                    end
                end

                divs[n] = f
            }
        end

        hash.each { |name, obj|
            comp.push obj
        }

        comp.finalize
        comp
    end
        
    def test_to_graph
        one, two, middle, top = mktree
        
        graph = nil
        assert_nothing_raised do
            graph = top.to_graph
        end
        
        assert(graph.is_a?(Puppet::PGraph), "result is not a pgraph")
        
        [one, two, middle, top].each do |comp|
            comp.each do |child|
                assert(graph.edge?(comp, child),
                    "Did not create edge from %s => %s" % [comp.name, child.name])
            end
        end
    end
end
