#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppettest'

class TestRelationships < Test::Unit::TestCase
  include PuppetTest
  def setup
    super
    Puppet::Type.type(:exec)
  end

  def newfile
    assert_nothing_raised {
      return Puppet::Type.type(:file).new(
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
        assert(edge, "Could not find edge for #{source.ref} => #{target.ref}")

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

  def test_autorequire
    # We know that execs autorequire their cwd, so we'll use that
    path = tempfile
    file = Puppet::Type.type(:file).new(
      :title => "myfile", :path => path,
      :ensure => :directory
    )
    exec = Puppet::Type.newexec(
      :title => "myexec", :cwd => path,
      :command => "/bin/echo"
    )
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
      assert(catalog.relationship_graph.path_between(file, exec), "autorequire edge was not created")
    end
  end

  # Testing #411.  It was a problem with builddepends.
  def test_missing_deps
    file = Puppet::Type.type(:file).new :path => tempfile, :require => Puppet::Resource.new("file", "/no/such/file")

    assert_raise(Puppet::Error) do
      file.builddepends
    end
  end
end

