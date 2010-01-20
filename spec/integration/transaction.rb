#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet_spec/files'
require 'puppet/transaction'

describe Puppet::Transaction do
    include PuppetSpec::Files

    it "should not apply generated resources if the parent resource fails" do
        catalog = Puppet::Resource::Catalog.new
        resource = Puppet::Type.type(:file).new :path => "/foo/bar", :backup => false
        catalog.add_resource resource

        child_resource = Puppet::Type.type(:file).new :path => "/foo/bar/baz", :backup => false

        resource.expects(:eval_generate).returns([child_resource])

        transaction = Puppet::Transaction.new(catalog)

        resource.expects(:retrieve).raises "this is a failure"

        child_resource.expects(:retrieve).never

        transaction.evaluate
    end

    it "should not apply virtual resources" do
        catalog = Puppet::Resource::Catalog.new
        resource = Puppet::Type.type(:file).new :path => "/foo/bar", :backup => false
        resource.virtual = true
        catalog.add_resource resource

        transaction = Puppet::Transaction.new(catalog)

        resource.expects(:evaluate).never

        transaction.evaluate
    end

    it "should apply exported resources" do
        catalog = Puppet::Resource::Catalog.new
        resource = Puppet::Type.type(:file).new :path => "/foo/bar", :backup => false
        resource.exported = true
        catalog.add_resource resource

        transaction = Puppet::Transaction.new(catalog)

        resource.expects(:evaluate).never

        transaction.evaluate
    end

    it "should not apply virtual exported resources" do
        catalog = Puppet::Resource::Catalog.new
        resource = Puppet::Type.type(:file).new :path => "/foo/bar", :backup => false
        resource.exported = true
        resource.virtual = true
        catalog.add_resource resource

        transaction = Puppet::Transaction.new(catalog)

        resource.expects(:evaluate).never

        transaction.evaluate
    end

    it "should refresh resources that subscribe to changed resources" do
        name = tmpfile("something")
        file = Puppet::Type.type(:file).new(
            :name => name,
            :ensure => "file"
        )
        exec = Puppet::Type.type(:exec).new(
            :name => "echo true",
            :path => "/usr/bin:/bin",
            :refreshonly => true,
            :subscribe => Puppet::Resource::Reference.new(file.class.name, file.name)
        )

        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource file, exec

        exec.expects(:refresh)

        catalog.apply
    end

    it "should not refresh resources that only require changed resources" do
        name = tmpfile("something")
        file = Puppet::Type.type(:file).new(
            :name => name,
            :ensure => "file"
        )
        exec = Puppet::Type.type(:exec).new(
            :name => "echo true",
            :path => "/usr/bin:/bin",
            :refreshonly => true,
            :require => Puppet::Resource::Reference.new(file.class.name, file.name)
        )


        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource file
        catalog.add_resource exec

        exec.expects(:refresh).never

        trans = catalog.apply

        trans.events.length.should == 1
    end

    it "should cascade events such that multiple refreshes result" do
        files = []

        4.times { |i|
            files << Puppet::Type.type(:file).new(
                :name => tmpfile("something"),
                :ensure => "file"
            )
        }

        fname = tmpfile("something")
        exec = Puppet::Type.type(:exec).new(
            :name => "touch %s" % fname,
            :path => "/usr/bin:/bin",
            :refreshonly => true
        )

        exec[:subscribe] = files.collect { |f|
            Puppet::Resource::Reference.new(:file, f.name)
        }

        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource(exec, *files)

        catalog.apply
        FileTest.should be_exist(fname)
    end

    # Make sure refreshing happens mid-transaction, rather than at the end.
    it "should refresh resources as they're encountered rather than all at the end" do
        file = tmpfile("something")

        exec1 = Puppet::Type.type(:exec).new(
            :title => "one",
            :name => "echo one >> %s" % file,
            :path => "/usr/bin:/bin"
        )

        exec2 = Puppet::Type.type(:exec).new(
            :title => "two",
            :name => "echo two >> %s" % file,
            :path => "/usr/bin:/bin",
            :refreshonly => true,
            :subscribe => exec1
        )

        exec3 = Puppet::Type.type(:exec).new(
            :title => "three",
            :name => "echo three >> %s" % file,
            :path => "/usr/bin:/bin",
            :require => exec2
        )
        execs = [exec1, exec2, exec3]

        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource(exec1,exec2,exec3)

        trans = Puppet::Transaction.new(catalog)
        execs.each { |e| catalog.should be_vertex(e) }
        trans.prepare
        execs.each { |e| catalog.should be_vertex(e) }
        reverse = trans.relationship_graph.reversal
        execs.each { |e| reverse.should be_vertex(e) }

        catalog.apply

        FileTest.should be_exist(file)
        File.read(file).should == "one\ntwo\nthree\n"
    end
end
