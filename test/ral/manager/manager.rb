#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-11-29.
#  Copyright (c) 2006. All rights reserved.

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'

class TestTypeManager < Test::Unit::TestCase
  include PuppetTest

  class FakeManager
    extend Puppet::MetaType::Manager
    def self.clear
      @types = {}
    end
  end

  def teardown
    super
    FakeManager.clear
  end

  # Make sure we can remove defined types
  def test_rmtype
    assert_nothing_raised {
      FakeManager.newtype :testing do
        newparam(:name, :namevar => true)
      end
    }
    assert(FakeManager.type(:testing), "Did not get fake type")

    assert_nothing_raised do
      FakeManager.rmtype(:testing)
    end

    assert_nil(FakeManager.type(:testing), "Type was not removed")
    assert(! defined?(FakeManager::Testing), "Constant was not removed")
  end

  def test_newtype
    assert_nothing_raised do
      FakeManager.newtype(:testing, :self_refresh => true) do
        newparam(:name, :namevar => true)
      end
    end

    test = FakeManager.type(:testing)
    assert(test, "did not get type")
    assert(test.self_refresh, "did not set attribute")
  end
end

