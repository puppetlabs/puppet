#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../lib/puppettest')

require 'puppettest'
require 'puppettest/fileparsing'

class TestMailaliasAliasesProvider < Test::Unit::TestCase
  include PuppetTest
  include PuppetTest::FileParsing

  def setup
    super
    @provider = Puppet::Type.type(:mailalias).provider(:aliases)

    @oldfiletype = @provider.filetype

    @alias = mkalias
  end

  def teardown
    Puppet::Util::FileType.filetype(:ram).clear
    @provider.filetype = @oldfiletype
    @provider.clear
    super
  end

  def mkalias(name = "me")
    if defined?(@pcount)
      @pcount += 1
    else
      @pcount = 1
    end
    args = {
      :name => name,
      :recipient => %w{here there}
    }

    fakeresource = fakeresource(:mailalias, args[:name])

    key = @provider.new(fakeresource)
    args.each do |p,v|
      key.send(p.to_s + "=", v)
    end

    key
  end

  def test_data_parsing_and_generating
    fakedata("data/types/mailalias").each { |file|
      fakedataparse(file)
    }
  end
end

