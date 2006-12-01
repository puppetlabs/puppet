#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppettest'
require 'puppettest/support/resources'

# $Id$

class TestTransactions < Test::Unit::TestCase
    include PuppetTest::FileTesting
    include PuppetTest::Support::Resources

    def test_reports
        path1 = tempfile()
        path2 = tempfile()
        objects = []
        objects << Puppet::Type.newfile(
            :path => path1,
            :content => "yayness"
        )
        objects << Puppet::Type.newfile(
            :path => path2,
            :content => "booness"
        )

        trans = assert_events([:file_created, :file_created], *objects)

        report = nil

        assert_nothing_raised {
            report = trans.report
        }

        # First test the report logs
        assert(report.logs.length > 0, "Did not get any report logs")

        report.logs.each do |obj|
            assert_instance_of(Puppet::Log, obj)
        end

        # Then test the metrics
        metrics = report.metrics

        assert(metrics, "Did not get any metrics")
        assert(metrics.length > 0, "Did not get any metrics")

        assert(metrics.has_key?("resources"), "Did not get object metrics")
        assert(metrics.has_key?("changes"), "Did not get change metrics")

        metrics.each do |name, metric|
            assert_instance_of(Puppet::Metric, metric)
        end
    end

    def test_prefetch
        # Create a type just for testing prefetch
        name = :prefetchtesting
        $prefetched = false
        type = Puppet::Type.newtype(name) do
            newparam(:name) {}
        end
        
        cleanup do
            Puppet::Type.rmtype(name)
        end

        # Now create a provider
        type.provide(:prefetch) do
            def self.prefetch
                $prefetched = true
            end
        end

        # Now create an instance
        inst = type.create :name => "yay"
        
        # Create a transaction
        trans = Puppet::Transaction.new(newcomp(inst))

        # Make sure prefetch works
        assert_nothing_raised do
            trans.prefetch
        end

        assert_equal(true, $prefetched, "type prefetch was not called")

        # Now make sure it gets called from within evaluate()
        $prefetched = false
        assert_nothing_raised do
            trans.evaluate
        end

        assert_equal(true, $prefetched, "evaluate did not call prefetch")
    end

    def test_refreshes_generate_events
        path = tempfile()
        firstpath = tempfile()
        secondpath = tempfile()
        file = Puppet::Type.newfile(:title => "file", :path => path, :content => "yayness")
        first = Puppet::Type.newexec(:title => "first",
                                     :command => "/bin/echo first > #{firstpath}",
                                     :subscribe => [:file, path],
                                     :refreshonly => true
        )
        second = Puppet::Type.newexec(:title => "second",
                                     :command => "/bin/echo second > #{secondpath}",
                                     :subscribe => [:exec, "first"],
                                     :refreshonly => true
        )

        assert_apply(file, first, second)

        assert(FileTest.exists?(secondpath), "Refresh did not generate an event")
    end

    unless %x{groups}.chomp.split(/ /).length > 1
        $stderr.puts "You must be a member of more than one group to test transactions"
    else
    def ingroup(gid)
        require 'etc'
        begin
            group = Etc.getgrgid(gid)
        rescue => detail
            puts "Could not retrieve info for group %s: %s" % [gid, detail]
            return nil
        end

        return @groups.include?(group.name)
    end

    def setup
        super
        @groups = %x{groups}.chomp.split(/ /)
        unless @groups.length > 1
            p @groups
            raise "You must be a member of more than one group to test this"
        end
    end

    def newfile(hash = {})
        tmpfile = tempfile()
        File.open(tmpfile, "w") { |f| f.puts rand(100) }

        # XXX now, because os x apparently somehow allows me to make a file
        # owned by a group i'm not a member of, i have to verify that
        # the file i just created is owned by one of my groups
        # grrr
        unless ingroup(File.stat(tmpfile).gid)
            Puppet.info "Somehow created file in non-member group %s; fixing" %
                File.stat(tmpfile).gid

            require 'etc'
            firstgr = @groups[0]
            unless firstgr.is_a?(Integer)
                str = Etc.getgrnam(firstgr)
                firstgr = str.gid
            end
            File.chown(nil, firstgr, tmpfile)
        end

        hash[:name] = tmpfile
        assert_nothing_raised() {
            return Puppet.type(:file).create(hash)
        }
    end

    def newservice
        assert_nothing_raised() {
            return Puppet.type(:service).create(
                :name => "sleeper",
                :type => "init",
                :path => exampledir("root/etc/init.d"),
                :hasstatus => true,
                :check => [:ensure]
            )
        }
    end

    def newexec(file)
        assert_nothing_raised() {
            return Puppet.type(:exec).create(
                :name => "touch %s" % file,
                :path => "/bin:/usr/bin:/sbin:/usr/sbin",
                :returns => 0
            )
        }
    end

    # modify a file and then roll the modifications back
    def test_filerollback
        transaction = nil
        file = newfile()

        states = {}
        check = [:group,:mode]
        file[:check] = check

        assert_nothing_raised() {
            file.retrieve
        }

        assert_nothing_raised() {
            check.each { |state|
                assert(file[state])
                states[state] = file[state]
            }
        }


        component = newcomp("file",file)
        require 'etc'
        groupname = Etc.getgrgid(File.stat(file.name).gid).name
        assert_nothing_raised() {
            # Find a group that it's not set to
            group = @groups.find { |group| group != groupname }
            unless group
                raise "Could not find suitable group"
            end
            file[:group] = group

            file[:mode] = "755"
        }
        trans = assert_events([:file_changed, :file_changed], component)
        file.retrieve

        assert_rollback_events(trans, [:file_changed, :file_changed], "file")

        assert_nothing_raised() {
            file.retrieve
        }
        states.each { |state,value|
            assert_equal(
                value,file.is(state), "File %s remained %s" % [state, file.is(state)]
            )
        }
    end

    # start a service, and then roll the modification back
    # Disabled, because it wasn't really worth the effort.
    def disabled_test_servicetrans
        transaction = nil
        service = newservice()

        component = newcomp("service",service)

        assert_nothing_raised() {
            service[:ensure] = 1
        }
        service.retrieve
        assert(service.insync?, "Service did not start")
        system("ps -ef | grep ruby")
        trans = assert_events([:service_started], component)
        service.retrieve

        assert_rollback_events(trans, [:service_stopped], "service")
    end

    # test that services are correctly restarted and that work is done
    # in the right order
    def test_refreshing
        transaction = nil
        file = newfile()
        execfile = File.join(tmpdir(), "exectestingness")
        exec = newexec(execfile)
        states = {}
        check = [:group,:mode]
        file[:check] = check
        file[:group] = @groups[0]

        assert_apply(file)

        @@tmpfiles << execfile

        component = newcomp("both",file,exec)

        # 'subscribe' expects an array of arrays
        exec[:subscribe] = [[file.class.name,file.name]]
        exec[:refreshonly] = true

        assert_nothing_raised() {
            file.retrieve
            exec.retrieve
        }

        check.each { |state|
            states[state] = file[state]
        }
        assert_nothing_raised() {
            file[:mode] = "755"
        }

        trans = assert_events([:file_changed, :triggered], component)

        assert(FileTest.exists?(execfile), "Execfile does not exist")
        File.unlink(execfile)
        assert_nothing_raised() {
            file[:group] = @groups[1]
        }

        trans = assert_events([:file_changed, :triggered], component)
        assert(FileTest.exists?(execfile), "Execfile does not exist")
    end

    # Verify that one component requiring another causes the contained
    # resources in the requiring component to get refreshed.
    def test_refresh_across_two_components
        transaction = nil
        file = newfile()
        execfile = File.join(tmpdir(), "exectestingness2")
        @@tmpfiles << execfile
        exec = newexec(execfile)
        states = {}
        check = [:group,:mode]
        file[:check] = check
        file[:group] = @groups[0]
        assert_apply(file)

        fcomp = newcomp("file",file)
        ecomp = newcomp("exec",exec)

        component = newcomp("both",fcomp,ecomp)

        # 'subscribe' expects an array of arrays
        #component[:require] = [[file.class.name,file.name]]
        ecomp[:subscribe] = fcomp
        exec[:refreshonly] = true

        trans = assert_events([], component)

        assert_nothing_raised() {
            file[:group] = @groups[1]
            file[:mode] = "755"
        }

        trans = assert_events([:file_changed, :file_changed, :triggered], component)
    end

    # Make sure that multiple subscriptions get triggered.
    def test_multisubs
        path = tempfile()
        file1 = tempfile()
        file2 = tempfile()
        file = Puppet.type(:file).create(
            :path => path,
            :ensure => "file"
        )
        exec1 = Puppet.type(:exec).create(
            :path => ENV["PATH"],
            :command => "touch %s" % file1,
            :refreshonly => true,
            :subscribe => [:file, path]
        )
        exec2 = Puppet.type(:exec).create(
            :path => ENV["PATH"],
            :command => "touch %s" % file2,
            :refreshonly => true,
            :subscribe => [:file, path]
        )

        assert_apply(file, exec1, exec2)
        assert(FileTest.exists?(file1), "File 1 did not get created")
        assert(FileTest.exists?(file2), "File 2 did not get created")
    end

    # Make sure that a failed trigger doesn't result in other events not
    # getting triggered.
    def test_failedrefreshes
        path = tempfile()
        newfile = tempfile()
        file = Puppet.type(:file).create(
            :path => path,
            :ensure => "file"
        )
        svc = Puppet.type(:service).create(
            :name => "thisservicedoesnotexist",
            :subscribe => [:file, path]
        )
        exec = Puppet.type(:exec).create(
            :path => ENV["PATH"],
            :command => "touch %s" % newfile,
            :logoutput => true,
            :refreshonly => true,
            :subscribe => [:file, path]
        )

        assert_apply(file, svc, exec)
        assert(FileTest.exists?(path), "File did not get created")
        assert(FileTest.exists?(newfile), "Refresh file did not get created")
    end

    # Make sure that unscheduled and untagged objects still respond to events
    def test_unscheduled_and_untagged_response
        Puppet::Type.type(:schedule).mkdefaultschedules
        Puppet[:ignoreschedules] = false
        file = Puppet.type(:file).create(
            :name => tempfile(),
            :ensure => "file"
        )

        fname = tempfile()
        exec = Puppet.type(:exec).create(
            :name => "touch %s" % fname,
            :path => "/usr/bin:/bin",
            :schedule => "monthly",
            :subscribe => ["file", file.name]
        )

        comp = newcomp(file,exec)
        comp.finalize

        # Run it once
        assert_apply(comp)
        assert(FileTest.exists?(fname), "File did not get created")

        assert(!exec.scheduled?, "Exec is somehow scheduled")

        # Now remove it, so it can get created again
        File.unlink(fname)

        file[:content] = "some content"

        assert_events([:file_changed, :triggered], comp)
        assert(FileTest.exists?(fname), "File did not get recreated")

        # Now remove it, so it can get created again
        File.unlink(fname)

        # And tag our exec
        exec.tag("testrun")

        # And our file, so it runs
        file.tag("norun")

        Puppet[:tags] = "norun"

        file[:content] = "totally different content"

        assert(! file.insync?, "Uh, file is in sync?")

        assert_events([:file_changed, :triggered], comp)
        assert(FileTest.exists?(fname), "File did not get recreated")
    end

    def test_failed_reqs_mean_no_run
        exec = Puppet::Type.type(:exec).create(
            :command => "/bin/mkdir /this/path/cannot/possibly/exit",
            :title => "mkdir"
        )

        file1 = Puppet::Type.type(:file).create(
            :title => "file1",
            :path => tempfile(),
            :require => exec,
            :ensure => :file
        )

        file2 = Puppet::Type.type(:file).create(
            :title => "file2",
            :path => tempfile(),
            :require => file1,
            :ensure => :file
        )

        comp = newcomp(exec, file1, file2)

        comp.finalize

        assert_apply(comp)

        assert(! FileTest.exists?(file1[:path]),
            "File got created even tho its dependency failed")
        assert(! FileTest.exists?(file2[:path]),
            "File got created even tho its deep dependency failed")
    end
    end
    
    def f(n)
        Puppet::Type.type(:file)["/tmp/#{n.to_s}"]
    end
    
    def test_relationship_graph
        one, two, middle, top = mktree
        
        {one => two, "f" => "c", "h" => middle}.each do |source, target|
            if source.is_a?(String)
                source = f(source)
            end
            if target.is_a?(String)
                target = f(target)
            end
            target[:require] = source
        end
        
        trans = Puppet::Transaction.new(top)
        
        graph = nil
        assert_nothing_raised do
            graph = trans.relationship_graph
        end
        
        assert_instance_of(Puppet::PGraph, graph,
            "Did not get relationship graph")
        
        # Make sure all of the components are gone
        comps = graph.vertices.find_all { |v| v.is_a?(Puppet::Type::Component)}
        assert(comps.empty?, "Deps graph still contains components")
        
        # It must be reversed because of how topsort works
        sorted = graph.topsort.reverse
        
        # Now make sure the appropriate edges are there and are in the right order
        assert(graph.dependencies(f(:f)).include?(f(:c)),
            "c not marked a dep of f")
        assert(sorted.index(f(:c)) < sorted.index(f(:f)),
            "c is not before f")
            
        one.each do |o|
            two.each do |t|
                assert(graph.dependencies(o).include?(t),
                    "%s not marked a dep of %s" % [t.ref, o.ref])
                assert(sorted.index(t) < sorted.index(o),
                    "%s is not before %s" % [t.ref, o.ref])
            end
        end
        
        trans.resources.leaves(middle).each do |child|
            assert(graph.dependencies(f(:h)).include?(child),
                "%s not marked a dep of h" % [child.ref])
            assert(sorted.index(child) < sorted.index(f(:h)),
                "%s is not before h" % child.ref)
        end
        
        # Lastly, make sure our 'g' vertex made it into the relationship
        # graph, since it's not involved in any relationships.
        assert(graph.vertex?(f(:g)),
            "Lost vertexes with no relations")

        graph.to_jpg("normal_relations")
    end
    
    def test_generate
        # Create a bogus type that generates new instances with shorter
        Puppet::Type.newtype(:generator) do
            newparam(:name, :namevar => true)
            
            def generate
                ret = []
                if title.length > 1
                    ret << self.class.create(:title => title[0..-2])
                end
                ret
            end
        end
        cleanup do
            Puppet::Type.rmtype(:generator)
        end
        
        yay = Puppet::Type.newgenerator :title => "yay"
        rah = Puppet::Type.newgenerator :title => "rah"
        comp = newcomp(yay, rah)
        trans = comp.evaluate
        
        assert_nothing_raised do
            trans.generate
        end
        
        %w{ya ra y r}.each do |name|
            assert(trans.resources.vertex?(Puppet::Type.type(:generator)[name]),
                "Generated %s was not a vertex" % name)
        end
    end
end

# $Id$