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
        looped = 0
        loop do
            looped += 1
            if looped > 1000
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
        name = "/tmp/componentrandfile" + num.to_s

        file = Puppet::Type::PFile.new(
            :path => name,
            :checksum => "md5"
        )
        @@tmpfiles << name
        file
    end

    def mkcomp
        Puppet::Type::Component.new(:name => "component_" + randnum(1000).to_s)
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

    def test_correctsorting
        tmpfile = "/tmp/comptesting"
        @@tmpfiles.push tmpfile
        trans = nil
        cmd = nil
        File.open(tmpfile, File::WRONLY|File::CREAT|File::TRUNC) { |of|
            of.puts rand(100)
        }
        file = Puppet::Type::PFile.new(
            :path => tmpfile,
            :checksum => "md5"
        )
        assert_nothing_raised {
            cmd = Puppet::Type::Exec.new(
                :command => "pwd",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :subscribe => [[file.class.name,file.name]],
                :refreshonly => true
            )
        }

        order = nil
        assert_nothing_raised {
            order = Puppet::Type::Component.sort([file, cmd])
        }

        [cmd, file].each { |obj|
            assert_equal(1, order.find_all { |o| o.name == obj.name }.length)
        }
    end

    def test_correctflattening
        tmpfile = "/tmp/comptesting"
        @@tmpfiles.push tmpfile
        trans = nil
        cmd = nil
        File.open(tmpfile, File::WRONLY|File::CREAT|File::TRUNC) { |of|
            of.puts rand(100)
        }
        file = Puppet::Type::PFile.new(
            :path => tmpfile,
            :checksum => "md5"
        )
        assert_nothing_raised {
            cmd = Puppet::Type::Exec.new(
                :command => "pwd",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :subscribe => [[file.class.name,file.name]],
                :refreshonly => true
            )
        }

        comp = Puppet::Type::Component.new(:name => "RefreshTest")
        [cmd, file].each { |obj|
            comp.push obj
        }
        objects = nil
        assert_nothing_raised {
            objects = comp.flatten
        }

        [cmd, file].each { |obj|
            assert_equal(1, objects.find_all { |o| o.name == obj.name }.length)
        }

        assert(objects[0] == file, "File was not first object")
        assert(objects[1] == cmd, "Exec was not second object")
    end

    def test_deepflatten
        tmpfile = tempfile()
        @@tmpfiles.push tmpfile
        trans = nil
        cmd = nil
        File.open(tmpfile, File::WRONLY|File::CREAT|File::TRUNC) { |of|
            of.puts rand(100)
        }
        file = Puppet::Type::PFile.new(
            :path => tmpfile,
            :checksum => "md5"
        )
        assert_nothing_raised {
            cmd = Puppet::Type::Exec.new(
                :command => "pwd",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :refreshonly => true
            )
        }

        fcomp = newcomp("fflatten", file)
        ecomp = newcomp("eflatten", cmd)

        # this subscription can screw up the sorting
        ecomp[:subscribe] = [[fcomp.class.name,fcomp.name]]

        comp = newcomp("bflatten", ecomp, fcomp)
        objects = nil
        assert_nothing_raised {
            objects = comp.flatten
        }

        assert_equal(objects.length, 2, "Did not get two sorted objects")
        objects.each { |o|
            assert(o.is_a?(Puppet::Type), "Object %s is not a Type" % o.class)
        }

        assert(objects[0] == file, "File was not first object")
        assert(objects[1] == cmd, "Exec was not second object")
    end

    def test_deepflatten2
        tmpfile = tempfile()
        @@tmpfiles.push tmpfile
        trans = nil
        cmd = nil
        File.open(tmpfile, File::WRONLY|File::CREAT|File::TRUNC) { |of|
            of.puts rand(100)
        }
        file = Puppet::Type::PFile.new(
            :path => tmpfile,
            :checksum => "md5"
        )
        assert_nothing_raised {
            cmd = Puppet::Type::Exec.new(
                :command => "pwd",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :refreshonly => true
            )
        }

        ocmd = nil
        assert_nothing_raised {
            ocmd = Puppet::Type::Exec.new(
                :command => "echo true",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :refreshonly => true
            )
        }

        fcomp = newcomp("fflatten", file)
        ecomp = newcomp("eflatten", cmd)
        ocomp = newcomp("oflatten", ocmd)

        # this subscription can screw up the sorting
        cmd[:subscribe] = [[fcomp.class.name,fcomp.name]]
        ocmd[:subscribe] = [[cmd.class.name,cmd.name]]

        comp = newcomp("bflatten", ocomp, ecomp, fcomp)
        objects = nil
        assert_nothing_raised {
            objects = comp.flatten
        }

        assert_equal(objects.length, 3, "Did not get three sorted objects")

        objects.each { |o|
            assert(o.is_a?(Puppet::Type), "Object %s is not a Type" % o.class)
        }

        assert(objects[0] == file, "File was not first object")
        assert(objects[1] == cmd, "Exec was not second object")
        assert(objects[2] == ocmd, "Other exec was not second object")
    end
end
