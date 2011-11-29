#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'mocha'
require 'puppet'
require 'puppettest'
require 'puppettest/support/resources'
require 'puppettest/support/utils'

class TestTransactions < Test::Unit::TestCase
  include PuppetTest::FileTesting
  include PuppetTest::Support::Resources
  include PuppetTest::Support::Utils
  class Fakeprop <Puppet::Property
    initvars

    attr_accessor :path, :is, :should, :name
    def should_to_s(value)
      value.to_s
    end
    def insync?(foo)
      true
    end
    def info(*args)
      false
    end

    def set(value)
      # eh
    end

    def log(msg)
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
    type.class_eval(&block) if block
    cleanup do
      Puppet::Type.rmtype(:generator)
    end

    type
  end

  # Create a new type that generates instances with shorter names.
  def mkreducer(&block)
    type = mkgenerator do
      def eval_generate
        ret = []
        if title.length > 1
          ret << self.class.new(:title => title[0..-2])
        else
          return nil
        end
        ret
      end
    end

    type.class_eval(&block) if block

    type
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
      def self.prefetch(resources)
        $prefetched = resources
      end
    end

    # Now create an instance
    inst = type.new :name => "yay"

    # Create a transaction
    trans = Puppet::Transaction.new(mk_catalog(inst))

    # Make sure it gets called from within evaluate
    $prefetched = false
    assert_nothing_raised do
      trans.evaluate
    end

    assert_equal({inst.title => inst}, $prefetched, "evaluate did not call prefetch")
  end

  def test_ignore_tags?
    config = Puppet::Resource::Catalog.new
    config.host_config = true
    transaction = Puppet::Transaction.new(config)
    assert(! transaction.ignore_tags?, "Ignoring tags when applying a host catalog")

    config.host_config = false
    transaction = Puppet::Transaction.new(config)
    assert(transaction.ignore_tags?, "Not ignoring tags when applying a non-host catalog")
  end

  def test_missing_tags?
    resource = Puppet::Type.type(:notify).new :title => "foo"
    resource.stubs(:tagged?).returns true
    config = Puppet::Resource::Catalog.new

    # Mark it as a host config so we don't care which test is first
    config.host_config = true
    transaction = Puppet::Transaction.new(config)
    assert(! transaction.missing_tags?(resource), "Considered a resource to be missing tags when none are set")

    # host catalogs pay attention to tags, no one else does.
    Puppet[:tags] = "three,four"
    config.host_config = false
    transaction = Puppet::Transaction.new(config)
    assert(! transaction.missing_tags?(resource), "Considered a resource to be missing tags when not running a host catalog")

    #
    config.host_config = true
    transaction = Puppet::Transaction.new(config)
    assert(! transaction.missing_tags?(resource), "Considered a resource to be missing tags when running a host catalog and all tags are present")

    transaction = Puppet::Transaction.new(config)
    resource.stubs :tagged? => false
    assert(transaction.missing_tags?(resource), "Considered a resource not to be missing tags when running a host catalog and tags are missing")
  end

  # Make sure changes in contained files still generate callback events.
  def test_generated_callbacks
    dir = tempfile
    maker = tempfile
    Dir.mkdir(dir)
    file = File.join(dir, "file")
    File.open(file, "w") { |f| f.puts "" }
    File.chmod(0644, file)
    File.chmod(0755, dir) # So only the child file causes a change

    dirobj = Puppet::Type.type(:file).new :mode => "755", :recurse => true, :path => dir
    exec = Puppet::Type.type(:exec).new :title => "make",
      :command => "touch #{maker}", :path => ENV['PATH'], :refreshonly => true,
      :subscribe => dirobj

    assert_apply(dirobj, exec)
    assert(FileTest.exists?(maker), "Did not make callback file")
  end

  # Testing #401 -- transactions are calling refresh on classes that don't support it.
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

    file = Puppet::Type.type(:file).new :path => tempfile, :content => "yay"
    one = klass.new :name => "one", :subscribe => file

    assert_apply(file, one)

    assert(! $called.include?(:refresh), "Called refresh when it wasn't set as a method")
  end

  # Testing #437 - cyclic graphs should throw failures.
  def test_fail_on_cycle
    one = Puppet::Type.type(:exec).new(:name => "/bin/echo one")
    two = Puppet::Type.type(:exec).new(:name => "/bin/echo two")
    one[:require] = two
    two[:require] = one

    config = mk_catalog(one, two)
    trans = Puppet::Transaction.new(config)
    assert_raise(Puppet::Error) do
      trans.evaluate
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

    obj = type.new(:name => "testing")

    assert_apply(obj)
  end

  def test_self_refresh_causes_triggering
    type = Puppet::Type.newtype(:refresher, :self_refresh => true) do
      attr_accessor :refreshed, :testing
      newparam(:name) {}
      newproperty(:testing) do
        def retrieve
          :eh
        end

        def sync
          # noop
          :ran_testing
        end
      end
      def refresh
        @refreshed = true
      end
    end
    cleanup { Puppet::Type.rmtype(:refresher)}

    obj = type.new(:name => "yay", :testing => "cool")

    assert(! obj.insync?(obj.retrieve), "fake object is already in sync")

    # Now make sure it gets refreshed when the change happens
    assert_apply(obj)
    assert(obj.refreshed, "object was not refreshed during transaction")
  end

  # Testing #433
  def test_explicit_dependencies_beat_automatic
    # Create a couple of different resource sets that have automatic relationships and make sure the manual relationships win
    rels = {}
    # Now add the explicit relationship
    # Now files
    d = tempfile
    f = File.join(d, "file")
    file = Puppet::Type.type(:file).new(:path => f, :content => "yay")
    dir = Puppet::Type.type(:file).new(:path => d, :ensure => :directory, :require => file)

    rels[dir] = file
    rels.each do |after, before|
      config = mk_catalog(before, after)
      trans = Puppet::Transaction.new(config)
      str = "from #{before} to #{after}"

       assert_nothing_raised("Failed to create graph #{str}") do
         trans.add_dynamically_generated_resources
       end


      graph = trans.relationship_graph
      assert(graph.edge?(before, after), "did not create manual relationship #{str}")
      assert(! graph.edge?(after, before), "created automatic relationship #{str}")
    end
  end

  # #542 - make sure resources in noop mode still notify their resources,
  # so that users know if a service will get restarted.
  def test_noop_with_notify
    path = tempfile
    epath = tempfile
    spath = tempfile

          file = Puppet::Type.type(:file).new(
        :path => path, :ensure => :file,
        
      :title => "file")

          exec = Puppet::Type.type(:exec).new(
        :command => "touch #{epath}",
      :path => ENV["PATH"], :subscribe => file, :refreshonly => true,
        
      :title => 'exec1')

          exec2 = Puppet::Type.type(:exec).new(
        :command => "touch #{spath}",
      :path => ENV["PATH"], :subscribe => exec, :refreshonly => true,
        
      :title => 'exec2')

    Puppet[:noop] = true

    assert(file.noop, "file not in noop")
    assert(exec.noop, "exec not in noop")

    @logs.clear
    assert_apply(file, exec, exec2)

    assert(! FileTest.exists?(path), "Created file in noop")
    assert(! FileTest.exists?(epath), "Executed exec in noop")
    assert(! FileTest.exists?(spath), "Executed second exec in noop")

    assert(@logs.detect { |l|
      l.message =~ /should be/  and l.source == file.property(:ensure).path},
        "did not log file change")

          assert(
        @logs.detect { |l|
      l.message =~ /Would have/ and l.source == exec.path },
        
        "did not log first exec trigger")

          assert(
        @logs.detect { |l|
      l.message =~ /Would have/ and l.source == exec2.path },
        
        "did not log second exec trigger")
  end

  def test_only_stop_purging_with_relations
    files = []
    paths = []
    3.times do |i|
      path = tempfile
      paths << path

            file = Puppet::Type.type(:file).new(
        :path => path, :ensure => :absent,
        
        :backup => false, :title => "file#{i}")
      File.open(path, "w") { |f| f.puts "" }
      files << file
    end

    files[0][:ensure] = :file
    files[0][:require] = files[1..2]

    # Mark the second as purging
    files[1].purging

    assert_apply(*files)

    assert(FileTest.exists?(paths[1]), "Deleted required purging file")
    assert(! FileTest.exists?(paths[2]), "Did not delete non-purged file")
  end

  def test_flush
    $state = :absent
    $flushed = 0
    type = Puppet::Type.newtype(:flushtest) do
      newparam(:name)
      newproperty(:ensure) do
        newvalues :absent, :present, :other
        def retrieve
          $state
        end
        def set(value)
          $state = value
          :thing_changed
        end
      end

      def flush
        $flushed += 1
      end
    end

    cleanup { Puppet::Type.rmtype(:flushtest) }

    obj = type.new(:name => "test", :ensure => :present)

    # first make sure it runs through and flushes
    assert_apply(obj)

    assert_equal(:present, $state, "Object did not make a change")
    assert_equal(1, $flushed, "object was not flushed")

    # Now run a noop and make sure we don't flush
    obj[:ensure] = "other"
    obj[:noop] = true

    assert_apply(obj)
    assert_equal(:present, $state, "Object made a change in noop")
    assert_equal(1, $flushed, "object was flushed in noop")
  end
end
