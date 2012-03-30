#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/transaction'

describe Puppet::Transaction do
  include PuppetSpec::Files

  before do
    Puppet::Util::Storage.stubs(:store)
  end

  def mk_catalog(*resources)
    catalog = Puppet::Resource::Catalog.new(Puppet::Node.new("mynode"))
    resources.each { |res| catalog.add_resource res }
    catalog
  end

  def usr_bin_touch(path)
    Puppet.features.microsoft_windows? ? "#{ENV['windir']}/system32/cmd.exe /c \"type NUL >> \"#{path}\"\"" : "/usr/bin/touch #{path}"
  end

  def touch(path)
    Puppet.features.microsoft_windows? ? "cmd.exe /c \"type NUL >> \"#{path}\"\"" : "touch #{path}"
  end

  it "should not apply generated resources if the parent resource fails" do
    catalog = Puppet::Resource::Catalog.new
    resource = Puppet::Type.type(:file).new :path => make_absolute("/foo/bar"), :backup => false
    catalog.add_resource resource

    child_resource = Puppet::Type.type(:file).new :path => make_absolute("/foo/bar/baz"), :backup => false

    resource.expects(:eval_generate).returns([child_resource])

    transaction = Puppet::Transaction.new(catalog)

    resource.expects(:retrieve).raises "this is a failure"
    resource.stubs(:err)

    child_resource.expects(:retrieve).never

    transaction.evaluate
  end

  it "should not apply virtual resources" do
    catalog = Puppet::Resource::Catalog.new
    resource = Puppet::Type.type(:file).new :path => make_absolute("/foo/bar"), :backup => false
    resource.virtual = true
    catalog.add_resource resource

    transaction = Puppet::Transaction.new(catalog)

    resource.expects(:evaluate).never

    transaction.evaluate
  end

  it "should apply exported resources" do
    catalog = Puppet::Resource::Catalog.new
    path = tmpfile("exported_files")
    resource = Puppet::Type.type(:file).new :path => path, :backup => false, :ensure => :file
    resource.exported = true
    catalog.add_resource resource

    catalog.apply
    FileTest.should be_exist(path)
  end

  it "should not apply virtual exported resources" do
    catalog = Puppet::Resource::Catalog.new
    resource = Puppet::Type.type(:file).new :path => make_absolute("/foo/bar"), :backup => false
    resource.exported = true
    resource.virtual = true
    catalog.add_resource resource

    transaction = Puppet::Transaction.new(catalog)

    resource.expects(:evaluate).never

    transaction.evaluate
  end

  it "should not apply device resources on normal host" do
    catalog = Puppet::Resource::Catalog.new
    resource = Puppet::Type.type(:interface).new :name => "FastEthernet 0/1"
    catalog.add_resource resource

    transaction = Puppet::Transaction.new(catalog)
    transaction.for_network_device = false

    transaction.expects(:apply).never.with(resource, nil)

    transaction.evaluate
    transaction.resource_status(resource).should be_skipped
  end

  it "should not apply host resources on device" do
    catalog = Puppet::Resource::Catalog.new
    resource = Puppet::Type.type(:file).new :path => make_absolute("/foo/bar"), :backup => false
    catalog.add_resource resource

    transaction = Puppet::Transaction.new(catalog)
    transaction.for_network_device = true

    transaction.expects(:apply).never.with(resource, nil)

    transaction.evaluate
    transaction.resource_status(resource).should be_skipped
  end

  it "should apply device resources on device" do
    catalog = Puppet::Resource::Catalog.new
    resource = Puppet::Type.type(:interface).new :name => "FastEthernet 0/1"
    catalog.add_resource resource

    transaction = Puppet::Transaction.new(catalog)
    transaction.for_network_device = true

    transaction.expects(:apply).with(resource, nil)

    transaction.evaluate
    transaction.resource_status(resource).should_not be_skipped
  end

  it "should apply resources appliable on host and device on a device" do
    catalog = Puppet::Resource::Catalog.new
    resource = Puppet::Type.type(:schedule).new :name => "test"
    catalog.add_resource resource

    transaction = Puppet::Transaction.new(catalog)
    transaction.for_network_device = true

    transaction.expects(:apply).with(resource, nil)

    transaction.evaluate
    transaction.resource_status(resource).should_not be_skipped
  end

  # Verify that one component requiring another causes the contained
  # resources in the requiring component to get refreshed.
  it "should propagate events from a contained resource through its container to its dependent container's contained resources" do
    transaction = nil
    file = Puppet::Type.type(:file).new :path => tmpfile("event_propagation"), :ensure => :present
    execfile = File.join(tmpdir("exec_event"), "exectestingness2")
    exec = Puppet::Type.type(:exec).new :command => touch(execfile), :path => ENV['PATH']
    catalog = mk_catalog(file)

    fcomp = Puppet::Type.type(:component).new(:name => "Foo[file]")
    catalog.add_resource fcomp
    catalog.add_edge(fcomp, file)

    ecomp = Puppet::Type.type(:component).new(:name => "Foo[exec]")
    catalog.add_resource ecomp
    catalog.add_resource exec
    catalog.add_edge(ecomp, exec)

    ecomp[:subscribe] = Puppet::Resource.new(:foo, "file")
    exec[:refreshonly] = true

    exec.expects(:refresh)
    catalog.apply
  end

  # Make sure that multiple subscriptions get triggered.
  it "should propagate events to all dependent resources" do
    path = tmpfile("path")
    file1 = tmpfile("file1")
    file2 = tmpfile("file2")

    file = Puppet::Type.type(:file).new(
      :path   => path,
      :ensure => "file"
    )

    exec1 = Puppet::Type.type(:exec).new(
      :path    => ENV["PATH"],
      :command => touch(file1),
      :refreshonly => true,
      :subscribe   => Puppet::Resource.new(:file, path)
    )

    exec2 = Puppet::Type.type(:exec).new(
      :path        => ENV["PATH"],
      :command     => touch(file2),
      :refreshonly => true,
      :subscribe   => Puppet::Resource.new(:file, path)
    )

    catalog = mk_catalog(file, exec1, exec2)
    catalog.apply
    FileTest.should be_exist(file1)
    FileTest.should be_exist(file2)
  end

  it "should not let one failed refresh result in other refreshes failing" do
    path = tmpfile("path")
    newfile = tmpfile("file")
      file = Puppet::Type.type(:file).new(
      :path => path,
      :ensure => "file"
    )

    exec1 = Puppet::Type.type(:exec).new(
      :path => ENV["PATH"],
      :command => touch(File.expand_path("/this/cannot/possibly/exist")),
      :logoutput => true,
      :refreshonly => true,
      :subscribe => file,
      :title => "one"
    )

    exec2 = Puppet::Type.type(:exec).new(
      :path => ENV["PATH"],
      :command => touch(newfile),
      :logoutput => true,
      :refreshonly => true,
      :subscribe => [file, exec1],
      :title => "two"
    )

    exec1.stubs(:err)

    catalog = mk_catalog(file, exec1, exec2)
    catalog.apply
    FileTest.should be_exists(newfile)
  end

  it "should still trigger skipped resources" do
    catalog = mk_catalog
    catalog.add_resource(*Puppet::Type.type(:schedule).mkdefaultschedules)

    Puppet[:ignoreschedules] = false

    file = Puppet::Type.type(:file).new(
      :name => tmpfile("file"),
      :ensure => "file",
      :backup => false
    )

    fname = tmpfile("exec")

    exec = Puppet::Type.type(:exec).new(
      :name => touch(fname),
      :path => Puppet.features.microsoft_windows? ? "#{ENV['windir']}/system32" : "/usr/bin:/bin",
      :schedule => "monthly",
      :subscribe => Puppet::Resource.new("file", file.name)
    )

    catalog.add_resource(file, exec)

    # Run it once
    catalog.apply
    FileTest.should be_exists(fname)

    # Now remove it, so it can get created again
    File.unlink(fname)

    file[:content] = "some content"

    catalog.apply
    FileTest.should be_exists(fname)

    # Now remove it, so it can get created again
    File.unlink(fname)

    # And tag our exec
    exec.tag("testrun")

    # And our file, so it runs
    file.tag("norun")

    Puppet[:tags] = "norun"

    file[:content] = "totally different content"

    catalog.apply
    FileTest.should be_exists(fname)
  end

  it "should not attempt to evaluate resources with failed dependencies" do

    exec = Puppet::Type.type(:exec).new(
      :command => "#{File.expand_path('/bin/mkdir')} /this/path/cannot/possibly/exist",
      :title => "mkdir"
    )

    file1 = Puppet::Type.type(:file).new(
      :title => "file1",
      :path => tmpfile("file1"),
      :require => exec,
      :ensure => :file
    )

    file2 = Puppet::Type.type(:file).new(
      :title => "file2",
      :path => tmpfile("file2"),
      :require => file1,
      :ensure => :file
    )

    catalog = mk_catalog(exec, file1, file2)
    catalog.apply

    FileTest.should_not be_exists(file1[:path])
    FileTest.should_not be_exists(file2[:path])
  end

  it "should not trigger subscribing resources on failure" do
    file1 = tmpfile("file1")
    file2 = tmpfile("file2")

    create_file1 = Puppet::Type.type(:exec).new(
      :command => usr_bin_touch(file1)
    )

    exec = Puppet::Type.type(:exec).new(
      :command => "#{File.expand_path('/bin/mkdir')} /this/path/cannot/possibly/exist",
      :title => "mkdir",
      :notify => create_file1
    )

    create_file2 = Puppet::Type.type(:exec).new(
      :command => usr_bin_touch(file2),
      :subscribe => exec
    )

    catalog = mk_catalog(exec, create_file1, create_file2)
    catalog.apply

    FileTest.should_not be_exists(file1)
    FileTest.should_not be_exists(file2)
  end

  # #801 -- resources only checked in noop should be rescheduled immediately.
  it "should immediately reschedule noop resources" do
    Puppet::Type.type(:schedule).mkdefaultschedules
    resource = Puppet::Type.type(:notify).new(:name => "mymessage", :noop => true)
    catalog = Puppet::Resource::Catalog.new
    catalog.add_resource resource

    trans = catalog.apply

    trans.resource_harness.should be_scheduled(trans.resource_status(resource), resource)
  end
end
