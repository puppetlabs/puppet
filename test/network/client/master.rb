#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'mocha'

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
        
        def finalize
            @finalized = true
        end
        
        def finalized?
            @finalized
        end
    end

    def setup
        super
        @master = Puppet::Network::Client.master
    end

    def mkmaster(file = nil)
        master = nil

        file ||= mktestmanifest()
        # create our master
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Network::Handler.master.new(
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
            client = Puppet::Network::Client.master.new(
                :Master => master
            )
        }

        return client
    end
    
    def mk_fake_client
        server = Puppet::Network::Handler.master.new :Code => ""
        master = Puppet::Network::Client.master.new :Server => server, :Local => true

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
    
    def test_getconfig
        client = mkclient
        
        $methodsrun = []
        cleanup { $methodsrun = nil }
        client.meta_def(:getplugins) do
            $methodsrun << :getplugins
        end
        client.meta_def(:get_actual_config) do
            $methodsrun << :get_actual_config
            result = Puppet::TransBucket.new()
            result.type = "testing"
            result.name = "yayness"
            result
        end
        
        assert_nothing_raised do
            client.getconfig
        end
        [:get_actual_config].each do |method|
            assert($methodsrun.include?(method), "method %s was not run" % method)
        end
        assert(! $methodsrun.include?(:getplugins), "plugins were synced even tho disabled")

        # Now set pluginsync
        Puppet[:pluginsync] = true
        $methodsrun.clear
        
        assert_nothing_raised do
            client.getconfig
        end
        [:getplugins, :get_actual_config].each do |method|
            assert($methodsrun.include?(method), "method %s was not run" % method)
        end
        
        objects = client.objects
        assert(objects.finalized?, "objects were not finalized")
    end

    def test_disable
        FileUtils.mkdir_p(Puppet[:statedir])
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
            facts = Puppet::Network::Client.master.facts
        }

        assert_equal(Puppet.version.to_s, facts["clientversion"])
        
    end

    # Make sure non-string facts don't make things go kablooie
    def test_nonstring_facts
        FileUtils.mkdir_p(Puppet[:statedir])
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
            files = Puppet::Network::Client.master.download(:dest => dest, :source => source, :name => "testing")
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
            Puppet::Network::Client.master.getplugins
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
            Puppet::Network::Client.master.getplugins
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
            Puppet::Network::Client.master.getplugins
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
            Puppet::Network::Client.master.getfacts
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
            Puppet::Network::Client.master.getfacts
        }

        assert_equal("funtest", Facter.value(:myfact),
            "Did not reload fact")
        assert_equal(hostname, Facter.value(:hostname),
            "Lost value to hostname")

        # Now run it again and make sure the fact still loads
        assert_nothing_raised {
            Puppet::Network::Client.master.getfacts
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
            Puppet::Network::Client.master.loadfacts
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
        chowner = Puppet::Type.type(:file).create :path => dir,
            :owner => user.name, :group => group.name, :recurse => true
        assert_apply(chowner)
        chowner.remove

        assert_equal(user.uid, File.stat(file).uid)
        assert_equal(group.gid, File.stat(file).gid)


        assert_nothing_raised {
            Puppet::Network::Client.master.download(:dest => dest, :source => dir,
                :name => "testing"
            ) {}
        }

        destfile = File.join(dest, "file")

        assert(FileTest.exists?(destfile), "Did not create destfile")

        assert_equal(Process.uid, File.stat(destfile).uid)
    end
    end
    
    # Test retrieving all of the facts.
    def test_facts
        facts = nil
        assert_nothing_raised do
            facts = Puppet::Network::Client.master.facts
        end
        Facter.to_hash.each do |fact, value|
            assert_equal(facts[fact.downcase], value, "%s is not equal" % fact.inspect)
        end
        
        # Make sure the puppet version got added
        assert_equal(Puppet::PUPPETVERSION, facts["clientversion"], "client version did not get added")
        
        # And make sure the ruby version is in there
        assert_equal(RUBY_VERSION, facts["rubyversion"], "ruby version did not get added")
    end
    
    # #424
    def test_caching_of_compile_time
        file = tempfile()
        manifest = tempfile()
        File.open(manifest, "w") { |f| f.puts "file { '#{file}': content => yay }" }
        
        driver = mkmaster(manifest)
        driver.local = false
        master = mkclient(driver)
        
        # We have to make everything thinks it's remote, because there's no local caching info
        master.local = false
        
        assert(! master.fresh?(master.class.facts),
            "Considered fresh with no compile at all")
        
        assert_nothing_raised { master.run }
        assert(master.fresh?(master.class.facts),
            "not considered fresh after compile")
        
        # Now make sure the config time is cached
        assert(master.compile_time, "No stored config time")
        assert_equal(master.compile_time, Puppet::Util::Storage.cache(:configuration)[:compile_time], "times did not match")
        time = master.compile_time
        master.clear
        File.unlink(file)
        Puppet::Util::Storage.store
        
        # Now make a new master
        Puppet::Util::Storage.clear
        master = mkclient(driver)
        master.run
        assert_equal(time, master.compile_time, "time was not retrieved from cache")
        assert(FileTest.exists?(file), "file was not created on second run")
    end

    def test_default_objects
        # Make sure they start out missing
        assert_nil(Puppet::Type.type(:filebucket)["puppet"],
            "default filebucket already exists")
        assert_nil(Puppet::Type.type(:schedule)["daily"],
            "default schedules already exists")

        master = mkclient()

        # Now make sure they got created
        assert(Puppet::Type.type(:filebucket)["puppet"],
            "default filebucket not found")
        assert(Puppet::Type.type(:schedule)["daily"],
            "default schedules not found")

        # clear everything, and make sure we can recreate them
        Puppet::Type.allclear
        assert_nil(Puppet::Type.type(:filebucket)["puppet"],
            "default filebucket not removed")
        assert_nil(Puppet::Type.type(:schedule)["daily"],
            "default schedules not removed")
        assert_nothing_raised  { master.mkdefault_objects }
        assert(Puppet::Type.type(:filebucket)["puppet"],
            "default filebucket not found")
        assert(Puppet::Type.type(:schedule)["daily"],
            "default schedules not found")


        # Make sure we've got schedules
        assert(Puppet::Type.type(:schedule)["hourly"], "Could not retrieve hourly schedule")
        assert(Puppet::Type.type(:filebucket)["puppet"], "Could not retrieve default bucket")
    end

    # #540 - make sure downloads aren't affected by noop
    def test_download_in_noop
        source = tempfile
        File.open(source, "w") { |f| f.puts "something" }
        dest = tempfile
        Puppet[:noop] = true
        assert_nothing_raised("Could not download in noop") do
            @master.download(:dest => dest, :source => source, :tag => "yay")
        end

        assert(FileTest.exists?(dest), "did not download in noop mode")

        assert(Puppet[:noop], "noop got disabled in run")
    end

    # #491 - make sure a missing config doesn't kill us
    def test_missing_localconfig
        master = mkclient
        master.local = false
        driver = master.send(:instance_variable_get, "@driver")
        driver.local = false
        # Retrieve the configuration
        master.getconfig

        # Now the config is up to date, so get rid of the @objects var and
        # the cached config
        master.clear
        File.unlink(master.cachefile)

        assert_nothing_raised("Missing cache file threw error") do
            master.getconfig
        end

        assert(! @logs.detect { |l| l.message =~ /Could not load/},
            "Tried to load cache when it is non-existent")
    end

    # #519 - cache the facts so that we notice if they change.
    def test_factchanges_cause_recompile
        $value = "one"
        Facter.add(:testfact) do
            setcode { $value }
        end
        assert_equal("one", Facter.value(:testfact), "fact was not set correctly")
        master = mkclient
        master.local = false
        driver = master.send(:instance_variable_get, "@driver")
        driver.local = false

        assert_nothing_raised("Could not compile config") do
            master.getconfig
        end

        $value = "two"
        Facter.clear
        Facter.loadfacts
        Facter.add(:testfact) do
            setcode { $value }
        end
        facts = master.class.facts
        assert_equal("two", Facter.value(:testfact), "fact did not change")

        assert(master.send(:facts_changed?, facts),
            "master does not think facts changed")
        assert(! master.fresh?(facts),
            "master is considered fresh after facts changed")

        assert_nothing_raised("Could not recompile when facts changed") do
            master.getconfig
        end

    end

    def test_locking
        master = mkclient

        class << master
            def getconfig
                raise ArgumentError, "Just testing"
            end
        end

        assert_raise(ArgumentError, "did not fail") do
            master.run
        end

        assert(! master.send(:lockfile).locked?,
            "Master is still locked after failure")
    end

    # Make sure we get a value for timeout
    def test_config_timeout
        master = Puppet::Network::Client.client(:master)
        time = Integer(Puppet[:configtimeout])
        assert_equal(time, master.timeout, "Did not get default value for timeout")
        assert_equal(time, master.timeout, "Did not get default value for timeout on second run")

        # Reset it
        Puppet[:configtimeout] = "50"
        assert_equal(50, master.timeout, "Did not get changed default value for timeout")
        assert_equal(50, master.timeout, "Did not get changed default value for timeout on second run")

        # Now try an integer
        Puppet[:configtimeout] = 100
        assert_equal(100, master.timeout, "Did not get changed integer default value for timeout")
        assert_equal(100, master.timeout, "Did not get changed integer default value for timeout on second run")
    end

    # #569 -- Make sure we can ignore dynamic facts.
    def test_dynamic_facts
        client = mkclient 

        assert_equal(%w{memorysize memoryfree swapsize swapfree}, client.class.dynamic_facts,
            "Did not get correct defaults for dynamic facts")

        # Cache some values for comparison
        cached = {"one" => "yep", "two" => "nope"}
        Puppet::Util::Storage.cache(:configuration)[:facts] = cached

        assert(! client.send(:facts_changed?, cached), "Facts incorrectly considered to be changed")

        # Now add some values to the passed result and make sure we get a positive
        newfacts = cached.dup
        newfacts["changed"] = "something"

        assert(client.send(:facts_changed?, newfacts), "Did not catch changed fact")

        # Now add a dynamic fact and make sure it's ignored
        newfacts = cached.dup
        newfacts["memorysize"] = "something"

        assert(! client.send(:facts_changed?, newfacts), "Dynamic facts resulted in a false positive")

        # And try it with both
        cached["memorysize"] = "something else"
        assert(! client.send(:facts_changed?, newfacts), "Dynamic facts resulted in a false positive")

        # And finally, with only in the cache
        newfacts.delete("memorysize")
        assert(! client.send(:facts_changed?, newfacts), "Dynamic facts resulted in a false positive")
    end

    def test_splay
        client = mkclient

        # Make sure we default to no splay
        client.expects(:sleep).never

        assert_nothing_raised("Failed to call splay") do
            client.send(:splay)
        end

        # Now set it to true and make sure we get the right value
        client = mkclient
        client.expects(:sleep)

        Puppet[:splay] = true
        assert_nothing_raised("Failed to call sleep when splay is true") do
            client.send(:splay)
        end

        time = Puppet::Util::Storage.cache(:configuration)[:splay_time]
        assert(time, "Splay time was not cached")

        # Now try it again
        client = mkclient
        client.expects(:sleep).with(time)

        assert_nothing_raised("Failed to call sleep when splay is true with a cached value") do
            client.send(:splay)
        end
    end
end

# $Id$
