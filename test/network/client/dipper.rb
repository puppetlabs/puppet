#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppet/file_bucket/dipper'

class TestDipperClient < Test::Unit::TestCase
  include PuppetTest::ServerTest

  def setup
    super
    @dipper = Puppet::FileBucket::Dipper.new(:Path => tempfile)
  end

  # Make sure we can create a new file with 'restore'.
  def test_restore_to_new_file
    file = tempfile
    text = "asdf;lkajseofiqwekj"
    File.open(file, "w") { |f| f.puts text }
    md5 = nil
    assert_nothing_raised("Could not send file") do
      md5 = @dipper.backup(file)
    end

    newfile = tempfile
    assert_nothing_raised("could not restore to new path") do
      @dipper.restore(newfile, md5)
    end

    assert_equal(File.read(file), File.read(newfile), "did not restore correctly")
  end
end

