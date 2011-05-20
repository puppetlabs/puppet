#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../lib/puppettest')

require 'puppettest'
require 'puppettest/fileparsing'
require 'test/unit'

class TestParsedHostProvider < Test::Unit::TestCase
  include PuppetTest
  include PuppetTest::FileParsing

  def setup
    super
    @provider = Puppet::Type.type(:host).provider(:parsed)

    @oldfiletype = @provider.filetype
  end

  def teardown
    Puppet::Util::FileType.filetype(:ram).clear
    @provider.filetype = @oldfiletype
    @provider.clear
    super
  end

  # Parse our sample data and make sure we regenerate it correctly.
  def test_hostsparse
    fakedata("data/types/hosts").each do |file| fakedataparse(file) end
  end
end

