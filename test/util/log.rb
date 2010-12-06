#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppet/util/log'
require 'puppettest'

class TestLog < Test::Unit::TestCase
  include PuppetTest

  def setup
    super
    @oldloglevel = Puppet::Util::Log.level
    Puppet::Util::Log.close_all
  end

  def teardown
    super
    Puppet::Util::Log.close_all
    Puppet::Util::Log.level = @oldloglevel
  end

  def getlevels
    levels = nil
    assert_nothing_raised {
      levels = []
      Puppet::Util::Log.eachlevel { |level| levels << level }
    }
    # Don't test the top levels; too annoying
    levels.reject { |level| level == :emerg or level == :crit }
  end

  def mkmsgs(levels)
    levels.collect { |level|
      next if level == :alert
      assert_nothing_raised {

              Puppet::Util::Log.new(
                
          :level => level,
          :source => "Test",
        
          :message => "Unit test for #{level}"
        )
      }
    }
  end

  def test_logfile
    fact = nil
    levels = nil
    Puppet::Util::Log.level = :debug
    levels = getlevels
    logfile = tempfile
    fact = nil
    assert_nothing_raised {
      Puppet::Util::Log.newdestination(logfile)
    }
    msgs = mkmsgs(levels)
    assert(msgs.length == levels.length)
    Puppet::Util::Log.close_all
    count = 0

    assert(FileTest.exists?(logfile), "Did not create logfile")

    assert_nothing_raised {
      File.open(logfile) { |of|
        count = of.readlines.length
      }
    }
    assert(count == levels.length - 1) # skip alert
  end

  def test_syslog
    levels = nil
    assert_nothing_raised {
      levels = getlevels.reject { |level|
        level == :emerg || level == :crit
      }
    }
    assert_nothing_raised {
      Puppet::Util::Log.newdestination("syslog")
    }
    # there's really no way to verify that we got syslog messages...
    msgs = mkmsgs(levels)
    assert(msgs.length == levels.length)
  end

  def test_levelmethods
    assert_nothing_raised {
      Puppet::Util::Log.newdestination("/dev/null")
    }
    getlevels.each { |level|
      assert_nothing_raised {
        Puppet.send(level,"Testing for #{level}")
      }
    }
  end

  def test_output
    Puppet::Util::Log.level = :notice
    assert(Puppet.err("This is an error").is_a?(Puppet::Util::Log))
    assert(Puppet.debug("This is debugging").nil?)
    Puppet::Util::Log.level = :debug
    assert(Puppet.err("This is an error").is_a?(Puppet::Util::Log))
    assert(Puppet.debug("This is debugging").is_a?(Puppet::Util::Log))
  end

  def test_creatingdirs
    dir = tempfile
    file = File.join(dir, "logfile")
    Puppet::Util::Log.newdestination file
    Puppet.info "testing logs"
    assert(FileTest.directory?(dir))
    assert(FileTest.file?(file))
  end

  # Verify that we can pass strings that match printf args
  def test_percentlogs
    Puppet::Util::Log.newdestination :syslog

    assert_nothing_raised {

            Puppet::Util::Log.new(
                
        :level => :info,
        
        :message => "A message with %s in it"
      )
    }
  end

  # Verify that the error and source are always strings
  def test_argsAreStrings
    msg = nil

          file = Puppet::Type.type(:file).new(
                
      :path => tempfile,
        
      :check => %w{owner group}
    )
    assert_nothing_raised {
      msg = Puppet::Util::Log.new(:level => :info, :message => "This is a message")
    }
    assert_nothing_raised {
      msg.source = file
    }

    assert_instance_of(String, msg.to_s)
    assert_instance_of(String, msg.source)
  end

  def test_destination_matching
    dest = nil
    assert_nothing_raised {
      dest = Puppet::Util::Log.newdesttype("Destine") do
        def handle(msg)
          puts msg
        end
      end
    }

    [:destine, "Destine", "destine"].each do |name|
      assert(dest.match?(name), "Did not match #{name.inspect}")
    end

    assert_nothing_raised {
      dest.match(:yayness)
    }
    assert(dest.match("Yayness"), "Did not match yayness")
    Puppet::Util::Log.close(dest)
  end

  def test_autoflush
    file = tempfile
    Puppet::Util::Log.close(:console)
    Puppet::Util::Log.newdestination(file)
    Puppet.warning "A test"
    assert(File.read(file) !~ /A test/, "File defualted to autoflush")
    Puppet::Util::Log.flush
    assert(File.read(file) =~ /A test/, "File did not flush")
    Puppet::Util::Log.close(file)

    # Now try one with autoflush enabled
    Puppet[:autoflush] = true
    file = tempfile
    Puppet::Util::Log.newdestination(file)
    Puppet.warning "A test"
    assert(File.read(file) =~ /A test/, "File did not autoflush")
    Puppet::Util::Log.close(file)
  end

  def test_reopen
    Puppet[:autoflush] = true
    file = tempfile
    Puppet::Util::Log.close(:console)
    Puppet::Util::Log.newdestination(file)
    Puppet.warning "A test"
    assert(File.read(file) =~ /A test/,
      "File did not flush")
    # Rename the file
    newfile = file + ".old"
    File.rename(file, newfile)

    # Send another log
    Puppet.warning "Another test"
    assert(File.read(newfile) =~ /Another test/,
      "File did not rename")

    # Now reopen the log
    Puppet::Util::Log.reopen
    Puppet.warning "Reopen test"
    assert(File.read(file) =~ /Reopen test/, "File did not reopen")
    Puppet::Util::Log.close(file)
  end
end

