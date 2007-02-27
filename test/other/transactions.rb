#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppettest'
require 'puppettest/support/resources'

# $Id$

class TestTransactions < Test::Unit::TestCase
    include PuppetTest::FileTesting
    include PuppetTest::Support::Resources
    class Fakeprop <Puppet::Type::Property
        attr_accessor :path, :is, :should, :name
        def insync?
            true
        end
        def info(*args)
            false
        end
    end
    
    
    def mkgenerator(&block)
        $finished = []
        cleanup { $finished = nil }
        
        # Create a bogus type that generates new instances with shorter
        type = Puppet::Type.newtype(:generator) do
            newparam(:name, :namevar => true)
            def finish
                $finished << self.name
            end
        end
        if block
            type.class_eval(&block)
        end
        cleanup do
            Puppet::Type.rmtype(:generator)
        end
        
        return type
    end
    
    # Create a new type that generates instances with shorter names.
    def mkreducer(&block)
        type = mkgenerator() do
            def eval_generate
                ret = []
                if title.length > 1
                    ret << self.class.create(:title => title[0..-2])
                else
                    return nil
                end
                ret
            end
        end
        
        if block
            type.class_eval(&block)
        end
        
        return type
    end

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
            assert_instance_of(Puppet::Util::Log, obj)
        end

        # Then test the metrics
        metrics = report.metrics

        assert(metrics, "Did not get any metrics")
        assert(metrics.length > 0, "Did not get any metrics")

        assert(metrics.has_key?("resources"), "Did not get object metrics")
        assert(metrics.has_key?("changes"), "Did not get change metrics")

        metrics.each do |name, metric|
            assert_instance_of(Puppet::Util::Metric, metric)
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

        properties = {}
        check = [:group,:mode]
        file[:check] = check

        assert_nothing_raised() {
            file.retrieve
        }

        assert_nothing_raised() {
            check.each { |property|
                assert(file[property])
                properties[property] = file[property]
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
        properties.each { |property,value|
            assert_equal(
                value,file.is(property), "File %s remained %s" % [property, file.is(property)]
            )
        }
    end

    # test that services are correctly restarted and that work is done
    # in the right order
    def test_refreshing
        transaction = nil
        file = newfile()
        execfile = File.join(tmpdir(), "exectestingness")
        exec = newexec(execfile)
        properties = {}
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

        check.each { |property|
            properties[property] = file[property]
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
        properties = {}
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
        exec1 = Puppet.type(:exec).create(
            :path => ENV["PATH"],
            :command => "touch /this/cannot/possibly/exist",
            :logoutput => true,
            :refreshonly => true,
            :subscribe => file,
            :title => "one"
        )
        exec2 = Puppet.type(:exec).create(
            :path => ENV["PATH"],
            :command => "touch %s" % newfile,
            :logoutput => true,
            :refreshonly => true,
            :subscribe => [file, exec1],
            :title => "two"
        )

        assert_apply(file, exec1, exec2)
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
        assert(comps.empty?, "Deps graph still contains components %s" %
            comps.collect { |c| c.ref }.join(","))
        
        assert_equal([], comps, "Deps graph still contains components")
        
        # It must be reversed because of how topsort works
        sorted = graph.topsort.reverse
        
        # Now make sure the appropriate edges are there and are in the right order
        assert(graph.dependents(f(:f)).include?(f(:c)),
            "c not marked a dep of f")
        assert(sorted.index(f(:c)) < sorted.index(f(:f)),
            "c is not before f")
            
        one.each do |o|
            two.each do |t|
                assert(graph.dependents(o).include?(t),
                    "%s not marked a dep of %s" % [t.ref, o.ref])
                assert(sorted.index(t) < sorted.index(o),
                    "%s is not before %s" % [t.ref, o.ref])
            end
        end
        
        trans.resources.leaves(middle).each do |child|
            assert(graph.dependents(f(:h)).include?(child),
                "%s not marked a dep of h" % [child.ref])
            assert(sorted.index(child) < sorted.index(f(:h)),
                "%s is not before h" % child.ref)
        end
        
        # Lastly, make sure our 'g' vertex made it into the relationship
        # graph, since it's not involved in any relationships.
        assert(graph.vertex?(f(:g)),
            "Lost vertexes with no relations")

        # Now make the reversal graph and make sure all of the vertices made it into that
        reverse = graph.reversal
        %w{a b c d e f g h}.each do |letter|
            file = f(letter)
            assert(reverse.vertex?(file), "%s did not make it into reversal" % letter)
        end
    end
    
    # Test pre-evaluation generation
    def test_generate
        mkgenerator() do
            def generate
                ret = []
                if title.length > 1
                    ret << self.class.create(:title => title[0..-2])
                else
                    return nil
                end
                ret
            end
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
            assert($finished.include?(name), "%s was not finished" % name)
        end
        
        # Now make sure that cleanup gets rid of those generated types.
        assert_nothing_raised do
            trans.cleanup
        end
        
        %w{ya ra y r}.each do |name|
            assert(!trans.resources.vertex?(Puppet::Type.type(:generator)[name]),
                "Generated vertex %s was not removed from graph" % name)
            assert_nil(Puppet::Type.type(:generator)[name],
                "Generated vertex %s was not removed from class" % name)
        end
    end
    
    # Test mid-evaluation generation.
    def test_eval_generate
        $evaluated = []
        cleanup { $evaluated = nil }
        type = mkreducer() do
            def evaluate
                $evaluated << self.title
                return []
            end
        end

        yay = Puppet::Type.newgenerator :title => "yay"
        rah = Puppet::Type.newgenerator :title => "rah", :subscribe => yay
        comp = newcomp(yay, rah)
        trans = comp.evaluate
        
        trans.prepare
        
        # Now apply the resources, and make sure they appropriately generate
        # things.
        assert_nothing_raised("failed to apply yay") do
            trans.eval_resource(yay)
        end
        ya = type["ya"]
        assert(ya, "Did not generate ya")
        assert(trans.relgraph.vertex?(ya),
            "Did not add ya to rel_graph")
        
        # Now make sure the appropriate relationships were added
        assert(trans.relgraph.edge?(yay, ya),
            "parent was not required by child")
        assert(! trans.relgraph.edge?(ya, rah),
            "generated child ya inherited depencency on rah")
        
        # Now make sure it in turn eval_generates appropriately
        assert_nothing_raised("failed to apply yay") do
            trans.eval_resource(type["ya"])
        end

        %w{y}.each do |name|
            res = type[name]
            assert(res, "Did not generate %s" % name)
            assert(trans.relgraph.vertex?(res),
                "Did not add %s to rel_graph" % name)
            assert($finished.include?("y"), "y was not finished")
        end
        
        assert_nothing_raised("failed to eval_generate with nil response") do
            trans.eval_resource(type["y"])
        end
        assert(trans.relgraph.edge?(yay, ya), "no edge was created for ya => yay")
        
        assert_nothing_raised("failed to apply rah") do
            trans.eval_resource(rah)
        end

        ra = type["ra"]
        assert(ra, "Did not generate ra")
        assert(trans.relgraph.vertex?(ra),
            "Did not add ra to rel_graph" % name)
        assert($finished.include?("ra"), "y was not finished")
        
        # Now make sure this generated resource has the same relationships as
        # the generating resource
        assert(! trans.relgraph.edge?(yay, ra),
           "rah passed its dependencies on to its children")
        assert(! trans.relgraph.edge?(ya, ra),
            "children have a direct relationship")
        
        # Now make sure that cleanup gets rid of those generated types.
        assert_nothing_raised do
            trans.cleanup
        end
        
        %w{ya ra y r}.each do |name|
            assert(!trans.relgraph.vertex?(type[name]),
                "Generated vertex %s was not removed from graph" % name)
            assert_nil(type[name],
                "Generated vertex %s was not removed from class" % name)
        end
        
        # Now, start over and make sure that everything gets evaluated.
        trans = comp.evaluate
        $evaluated.clear
        assert_nothing_raised do
            trans.evaluate
        end
        
        assert_equal(%w{yay ya y rah ra r}, $evaluated,
            "Not all resources were evaluated or not in the right order")
    end
    
    def test_tags
        res = Puppet::Type.newfile :path => tempfile()
        comp = newcomp(res)
        
        # Make sure they default to none
        assert_equal([], comp.evaluate.tags)
        
        # Make sure we get the main tags
        Puppet[:tags] = %w{this is some tags}
        assert_equal(%w{this is some tags}, comp.evaluate.tags)
        
        # And make sure they get processed correctly
        Puppet[:tags] = ["one", "two,three", "four"]
        assert_equal(%w{one two three four}, comp.evaluate.tags)
        
        # lastly, make sure we can override them
        trans = comp.evaluate
        trans.tags = ["one", "two,three", "four"]
        assert_equal(%w{one two three four}, comp.evaluate.tags)
    end
    
    def test_tagged?
        res = Puppet::Type.newfile :path => tempfile()
        comp = newcomp(res)
        trans = comp.evaluate
        
        assert(trans.tagged?(res), "tagged? defaulted to false")
        
        # Now set some tags
        trans.tags = %w{some tags}
        
        # And make sure it's false
        assert(! trans.tagged?(res), "matched invalid tags")
        
        # Set ignoretags and make sure it sticks
        trans.ignoretags = true
        assert(trans.tagged?(res), "tags were not ignored")
        
        # Now make sure we actually correctly match tags
        res[:tag] = "mytag"
        trans.ignoretags = false
        trans.tags = %w{notag}
        
        assert(! trans.tagged?(res), "tags incorrectly matched")
        
        trans.tags = %w{mytag yaytag}
        assert(trans.tagged?(res), "tags should have matched")
    end
    
    # We don't want to purge resources that have relationships with other
    # resources, so we want our transactions to check for that.
    def test_required_resources_not_deleted
        @file = Puppet::Type.type(:file)
        path1 = tempfile()
        path2 = tempfile()
        
        # Create our first file
        File.open(path1, "w") { |f| f.puts "yay" }
        
        # Create a couple of related resources
        file1 = @file.create :title => "dependee", :path => path1, :ensure => :absent
        file2 = @file.create :title => "depender", :path => path2, :content => "some stuff", :require => file1
                
        # Now make sure we don't actually delete the first file
        assert_apply(file1, file2)
        
        assert(FileTest.exists?(path1), "required file was deleted")

        # However, we *do* want to allow deletion of resources of their dependency
        # is also being deleted
        file2[:ensure] = :absent

        assert_apply(file1, file2)
        
        assert(! FileTest.exists?(path1), "dependency blocked deletion even when it was itself being deleted")
    end
    
    # Make sure changes generated by eval_generated resources have proxies
    # set to the top-level resource.
    def test_proxy_resources
        type = mkreducer do
            def evaluate
                return Puppet::PropertyChange.new(Fakeprop.new(
                    :path => :path, :is => :is, :should => :should, :name => self.name, :parent => "a parent"))
            end
        end
        
        resource = type.create :name => "test"
        comp = newcomp(resource)
        trans = comp.evaluate
        trans.prepare

        assert_nothing_raised do
            trans.eval_resource(resource)
        end
        
        changes = trans.instance_variable_get("@changes")
        
        assert(changes.length > 0, "did not get any changes")
        
        changes.each do |change|
            assert_equal(resource, change.source, "change did not get proxy set correctly")
        end
    end
    
    # Make sure changes in contained files still generate callback events.
    def test_generated_callbacks
        dir = tempfile()
        maker = tempfile()
        Dir.mkdir(dir)
        file = File.join(dir, "file")
        File.open(file, "w") { |f| f.puts "" }
        File.chmod(0644, file)
        File.chmod(0755, dir) # So only the child file causes a change
        
        dirobj = Puppet::Type.type(:file).create :mode => "755", :recurse => true, :path => dir
        exec = Puppet::Type.type(:exec).create :title => "make",
            :command => "touch #{maker}", :path => ENV['PATH'], :refreshonly => true,
            :subscribe => dirobj
        
        assert_apply(dirobj, exec)
        assert(FileTest.exists?(maker), "Did not make callback file")
    end

    # Yay, this out to be fun.
    def test_trigger
        $triggered = []
        cleanup { $triggered = nil }
        trigger = Class.new do
            attr_accessor :name
            include Puppet::Util::Logging
            def initialize(name)
                @name = name
            end
            def ref
                self.name
            end
            def refresh
                $triggered << self.name
            end

            def to_s
                self.name
            end
        end

        # Make a graph with some stuff in it.
        graph = Puppet::PGraph.new

        # Add a non-triggering edge.
        a = trigger.new(:a)
        b = trigger.new(:b)
        c = trigger.new(:c)
        nope = Puppet::Relationship.new(a, b)
        yep = Puppet::Relationship.new(a, c, {:callback => :refresh})
        graph.add_edge!(nope)

        # And a triggering one.
        graph.add_edge!(yep)

        # Create our transaction
        trans = Puppet::Transaction.new(graph)

        # Set the non-triggering on
        assert_nothing_raised do
            trans.set_trigger(nope)
        end

        assert(! trans.targeted?(b), "b is incorrectly targeted")

        # Now set the other
        assert_nothing_raised do
            trans.set_trigger(yep)
        end
        assert(trans.targeted?(c), "c is not targeted")

        # Now trigger our three resources
        assert_nothing_raised do
            assert_nil(trans.trigger(a), "a somehow triggered something")
        end
        assert_nothing_raised do
            assert_nil(trans.trigger(b), "b somehow triggered something")
        end
        assert_equal([], $triggered,"got something in triggered")
        result = nil
        assert_nothing_raised do
            result = trans.trigger(c)
        end
        assert(result, "c did not trigger anything")
        assert_instance_of(Array, result)
        event = result.shift
        assert_instance_of(Puppet::Event, event)
        assert_equal(:triggered, event.event, "event was not set correctly")
        assert_equal(c, event.source, "source was not set correctly")
        assert_equal(trans, event.transaction, "transaction was not set correctly")

        assert(trans.triggered?(c, :refresh),
            "Transaction did not store the trigger")
    end

    def test_graph
        Puppet.config.use(:puppet)
        # Make a graph
        graph = Puppet::PGraph.new
        graph.add_edge!("a", "b")

        # Create our transaction
        trans = Puppet::Transaction.new(graph)

        assert_nothing_raised do
            trans.graph(graph, :testing)
        end

        dotfile = File.join(Puppet[:graphdir], "testing.dot")
        assert(! FileTest.exists?(dotfile), "Enabled graphing even tho disabled")

        # Now enable graphing
        Puppet[:graph] = true

        assert_nothing_raised do
            trans.graph(graph, :testing)
        end
        assert(FileTest.exists?(dotfile), "Did not create graph.")
    end

    def test_created_graphs
        FileUtils.mkdir_p(Puppet[:graphdir])
        file = Puppet::Type.newfile(:path => tempfile, :content => "yay")
        exec = Puppet::Type.type(:exec).create(:command => "echo yay", :path => ENV['PATH'],
            :require => file)

        Puppet[:graph] = true
        assert_apply(file, exec)

        %w{resources relationships expanded_relationships}.each do |name|
            file = File.join(Puppet[:graphdir], "%s.dot" % name)
            assert(FileTest.exists?(file), "graph for %s was not created" % name)
        end
    end
    
    def test_set_target
        file = Puppet::Type.newfile(:path => tempfile(), :content => "yay")
        exec1 = Puppet::Type.type(:exec).create :command => "/bin/echo exec1"
        exec2 = Puppet::Type.type(:exec).create :command => "/bin/echo exec2"
        trans = Puppet::Transaction.new(newcomp(file, exec1, exec2))
        
        # First try it with an edge that has no callback
        edge = Puppet::Relationship.new(file, exec1)
        assert_nothing_raised { trans.set_trigger(edge) }
        assert(! trans.targeted?(exec1), "edge with no callback resulted in a target")
        
        # Now with an edge that has an unsupported callback
        edge = Puppet::Relationship.new(file, exec1, :callback => :nosuchmethod, :event => :ALL_EVENTS)
        assert_nothing_raised { trans.set_trigger(edge) }
        assert(! trans.targeted?(exec1), "edge with invalid callback resulted in a target")
        
        # Lastly, with an edge with a supported callback
        edge = Puppet::Relationship.new(file, exec1, :callback => :refresh, :event => :ALL_EVENTS)
        assert_nothing_raised { trans.set_trigger(edge) }
        assert(trans.targeted?(exec1), "edge with valid callback did not result in a target")
    end
    
    # Testing #401 -- transactions are calling refresh() on classes that don't support it.
    def test_callback_availability
        $called = []
        klass = Puppet::Type.newtype(:norefresh) do
            newparam(:name, :namevar => true) {}
            def method_missing(method, *args)
                $called << method
            end
        end
        cleanup do
            $called = nil
            Puppet::Type.rmtype(:norefresh)
        end

        file = Puppet::Type.newfile :path => tempfile(), :content => "yay"
        one = klass.create :name => "one", :subscribe => file
        
        assert_apply(file, one)
        
        assert(! $called.include?(:refresh), "Called refresh when it wasn't set as a method")
    end

    # Testing #437 - cyclic graphs should throw failures.
    def test_fail_on_cycle
        one = Puppet::Type.type(:exec).create(:name => "/bin/echo one")
        two = Puppet::Type.type(:exec).create(:name => "/bin/echo two")
        one[:require] = two
        two[:require] = one

        trans = newcomp(one, two).evaluate
        assert_raise(Puppet::Error) do
            trans.prepare
        end
    end

    def test_errors_during_generation
        type = Puppet::Type.newtype(:failer) do
            newparam(:name) {}
            def eval_generate
                raise ArgumentError, "Invalid value"
            end
            def generate
                raise ArgumentError, "Invalid value"
            end
        end
        cleanup { Puppet::Type.rmtype(:failer) }

        obj = type.create(:name => "testing")

        assert_apply(obj)
    end
    
    def test_self_refresh_causes_triggering
        type = Puppet::Type.newtype(:refresher, :self_refresh => true) do
            attr_accessor :refreshed, :testing
            newparam(:name) {}
            newproperty(:testing) do
                def sync
                    self.is = self.should
                    :ran_testing
                end
            end
            def refresh
                @refreshed = true
            end
        end
        cleanup { Puppet::Type.rmtype(:refresher)}
        
        obj = type.create(:name => "yay", :testing => "cool")
        
        assert(! obj.insync?, "fake object is already in sync")
        
        # Now make sure it gets refreshed when the change happens
        assert_apply(obj)
        assert(obj.refreshed, "object was not refreshed during transaction")
    end
    
    # Testing #433
    def test_explicit_dependencies_beat_automatic
        # Create a couple of different resource sets that have automatic relationships and make sure the manual relationships win
        rels = {}
        # First users and groups
        group = Puppet::Type.type(:group).create(:name => nonrootgroup.name, :ensure => :present)
        user = Puppet::Type.type(:user).create(:name => nonrootuser.name, :ensure => :present, :gid => group.title)
        
        # Now add the explicit relationship
        group[:require] = user
        rels[group] = user
        # Now files
        d = tempfile()
        f = File.join(d, "file")
        file = Puppet::Type.newfile(:path => f, :content => "yay")
        dir = Puppet::Type.newfile(:path => d, :ensure => :directory, :require => file)
        
        rels[dir] = file
        rels.each do |after, before|
            comp = newcomp(before, after)
            trans = comp.evaluate
            str = "from %s to %s" % [before, after]
        
            assert_nothing_raised("Failed to create graph %s" % str) do
                trans.prepare
            end
        
            graph = trans.relgraph
            assert(graph.edge?(before, after), "did not create manual relationship %s" % str)
            assert(! graph.edge?(after, before), "created automatic relationship %s" % str)
        end
    end
end

# $Id$
