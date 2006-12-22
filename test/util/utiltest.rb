#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppettest'

class TestPuppetUtil < Test::Unit::TestCase
    include PuppetTest

    # we're getting corrupt files, probably because multiple processes
    # are reading or writing the file at once
    # so we need to test that
    def test_multiwrite
        file = tempfile()
        File.open(file, "w") { |f| f.puts "starting" }

        value = {:a => :b}
        threads = []
        sync = Sync.new
        9.times { |a|
            threads << Thread.new {
                9.times { |b|
                    assert_nothing_raised {
                        sync.synchronize(Sync::SH) {
                            Puppet::Util.readlock(file) { |f|
                                f.read
                            }
                        }
                        sleep 0.01
                        sync.synchronize(Sync::EX) {
                            Puppet::Util.writelock(file) { |f|
                                f.puts "%s %s" % [a, b]
                            }
                        }
                    }
                }
            }
        }
        threads.each { |th| th.join }
    end


    def test_withumask
        oldmask = File.umask

        path = tempfile()

        # FIXME this fails on FreeBSD with a mode of 01777
        Puppet::Util.withumask(000) do
            Dir.mkdir(path, 0777)
        end

        assert(File.stat(path).mode & 007777 == 0777, "File has the incorrect mode")
        assert_equal(oldmask, File.umask, "Umask was not reset")
    end

    def test_benchmark
        path = tempfile()
        str = "yayness"
        File.open(path, "w") do |f| f.print "yayness" end

        # First test it with the normal args
        assert_nothing_raised do
            val = nil
            result = Puppet::Util.benchmark(:notice, "Read file") do
                val = File.read(path)
            end

            assert_equal(str, val)

            assert_instance_of(Float, result)

        end

        # Now test it with a passed object
        assert_nothing_raised do
            val = nil
            Puppet::Util.benchmark(Puppet, :notice, "Read file") do
                val = File.read(path)
            end

            assert_equal(str, val)
        end
    end

    unless Puppet::SUIDManager.uid == 0
        $stderr.puts "Run as root to perform Utility tests"
        def test_nothing
        end
    else

    def mknverify(file, user, group = nil, id = false)
        if File.exists?(file)
            File.unlink(file)
        end
        args = []
        unless user or group
            args << nil
        end
        if user
            if id
                args << user.uid
            else
                args << user.name
            end
        end

        if group
            if id
                args << group.gid
            else
                args << group.name
            end
        end

        gid = nil
        if group
            gid = group.gid
        else
            gid = Puppet::SUIDManager.gid
        end

        uid = nil
        if user
            uid = user.uid
        else
            uid = Puppet::SUIDManager.uid
        end

        assert_nothing_raised {
            Puppet::SUIDManager.asuser(*args) {
                assert_equal(Puppet::SUIDManager.euid, uid, "UID is %s instead of %s" %
                    [Puppet::SUIDManager.euid, uid]
                )
                assert_equal(Puppet::SUIDManager.egid, gid, "GID is %s instead of %s" %
                    [Puppet::SUIDManager.egid, gid]
                )
                system("touch %s" % file)
            }
        }
        if uid == 0
            #Puppet.warning "Not testing user"
        else
            #Puppet.warning "Testing user %s" % uid
            assert(File.exists?(file), "File does not exist")
            assert_equal(File.stat(file).uid, uid,
                "File is owned by %s instead of %s" %
                [File.stat(file).uid, uid]
            )
            #system("ls -l %s" % file)
        end
        # I'm skipping these, because it seems so system dependent.
        #if gid == 0
        #    #Puppet.warning "Not testing group"
        #else
        #    Puppet.warning "Testing group %s" % gid.inspect
        #    system("ls -l %s" % file)
        #    assert_equal(gid, File.stat(file).gid,
        #        "File group is %s instead of %s" %
        #        [File.stat(file).gid, gid]
        #    )
        #end
        assert_nothing_raised {
            File.unlink(file)
        }
    end

    def test_asuser
        file = File.join(tmpdir, "asusertest")
        @@tmpfiles << file
        [
            [nil], # Nothing
            [nonrootuser()], # just user, by name
            [nonrootuser(), nil, true], # user, by uid
            [nonrootuser(), nonrootgroup()], # user and group, by name
            [nonrootuser(), nonrootgroup(), true], # user and group, by id
        ].each { |ary|
            mknverify(file, *ary)
        }
    end

    # Verify that we get reset back to the right user
    def test_asuser_recovery
        begin
            Puppet::Util.asuser(nonrootuser()) {
                raise "an error"
            }
        rescue
        end

        assert(Puppet::SUIDManager.euid == 0, "UID did not get reset")
    end
    end

    def test_proxy
        klass = Class.new do
            attr_accessor :hash
            class << self
                attr_accessor :ohash
            end
        end
        klass.send(:include, Puppet::Util)

        klass.ohash = {}

        inst = klass.new
        inst.hash = {}
        assert_nothing_raised do
            Puppet::Util.proxy klass, :hash, "[]", "[]=", :clear, :delete
        end

        assert_nothing_raised do
            Puppet::Util.classproxy klass, :ohash, "[]", "[]=", :clear, :delete
        end

        assert_nothing_raised do
            inst[:yay] = "boo"
            inst["cool"] = :yayness
        end

        [:yay, "cool"].each do |var|
            assert_equal(inst.hash[var], inst[var],
                        "Var %s did not take" % var)
        end

        assert_nothing_raised do
            klass[:Yay] = "boo"
            klass["Cool"] = :yayness
        end

        [:Yay, "Cool"].each do |var|
            assert_equal(inst.hash[var], inst[var],
                        "Var %s did not take" % var)
        end
    end

    def test_symbolize
        ret = nil
        assert_nothing_raised {
            ret = Puppet::Util.symbolize("yayness")
        }

        assert_equal(:yayness, ret)

        assert_nothing_raised {
            ret = Puppet::Util.symbolize(:yayness)
        }

        assert_equal(:yayness, ret)

        assert_nothing_raised {
            ret = Puppet::Util.symbolize(43)
        }

        assert_equal(43, ret)

        assert_nothing_raised {
            ret = Puppet::Util.symbolize(nil)
        }

        assert_equal(nil, ret)
    end
    
    def test_execute
        command = tempfile()
        File.open(command, "w") { |f|
            f.puts %{#!/bin/sh\n/bin/echo "$1">&1; echo "$2">&2}
        }
        File.chmod(0755, command)
        output = nil
        assert_nothing_raised do
            output = Puppet::Util.execute([command, "yaytest", "funtest"])
        end
        assert_equal("yaytest\nfuntest\n", output)
        
        # Now try it with a single quote
        assert_nothing_raised do
            output = Puppet::Util.execute([command, "yay'test", "funtest"])
            # output = Puppet::Util.execute(command)
            
        end
        assert_equal("yay'test\nfuntest\n", output)
        
        # Now test that we correctly fail if the command returns non-zero
        assert_raise(Puppet::ExecutionFailure) do
            out = Puppet::Util.execute(["touch", "/no/such/file/could/exist"])
        end
        
        # And that we can tell it not to fail
        assert_nothing_raised() do
            out = Puppet::Util.execute(["touch", "/no/such/file/could/exist"], false)
        end
        
        if Process.uid == 0
            # Make sure we correctly set our uid and gid
            user = nonrootuser
            group = nonrootgroup
            file = tempfile()
            assert_nothing_raised do
                Puppet::Util.execute(["touch", file], true, user.name, group.name)
            end
            assert(FileTest.exists?(file), "file was not created")
            assert_equal(user.uid, File.stat(file).uid, "uid was not set correctly")
            
            # We can't really check the gid, because it just behaves too inconsistently everywhere.
            # assert_equal(group.gid, File.stat(file).gid, "gid was not set correctly")
        end
    end
    
    def test_string_exec
        cmd = "/bin/echo howdy"
        output = nil
        assert_nothing_raised {
            output = Puppet::Util.execute(cmd)
        }
        assert_equal("howdy\n", output)
        assert_raise(RuntimeError) {
            Puppet::Util.execute(cmd, 0, 0)
        }
    end

    # This is mostly to test #380.
    def test_get_provider_value
        group = Puppet::Type.type(:group).create :name => "yayness", :ensure => :present
        
        root = Puppet::Type.type(:user).create :name => "root", :ensure => :present
        
        val = nil
        assert_nothing_raised do
            val = Puppet::Util.get_provider_value(:group, :gid, "yayness")
        end
        assert_nil(val, "returned a value on a missing group")
        
        # Now make sure we get a value for one we know exists
        assert_nothing_raised do
            val = Puppet::Util.get_provider_value(:user, :uid, "root")
        end
        assert_equal(0, val, "got invalid uid for root")
    end
end

# $Id$
