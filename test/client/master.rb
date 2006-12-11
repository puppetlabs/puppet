#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/client'
require 'puppet/server'
require 'puppettest'

class TestMasterClient < Test::Unit::TestCase
    include PuppetTest::ServerTest
    
    class FakeTrans
        def initialize
            @counters = Hash.new { |h,k| h[k] = 0 }
        end
        [:evaluate, :report, :cleanup, :addtimes, :tags, :ignoreschedules].each do |m|
            define_method(m.to_s + "=") do |*args|
                @counters[m] += 1
            end
            define_method(m) do |*args|
                @counters[m] += 1
            end
            define_method(m.to_s + "?") do
                @counters[m]
            end
        end
    end
    class FakeComponent
        attr_accessor :trans
        def evaluate
            @trans = FakeTrans.new
            @trans
        end
    end

    def mkmaster(file = nil)
        master = nil

        file ||= mktestmanifest()
        # create our master
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Server::Master.new(
                :Manifest => file,
                :UseNodes => false,
                :Local => true
            )
        }
        return master
    end

    def mkclient(master = nil)
        master ||= mkmaster()
        client = nil
        assert_nothing_raised() {
            client = Puppet::Client::MasterClient.new(
                :Master => master
            )
        }

        return client
    end
    
    def mk_fake_client
        server = Puppet::Server::Master.new :Code => ""
        master = Puppet::Client::MasterClient.new :Server => server, :Local => true

        # Now create some objects
        objects = FakeComponent.new

        master.send(:instance_variable_set, "@objects", objects)

        class << master
            def report(r)
                @reported ||= 0
                @reported += 1
            end
            def reported
                @reported ||= 0
                @reported
            end
        end
        return master, objects
    end
    
    def test_apply
        master, objects = mk_fake_client
        
        check = Proc.new do |hash|
            assert(objects.trans, "transaction was not created")
            trans = objects.trans
            hash[:yes].each do |m|
                assert_equal(1, trans.send(m.to_s + "?"), "did not call #{m} enough times")
            end
            hash[:no].each do |m|
                assert_equal(0, trans.send(m.to_s + "?"), "called #{m} too many times")
            end
        end
        
        # First try it with no arguments
        assert_nothing_raised do
            master.apply
        end
        check.call :yes => %w{evaluate cleanup addtimes}, :no => %w{report tags ignoreschedules}
        assert_equal(0, master.reported, "master sent report with reports disabled")
        
        
        # Now enable reporting and make sure the report method gets called
        Puppet[:report] = true
        assert_nothing_raised do
            master.apply
        end
        check.call :yes => %w{evaluate cleanup addtimes}, :no => %w{tags ignoreschedules}
        assert_equal(1, master.reported, "master did not send report")
        
        # Now try it with tags enabled
        assert_nothing_raised do
            master.apply("tags")
        end
        check.call :yes => %w{evaluate cleanup tags addtimes}, :no => %w{ignoreschedules}
        assert_equal(2, master.reported, "master did not send report")
        
        # and ignoreschedules
        assert_nothing_raised do
            master.apply("tags", true)
        end
        check.call :yes => %w{evaluate cleanup tags ignoreschedules addtimes}, :no => %w{}
        assert_equal(3, master.reported, "master did not send report")
    end

    def test_disable
        manifest = mktestmanifest

        master = mkmaster(manifest)

        client = mkclient(master)

        assert(! FileTest.exists?(@createdfile))

        assert_nothing_raised {
            client.disable
        }

        assert_nothing_raised {
            client.run
        }

        assert(! FileTest.exists?(@createdfile), "Disabled client ran")

        assert_nothing_raised {
            client.enable
        }

        assert_nothing_raised {
            client.run
        }

        assert(FileTest.exists?(@createdfile), "Enabled client did not run")
    end

    # Make sure we're getting the client version in our list of facts
    def test_clientversionfact
        facts = nil
        assert_nothing_raised {
            facts = Puppet::Client::MasterClient.facts
        }

        assert_equal(Puppet.version.to_s, facts["clientversion"])
        
    end

    # Make sure the client correctly locks itself
    def test_locking
        manifest = mktestmanifest

        master = nil

        # First test with a networked master
        client = Puppet::Client::MasterClient.new(
            :Server => "localhost"
        )

        assert_nothing_raised do
            client.lock do
                pid = nil
                assert(client.locked?, "Client is not locked")
                assert(client.lockpid.is_a?(Integer), "PID #{client.lockpid} is, um, not a pid")
            end
        end
        assert(! client.locked?)

        # Now test with a local client
        client = mkclient

        assert_nothing_raised do
            client.lock do
                pid = nil
                assert(! client.locked?, "Local client is locked")
            end
        end
        assert(! client.locked?)
    end

    # Make sure non-string facts don't make things go kablooie
    def test_nonstring_facts
        # Add a nonstring fact
        Facter.add("nonstring") do
            setcode { 1 }
        end

        assert_equal(1, Facter.nonstring, "Fact was a string from facter")

        client = mkclient()

        assert(! FileTest.exists?(@createdfile))

        assert_nothing_raised {
            client.run
        }
    end
    
    # This method is supposed
    def test_download
        source = tempfile()
        dest = tempfile()
        sfile = File.join(source, "file")
        dfile = File.join(dest, "file")
        Dir.mkdir(source)
        File.open(sfile, "w") {|f| f.puts "yay"}
        
        files = []
        assert_nothing_raised do
            files = Puppet::Client::MasterClient.download(:dest => dest, :source => source, :name => "testing")
        end
        
        assert(FileTest.directory?(dest), "dest dir was not created")
        assert(FileTest.file?(dfile), "dest file was not created")
        assert_equal(File.read(sfile), File.read(dfile), "Dest file had incorrect contents")
        assert_equal([dest, dfile].sort, files.sort, "Changed files were not returned correctly")
    end

    def test_getplugins
        Puppet[:pluginsource] = tempfile()
        Dir.mkdir(Puppet[:pluginsource])

        myplugin = File.join(Puppet[:pluginsource], "myplugin.rb")
        File.open(myplugin, "w") do |f|
            f.puts %{Puppet::Type.newtype(:myplugin) do
    newparam(:argument) do
        isnamevar
    end
end
}
        end

        assert_nothing_raised {
            Puppet::Client::MasterClient.getplugins
        }

        destfile = File.join(Puppet[:plugindest], "myplugin.rb")

        assert(File.exists?(destfile), "Did not get plugin")

        obj = Puppet::Type.type(:myplugin)

        assert(obj, "Did not define type")

        assert(obj.validattr?(:argument),
            "Did not get namevar")

        # Now modify the file and make sure the type is replaced
        File.open(myplugin, "w") do |f|
            f.puts %{Puppet::Type.newtype(:myplugin) do
    newparam(:yayness) do
        isnamevar
    end

    newparam(:rahness) do
    end
end
}
        end

        assert_nothing_raised {
            Puppet::Client::MasterClient.getplugins
        }

        destfile = File.join(Puppet[:pluginpath], "myplugin.rb")

        obj = Puppet::Type.type(:myplugin)

        assert(obj, "Did not define type")

        assert(obj.validattr?(:yayness),
            "Did not get namevar")

        assert(obj.validattr?(:rahness),
            "Did not get other var")

        assert(! obj.validattr?(:argument),
            "Old namevar is still valid")

        # Now try it again, to make sure we don't have any objects lying around
        assert_nothing_raised {
            Puppet::Client::MasterClient.getplugins
        }
    end

    def test_getfacts
        Puppet[:factsource] = tempfile()
        Dir.mkdir(Puppet[:factsource])
        hostname = Facter.value(:hostname)

        myfact = File.join(Puppet[:factsource], "myfact.rb")
        File.open(myfact, "w") do |f|
            f.puts %{Facter.add("myfact") do
            setcode { "yayness" }
end
}
        end

        assert_nothing_raised {
            Puppet::Client::MasterClient.getfacts
        }

        destfile = File.join(Puppet[:factdest], "myfact.rb")

        assert(File.exists?(destfile), "Did not get fact")

        assert_equal(hostname, Facter.value(:hostname),
            "Lost value to hostname")
        assert_equal("yayness", Facter.value(:myfact),
            "Did not get correct fact value")

        # Now modify the file and make sure the type is replaced
        File.open(myfact, "w") do |f|
            f.puts %{Facter.add("myfact") do
            setcode { "funtest" }
end
}
        end

        assert_nothing_raised {
            Puppet::Client::MasterClient.getfacts
        }

        assert_equal("funtest", Facter.value(:myfact),
            "Did not reload fact")
        assert_equal(hostname, Facter.value(:hostname),
            "Lost value to hostname")

        # Now run it again and make sure the fact still loads
        assert_nothing_raised {
            Puppet::Client::MasterClient.getfacts
        }

        assert_equal("funtest", Facter.value(:myfact),
            "Did not reload fact")
        assert_equal(hostname, Facter.value(:hostname),
            "Lost value to hostname")
    end

    # Make sure we load all facts on startup.
    def test_loadfacts
        dirs = [tempfile(), tempfile()]
        count = 0
        names = []
        dirs.each do |dir|
            Dir.mkdir(dir)
            name = "fact%s" % count
            names << name
            file = File.join(dir, "%s.rb" % name)

            # Write out a plugin file
            File.open(file, "w") do |f|
                f.puts %{Facter.add("#{name}") do setcode { "#{name}" } end }
            end
            count += 1
        end

        Puppet[:factpath] = dirs.join(":")

        names.each do |name|
            assert_nil(Facter.value(name), "Somehow retrieved invalid fact")
        end

        assert_nothing_raised {
            Puppet::Client::MasterClient.loadfacts
        }

        names.each do |name|
            assert_equal(name, Facter.value(name),
                    "Did not retrieve facts")
        end
    end

    if Process.uid == 0
    # Testing #283.  Make sure plugins et al are downloaded as the running user.
    def test_download_ownership
        dir = tstdir()
        dest = tstdir()
        file = File.join(dir, "file")
        File.open(file, "w") { |f| f.puts "funtest" }

        user = nonrootuser()
        group = nonrootgroup()
        FileUtils.chown_R(user.name, group.name, dir)

        assert_equal(user.uid, File.stat(file).uid)
        assert_equal(group.gid, File.stat(file).gid)


        assert_nothing_raised {
            Puppet::Client::MasterClient.download(:dest => dest, :source => dir,
                :name => "testing"
            ) {}
        }

        destfile = File.join(dest, "file")

        assert(FileTest.exists?(destfile), "Did not create destfile")

        assert_equal(Process.uid, File.stat(destfile).uid)
    end
    end
end

# $Id$
