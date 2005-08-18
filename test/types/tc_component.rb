if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'puppettest'
require 'test/unit'

# $Id$

class TestComponent < TestPuppet
    def setup
        @@used = {}
        super
    end

    def teardown
        assert_nothing_raised() {
            Puppet::Type.allclear
        }
        super
    end

    def randnum(limit)
        num = nil
        loop do
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
        name = "/tmp/componentrandfile" + num.to_s

        file = Puppet::Type::PFile.new(
            :path => name,
            :checksum => "md5"
        )
        @@tmpfiles << name
        file
    end

    def mkcomp
        comp = Puppet::Type::Component.new(:name => "component_" + randnum(1000).to_s)
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

        comp
    end

    def test_ordering
        list = nil
        comp = mkrandcomp(30,5)
        assert_nothing_raised {
            list = comp.flatten
        }

        list.each_with_index { |obj, index|
            obj.eachdependency { |dep|
                assert(list.index(dep) < index)
            }
        }
    end
end
