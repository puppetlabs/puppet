#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppettest'
require 'puppet/util/subclass_loader'

class TestPuppetUtilSubclassLoader < Test::Unit::TestCase
  include PuppetTest

  class LoadTest
    extend Puppet::Util::SubclassLoader
    handle_subclasses :faker, "puppet/fakeloaders"
  end

  def mk_subclass(name, path, parent)
    # Make a fake client
    unless defined?(@basedir)
      @basedir ||= tempfile
      $LOAD_PATH << @basedir
      cleanup { $LOAD_PATH.delete(@basedir) if $LOAD_PATH.include?(@basedir) }
    end

    libdir = File.join([@basedir, path.split(File::SEPARATOR)].flatten)
    FileUtils.mkdir_p(libdir)

    file = File.join(libdir, "#{name}.rb")
    File.open(file, "w") do |f|
      f.puts %{class #{parent}::#{name.to_s.capitalize} < #{parent}; end}
    end
  end

  def test_subclass_loading
    # Make a fake client
    mk_subclass("fake", "puppet/fakeloaders", "TestPuppetUtilSubclassLoader::LoadTest")


    fake = nil
    assert_nothing_raised do
      fake = LoadTest.faker(:fake)
    end
    assert_nothing_raised do
      assert_equal(fake, LoadTest.fake, "Did not get subclass back from main method")
    end
    assert(fake, "did not load subclass")

    # Now make sure the subclass behaves correctly
    assert_equal(:Fake, fake.name, "name was not calculated correctly")
  end

  def test_multiple_subclasses
    sub1 = Class.new(LoadTest)
    Object.const_set("Sub1", sub1)
    sub2 = Class.new(sub1)
    Object.const_set("Sub2", sub2)
    assert_equal(sub2, LoadTest.sub2, "did not get subclass of subclass")
  end

  # I started out using a class variable to mark the loader,
  # but it's shared among all classes that include this module,
  # so it didn't work.  This is testing whether I get the behaviour
  # that I want.
  def test_multiple_classes_using_module
    other = Class.new do
      extend Puppet::Util::SubclassLoader
      handle_subclasses :other, "puppet/other"
    end
    Object.const_set("OtherLoader", other)

    mk_subclass("multipletest", "puppet/other", "OtherLoader")
    mk_subclass("multipletest", "puppet/fakeloaders", "TestPuppetUtilSubclassLoader::LoadTest")
    #system("find #{@basedir}")
    #puts File.read(File.join(@basedir, "puppet/fakeloaders/multipletest.rb"))
    #puts File.read(File.join(@basedir, "puppet/other/multipletest.rb"))

    othersub = mainsub = nil
    assert_nothing_raised("Could not look up other sub") do
      othersub = OtherLoader.other(:multipletest)
    end
    assert_nothing_raised("Could not look up main sub") do
      mainsub = LoadTest.faker(:multipletest)
    end
    assert(othersub, "did not get other sub")
    assert(mainsub, "did not get main sub")
    assert(othersub.ancestors.include?(OtherLoader), "othersub is not a subclass of otherloader")
    assert(mainsub.ancestors.include?(LoadTest), "mainsub is not a subclass of loadtest")
  end
end

