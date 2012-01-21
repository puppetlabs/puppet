#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppettest'
require 'mocha'

class TestPuppetUtil < Test::Unit::TestCase
  include PuppetTest

  def test_withumask
    oldmask = File.umask

    path = tempfile

    # FIXME this fails on FreeBSD with a mode of 01777
    Puppet::Util.withumask(000) do
      Dir.mkdir(path, 0777)
    end

    assert(File.stat(path).mode & 007777 == 0777, "File has the incorrect mode")
    assert_equal(oldmask, File.umask, "Umask was not reset")
  end

  def test_benchmark
    path = tempfile
    str = "yayness"
    File.open(path, "w") do |f| f.print "yayness" end

    # First test it with the normal args
    assert_nothing_raised do
      val = nil
      result = Puppet::Util.benchmark(:notice, "Read file") do
        val = File.read(path)
      end

      assert_equal(str, val)

      assert_instance_of(Float, result)

    end

    # Now test it with a passed object
    assert_nothing_raised do
      val = nil
      Puppet::Util.benchmark(Puppet, :notice, "Read file") do
        val = File.read(path)
      end

      assert_equal(str, val)
    end
  end

  def test_proxy
    klass = Class.new do
      attr_accessor :hash
      class << self
        attr_accessor :ohash
      end
    end
    klass.send(:include, Puppet::Util)

    klass.ohash = {}

    inst = klass.new
    inst.hash = {}
    assert_nothing_raised do
      Puppet::Util.proxy klass, :hash, "[]", "[]=", :clear, :delete
    end

    assert_nothing_raised do
      Puppet::Util.classproxy klass, :ohash, "[]", "[]=", :clear, :delete
    end

    assert_nothing_raised do
      inst[:yay] = "boo"
      inst["cool"] = :yayness
    end

    [:yay, "cool"].each do |var|
      assert_equal(inst.hash[var], inst[var], "Var #{var} did not take")
    end

    assert_nothing_raised do
      klass[:Yay] = "boo"
      klass["Cool"] = :yayness
    end

    [:Yay, "Cool"].each do |var|
      assert_equal(inst.hash[var], inst[var], "Var #{var} did not take")
    end
  end

  def test_symbolize
    ret = nil
    assert_nothing_raised {
      ret = Puppet::Util.symbolize("yayness")
    }

    assert_equal(:yayness, ret)

    assert_nothing_raised {
      ret = Puppet::Util.symbolize(:yayness)
    }

    assert_equal(:yayness, ret)

    assert_nothing_raised {
      ret = Puppet::Util.symbolize(43)
    }

    assert_equal(43, ret)

    assert_nothing_raised {
      ret = Puppet::Util.symbolize(nil)
    }

    assert_equal(nil, ret)
  end

  def test_execute
    command = tempfile
    File.open(command, "w") { |f|
      f.puts %{#!/bin/sh\n/bin/echo "$1">&1; echo "$2">&2}
    }
    File.chmod(0755, command)
    output = nil
    assert_nothing_raised do
      output = Puppet::Util.execute([command, "yaytest", "funtest"])
    end
    assert_equal("yaytest\nfuntest\n", output)

    # Now try it with a single quote
    assert_nothing_raised do
      output = Puppet::Util.execute([command, "yay'test", "funtest"])
    end
    assert_equal("yay'test\nfuntest\n", output)

    # Now make sure we can squelch output (#565)
    assert_nothing_raised do
      output = Puppet::Util.execute([command, "yay'test", "funtest"], :squelch => true)
    end
    assert_equal(nil, output)

    # Now test that we correctly fail if the command returns non-zero
    assert_raise(Puppet::ExecutionFailure) do
      out = Puppet::Util.execute(["touch", "/no/such/file/could/exist"])
    end

    # And that we can tell it not to fail
    assert_nothing_raised do
      out = Puppet::Util.execute(["touch", "/no/such/file/could/exist"], :failonfail => false)
    end

    if Process.uid == 0
      # Make sure we correctly set our uid and gid
      user = nonrootuser
      group = nonrootgroup
      file = tempfile
      assert_nothing_raised do
        Puppet::Util.execute(["touch", file], :uid => user.name, :gid => group.name)
      end
      assert(FileTest.exists?(file), "file was not created")
      assert_equal(user.uid, File.stat(file).uid, "uid was not set correctly")

      # We can't really check the gid, because it just behaves too
      # inconsistently everywhere.
      # assert_equal(group.gid, File.stat(file).gid,
      #    "gid was not set correctly")
    end

    # (#565) Test the case of patricide.
    patricidecommand = tempfile
    File.open(patricidecommand, "w") { |f|
      f.puts %{#!/bin/bash\n/bin/bash -c 'kill -TERM \$PPID' &;\n while [ 1 ]; do echo -n ''; done;\n}
    }
    File.chmod(0755, patricidecommand)
    assert_nothing_raised do
      output = Puppet::Util.execute([patricidecommand], :squelch => true)
    end
    assert_equal(nil, output)
    # See what happens if we try and read the pipe to the command...
    assert_raise(Puppet::ExecutionFailure) do
      output = Puppet::Util.execute([patricidecommand])
    end
    assert_nothing_raised do
      output = Puppet::Util.execute([patricidecommand], :failonfail => false)
    end
  end

  def test_lang_environ_in_execute
    orig_lang = ENV["LANG"]
    orig_lc_all = ENV["LC_ALL"]
    orig_lc_messages = ENV["LC_MESSAGES"]
    orig_language = ENV["LANGUAGE"]

    cleanup do
      ENV["LANG"] = orig_lang
      ENV["LC_ALL"] = orig_lc_all
      ENV["LC_MESSAGES"] = orig_lc_messages
      ENV["LANGUAGE"] = orig_lc_messages
    end

    # Mmm, we love gettext(3)
    ENV["LANG"] = "en_US"
    ENV["LC_ALL"] = "en_US"
    ENV["LC_MESSAGES"] = "en_US"
    ENV["LANGUAGE"] = "en_US"

    %w{LANG LC_ALL LC_MESSAGES LANGUAGE}.each do |env|

      assert_equal(
        'C',
          Puppet::Util.execute(['ruby', '-e', "print ENV['#{env}']"]),

          "Environment var #{env} wasn't set to 'C'")

      assert_equal 'en_US', ENV[env], "Environment var #{env} not set back correctly"
    end

  end
end

