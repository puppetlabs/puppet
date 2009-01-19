#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/lib/puppettest'

require 'puppettest'
require 'puppet/agent'
require 'mocha'

class TestAgent < Test::Unit::TestCase
    include PuppetTest::ServerTest

    def setup
        super
        @agent_class = Puppet::Agent
    end

    def test_disable
        FileUtils.mkdir_p(Puppet[:statedir])

        client = Puppet::Agent.new

        assert_nothing_raised("Could not disable client") {
            client.disable
        }

        client.expects(:getconfig).never

        client.run

        client = Puppet::Agent.new

        client.expects(:getconfig)

        assert_nothing_raised("Could not enable client") {
            client.enable
        }
        client.run
    end

    # Make sure we're getting the client version in our list of facts
    def test_clientversionfact
        facts = nil
        assert_nothing_raised {
            facts = Puppet::Agent.facts
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

        # so we don't lose our fact setting
        Facter.stubs(:clear)
        Puppet::Agent.stubs(:loadfacts)

        assert_equal("1", Puppet::Agent.facts["nonstring"], "Did not convert all facts to strings")
    end
    
    # This method downloads files, and yields each file object if a block is given.
    def test_download
        source = tempfile()
        dest = tempfile()
        sfile = File.join(source, "file")
        dfile = File.join(dest, "file")
        Dir.mkdir(source)
        File.open(sfile, "w") {|f| f.puts "yay"}
        
        files = []
        assert_nothing_raised do
            files = Puppet::Agent.download(:dest => dest, :source => source, :name => "testing")
        end
        
        assert(FileTest.directory?(dest), "dest dir was not created")
        assert(FileTest.file?(dfile), "dest file was not created")
        assert_equal(File.read(sfile), File.read(dfile), "Dest file had incorrect contents")
        assert_equal([dest, dfile].sort, files.sort, "Changed files were not returned correctly")
    end

    def test_getplugins
        Puppet[:filetimeout] = -1
        Puppet[:pluginsource] = tempfile()
        Dir.mkdir(Puppet[:pluginsource])
        Dir.mkdir(File.join(Puppet[:pluginsource], "testing"))

        $loaded = []
        loader = Puppet::Util::Autoload.new(self, "testing")

        myplugin = File.join(Puppet[:pluginsource], "testing", "myplugin.rb")
        File.open(myplugin, "w") do |f|
            f.puts %{$loaded << :myplugin}
        end

        assert_nothing_raised("Could not get plugins") {
            Puppet::Agent.getplugins
        }

        destfile = File.join(Puppet[:plugindest], "testing", "myplugin.rb")

        assert(File.exists?(destfile), "Did not get plugin")

        assert(loader.load(:myplugin), "Did not load downloaded plugin")

        assert($loaded.include?(:myplugin), "Downloaded code was not evaluated")

        # Now modify the file and make sure the type is replaced
        File.open(myplugin, "w") do |f|
            f.puts %{$loaded << :changed}
        end

        assert_nothing_raised("Could not get plugin changes") {
            Puppet::Agent.getplugins
        }

        assert($loaded.include?(:changed), "Changed code was not evaluated")

        # Now try it again, to make sure we don't have any objects lying around
        assert_nothing_raised {
            Puppet::Agent.getplugins
        }
    end

    def test_getfacts
        Puppet[:filetimeout] = -1
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
            Puppet::Agent.getfacts
        }

        destfile = File.join(Puppet[:factdest], "myfact.rb")

        assert(File.exists?(destfile), "Did not get fact")

        facts = Puppet::Agent.facts

        assert_equal(hostname, facts["hostname"],
            "Lost value to hostname")

        assert_equal("yayness", facts["myfact"],
            "Did not get correct fact value")

        # Now modify the file and make sure the type is replaced
        File.open(myfact, "w") do |f|
            f.puts %{Facter.add("myfact") do
            setcode { "funtest" }
end
}
        end

        assert_nothing_raised {
            Puppet::Agent.getfacts
        }
        facts = Puppet::Agent.facts

        assert_equal("funtest", facts["myfact"],
            "Did not reload fact")
        assert_equal(hostname, facts["hostname"],
            "Lost value to hostname")

        # Now run it again and make sure the fact still loads
        assert_nothing_raised {
            Puppet::Agent.getfacts
        }
        facts = Puppet::Agent.facts

        assert_equal("funtest", facts["myfact"],
            "Did not reload fact")
        assert_equal(hostname, facts["hostname"],
            "Lost value to hostname")
    end

    # Make sure that setting environment by fact takes precedence to configuration
    def test_setenvironmentwithfact
        name = "environment"
        value = "test_environment"

        Facter.stubs(:to_hash).returns(name => value)

        assert_equal(value, Puppet::Agent.facts[name])
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
            Puppet::Agent.loadfacts
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
        chowner = Puppet::Type.type(:file).new :path => dir,
            :owner => user.name, :group => group.name, :recurse => true
        assert_apply(chowner)
        chowner.remove

        assert_equal(user.uid, File.stat(file).uid)
        assert_equal(group.gid, File.stat(file).gid)


        assert_nothing_raised {
            Puppet::Agent.download(:dest => dest, :source => dir,
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
            facts = Puppet::Agent.facts
        end
        Facter.to_hash.each do |fact, value|
            assert_equal(facts[fact.downcase], value.to_s, "%s is not equal" % fact.inspect)
        end
        
        # Make sure the puppet version got added
        assert_equal(Puppet::PUPPETVERSION, facts["clientversion"], "client version did not get added")
        
        # And make sure the ruby version is in there
        assert_equal(RUBY_VERSION, facts["rubyversion"], "ruby version did not get added")
    end
    
    # #540 - make sure downloads aren't affected by noop
    def test_download_in_noop
        source = tempfile
        File.open(source, "w") { |f| f.puts "something" }
        dest = tempfile
        Puppet[:noop] = true
        node = stub 'node', :environment => "development"
        Puppet::Node.stubs(:find).returns node
        assert_nothing_raised("Could not download in noop") do
            @agent_class.download(:dest => dest, :source => source, :tag => "yay")
        end

        assert(FileTest.exists?(dest), "did not download in noop mode")

        assert(Puppet[:noop], "noop got disabled in run")
    end

    # #491 - make sure a missing config doesn't kill us
    def test_missing_localconfig
        master = Puppet::Agent.new
        Puppet::Node::Facts.indirection.stubs(:save)
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

    def test_locking
        master = Puppet::Agent.new

        class << master
            def getconfig
                raise ArgumentError, "Just testing"
            end
        end

        master.run

        assert(! master.send(:lockfile).locked?,
            "Master is still locked after failure")
    end

    # Make sure we get a value for timeout
    def test_config_timeout
        master = Puppet::Agent
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

    def test_splay
        client = Puppet::Agent.new

        # Make sure we default to no splay
        client.expects(:sleep).never

        assert_nothing_raised("Failed to call splay") do
            client.send(:splay)
        end

        # Now set it to true and make sure we get the right value
        client = Puppet::Agent.new
        client.expects(:sleep)

        Puppet[:splay] = true
        assert_nothing_raised("Failed to call sleep when splay is true") do
            client.send(:splay)
        end

        # Now try it again
        client = Puppet::Agent.new
        client.expects(:sleep)

        assert_nothing_raised("Failed to call sleep when splay is true with a cached value") do
            client.send(:splay)
        end
    end

    def test_environment_is_added_to_facts
        facts = Puppet::Agent.facts
        assert_equal(facts["environment"], Puppet[:environment], "Did not add environment to client facts")

        # Now set it to a real value
        Puppet[:environment] = "something"
        facts = Puppet::Agent.facts
        assert_equal(facts["environment"], Puppet[:environment], "Did not add environment to client facts")
    end

    # #685
    def test_http_failures_do_not_kill_puppetd
        client = Puppet::Agent.new

        client.meta_def(:getconfig) { raise "A failure" }

        assert_nothing_raised("Failure in getconfig threw an error") do
            client.run
        end
    end

    def test_classfile
        Puppet[:code] = "class yaytest {}\n class bootest {}\n include yaytest, bootest"

        Puppet::Node::Facts.indirection.stubs(:save)

        client = Puppet::Agent.new

        # We can't guarantee class ordering
        client.expects(:setclasses).with do |array|
            array.length == 2 and array.include?("yaytest") and array.include?("bootest")
        end

        assert_nothing_raised {
            client.getconfig
        }
    end
end
