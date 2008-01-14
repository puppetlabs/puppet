#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppet'
require 'puppettest'

class TestRelationships < Test::Unit::TestCase
	include PuppetTest
	def setup
	    super
	    Puppet::Type.type(:exec)
    end
    
    def newfile
        assert_nothing_raised() {
            return Puppet.type(:file).create(
                :path => tempfile,
                :check => [:mode, :owner, :group]
            )
        }
    end
    
    def check_relationship(sources, targets, out, refresher)
        if out
            deps = sources.builddepends
            sources = [sources]
        else
            deps = targets.builddepends
            targets = [targets]
        end
        assert_instance_of(Array, deps)
        assert(! deps.empty?, "Did not receive any relationships")
        
        deps.each do |edge|
            assert_instance_of(Puppet::Relationship, edge)
        end
        
        sources.each do |source|
            targets.each do |target|
                edge = deps.find { |e| e.source == source and e.target == target }
                assert(edge, "Could not find edge for %s => %s" %
                    [source.ref, target.ref])
        
                if refresher
                    assert_equal(:ALL_EVENTS, edge.event)
                    assert_equal(:refresh, edge.callback)
                else
                    assert_nil(edge.event)
                    assert_nil(edge.callback, "Got a callback with no events")
                end
            end
        end
    end

    # Make sure our various metaparams work correctly.  We're just checking
    # here whether they correctly set up the callbacks and the direction of
    # the relationship.
    def test_relationship_metaparams
        out = {:require => false, :subscribe => false,
            :notify => true, :before => true}
        refreshers = [:subscribe, :notify]
        [:require, :subscribe, :notify, :before].each do |param|
            # Create three files to generate our events and three
            # execs to receive them
            files = []
            execs = []
            3.times do |i|
                files << Puppet::Type.newfile(
                    :title => "file#{i}",
                    :path => tempfile(),
                    :ensure => :file
                )

                path = tempfile()
                execs << Puppet::Type.newexec(
                    :title => "notifytest#{i}",
                    :path => "/usr/bin:/bin",
                    :command => "touch #{path}",
                    :refreshonly => true
                )
            end

            catalog = mk_catalog(*files)
            catalog.add_resource(*execs)

            # Add our first relationship
            if out[param]
                files[0][param] = execs[0]
                sources = files[0]
                targets = [execs[0]]
            else
                execs[0][param] = files[0]
                sources = [files[0]]
                targets = execs[0]
            end
            check_relationship(sources, targets, out[param], refreshers.include?(param))

            # Now add another relationship
            if out[param]
                files[0][param] = execs[1]
                targets << execs[1]
                assert_equal(targets.collect { |t| [t.class.name, t.title]},
                    files[0][param], "Incorrect target list")
            else
                execs[0][param] = files[1]
                sources << files[1]
                assert_equal(sources.collect { |t| [t.class.name, t.title]},
                    execs[0][param], "Incorrect source list")
            end
            check_relationship(sources, targets, out[param], refreshers.include?(param))
        end
    end
    
    def test_munge_relationship
        file = Puppet::Type.newfile :path => tempfile(), :mode => 0755
        execs = []
        3.times do |i|
            execs << Puppet::Type.newexec(:title => "yay#{i}", :command => "/bin/echo yay")
        end
        
        # First try it with one object, specified as a reference and an array
        result = nil
        [execs[0], [:exec, "yay0"], ["exec", "yay0"]].each do |target|
            assert_nothing_raised do
                result = file.send(:munge_relationship, :require, target)
            end
        
            assert_equal([[:exec, "yay0"]], result)
        end
        
        # Now try it with multiple objects
        symbols = execs.collect { |e| [e.class.name, e.title] }
        strings = execs.collect { |e| [e.class.name.to_s, e.title] }
        [execs, symbols, strings].each do |target|
            assert_nothing_raised do
                result = file.send(:munge_relationship, :require, target)
            end
        
            assert_equal(symbols, result)
        end
        
        # Make sure we can mix it up, even though this shouldn't happen
        assert_nothing_raised do
            result = file.send(:munge_relationship, :require, [execs[0], [execs[1].class.name, execs[1].title]])
        end
        
        assert_equal([[:exec, "yay0"], [:exec, "yay1"]], result)
        
        # Finally, make sure that new results get added to old.  The only way
        # to get rid of relationships is to delete the parameter.
        file[:require] = execs[0]
        
        assert_nothing_raised do
            result = file.send(:munge_relationship, :require, [execs[1], execs[2]])
        end
        
        assert_equal(symbols, result)
    end
    
    def test_autorequire
        # We know that execs autorequire their cwd, so we'll use that
        path = tempfile()
        
        file = Puppet::Type.newfile(:title => "myfile", :path => path,
            :ensure => :directory)
        exec = Puppet::Type.newexec(:title => "myexec", :cwd => path,
            :command => "/bin/echo")
        
        catalog = mk_catalog(file, exec)
        reqs = nil
        assert_nothing_raised do
            reqs = exec.autorequire
        end
        assert_instance_of(Puppet::Relationship, reqs[0], "Did not return a relationship edge")
        assert_equal(file, reqs[0].source, "Did not set the autorequire source correctly")
        assert_equal(exec, reqs[0].target, "Did not set the autorequire target correctly")
        
        # Now make sure that these relationships are added to the 
        # relationship graph
        catalog.apply do |trans|
            assert(catalog.relationship_graph.edge?(file, exec), "autorequire edge was not created")
        end
    end
    
    def test_requires?
        # Test the first direction
        file1 = Puppet::Type.newfile(:title => "one", :path => tempfile,
            :ensure => :directory)
        file2 = Puppet::Type.newfile(:title => "two", :path => tempfile,
            :ensure => :directory)
        
        file1[:require] = file2
        assert(file1.requires?(file2), "requires? failed to catch :require relationship")
        file1.delete(:require)
        assert(! file1.requires?(file2), "did not delete relationship")
        file1[:subscribe] = file2
        assert(file1.requires?(file2), "requires? failed to catch :subscribe relationship")
        file1.delete(:subscribe)
        assert(! file1.requires?(file2), "did not delete relationship")
        file2[:before] = file1
        assert(file1.requires?(file2), "requires? failed to catch :before relationship")
        file2.delete(:before)
        assert(! file1.requires?(file2), "did not delete relationship")
        file2[:notify] = file1
        assert(file1.requires?(file2), "requires? failed to catch :notify relationship")
    end
    
    # Testing #411.  It was a problem with builddepends.
    def test_missing_deps
        file = Puppet::Type.newfile :path => tempfile, :require => ["file", "/no/such/file"]
        
        assert_raise(Puppet::Error) do
            file.builddepends
        end
    end
end

