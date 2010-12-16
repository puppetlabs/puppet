#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppettest'

class TestStorage < Test::Unit::TestCase
  include PuppetTest

  def mkfile
    path = tempfile
    File.open(path, "w") { |f| f.puts :yayness }


          f = Puppet::Type.type(:file).new(
                
      :name => path,
        
      :check => %w{checksum type}
    )

    f
  end

  def test_storeandretrieve
    path = tempfile

    f = mkfile

    # Load first, since that's what we do in the code base; this creates
    # all of the necessary directories.
    assert_nothing_raised {
      Puppet::Util::Storage.load
    }

    hash = {:a => :b, :c => :d}

    state = nil
    assert_nothing_raised {
      state = Puppet::Util::Storage.cache(f)
    }

    assert(!state.include?("name"))

    assert_nothing_raised {
      state["name"] = hash
    }

    assert_nothing_raised {
      Puppet::Util::Storage.store
    }
    assert_nothing_raised {
      Puppet::Util::Storage.clear
    }
    assert_nothing_raised {
      Puppet::Util::Storage.load
    }

    # Reset it
    state = nil
    assert_nothing_raised {
      state = Puppet::Util::Storage.cache(f)
    }

    assert_equal(state["name"], hash)
  end

  def test_emptyrestore
    Puppet::Util::Storage.load
    Puppet::Util::Storage.store
    Puppet::Util::Storage.clear
    Puppet::Util::Storage.load

    f = mkfile
    state = Puppet::Util::Storage.cache(f)
    assert_same Hash, state.class
    assert_equal 0, state.size
  end
end

