#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppet/network/handler/fileserver'

class TestFileServer < Test::Unit::TestCase
  include PuppetTest

  def mkmount(path = nil)
    mount = nil
    name = "yaytest"
    base = path || tempfile
    Dir.mkdir(base) unless FileTest.exists?(base)
    # Create a test file
    File.open(File.join(base, "file"), "w") { |f| f.puts "bazoo" }
    assert_nothing_raised {
      mount = Puppet::Network::Handler.fileserver::Mount.new(name, base)
    }

    mount
  end
  # make a simple file source
  def mktestdir
    testdir = File.join(tmpdir, "remotefilecopytesting")
    @@tmpfiles << testdir

    # create a tmpfile
    pattern = "tmpfile"
    tmpfile = File.join(testdir, pattern)
    assert_nothing_raised {
      Dir.mkdir(testdir)
      File.open(tmpfile, "w") { |f|
        3.times { f.puts rand(100) }
      }
    }

    [testdir, %r{#{pattern}}, tmpfile]
  end

  # make a bunch of random test files
  def mktestfiles(testdir)
    @@tmpfiles << testdir
    assert_nothing_raised {
      files = %w{a b c d e}.collect { |l|
        name = File.join(testdir, "file#{l}")
        File.open(name, "w") { |f|
          f.puts rand(100)
        }

        name
      }

      return files
    }
  end

  def assert_describe(base, file, server)
    file = File.basename(file)
    assert_nothing_raised {
      desc = server.describe(base + file)
      assert(desc, "Got no description for #{file}")
      assert(desc != "", "Got no description for #{file}")
      assert_match(/^\d+/, desc, "Got invalid description #{desc}")
    }
  end

  # test for invalid names
  def test_namefailures
    server = nil
    assert_nothing_raised {

      server = Puppet::Network::Handler.fileserver.new(

        :Local => true,

        :Config => false
      )
    }

    [" ", "=" "+", "&", "#", "*"].each do |char|
      assert_raise(Puppet::Network::Handler::FileServerError, "'#{char}' did not throw a failure in fileserver module names") {
        server.mount("/tmp", "invalid#{char}name")
      }
    end
  end

  # verify that listing the root behaves as expected
  def test_listroot
    server = nil
    testdir, pattern, tmpfile = mktestdir

    file = nil
    checks = Puppet::Network::Handler.fileserver::CHECKPARAMS

    # and make our fileserver
    assert_nothing_raised {

      server = Puppet::Network::Handler.fileserver.new(

        :Local => true,

        :Config => false
      )
    }

    # mount the testdir
    assert_nothing_raised {
      server.mount(testdir, "test")
    }

    # and verify different iterations of 'root' return the same value
    list = nil
    assert_nothing_raised {
      list = server.list("/test/", :manage, true, false)
    }

    assert(list =~ pattern)

    assert_nothing_raised {
      list = server.list("/test", :manage, true, false)
    }
    assert(list =~ pattern)

  end

  # test listing individual files
  def test_getfilelist
    server = nil
    testdir, pattern, tmpfile = mktestdir

    file = nil

    assert_nothing_raised {

      server = Puppet::Network::Handler.fileserver.new(

        :Local => true,

        :Config => false
      )
    }

    assert_nothing_raised {
      server.mount(testdir, "test")
    }

    # get our listing
    list = nil
    sfile = "/test/tmpfile"
    assert_nothing_raised {
      list = server.list(sfile, :manage, true, false)
    }

    output = "/\tfile"

    # verify it got listed as a file
    assert_equal(output, list)

    # verify we got all fields
    assert(list !~ /\t\t/)

    # verify that we didn't get the directory itself
    list.split("\n").each { |line|
      assert(line !~ %r{remotefile})
    }

    # and then verify that the contents match
    contents = File.read(tmpfile)

    ret = nil
    assert_nothing_raised {
      ret = server.retrieve(sfile)
    }

    assert_equal(contents, ret)
  end

  # check that the fileserver is seeing newly created files
  def test_seenewfiles
    server = nil
    testdir, pattern, tmpfile = mktestdir


    newfile = File.join(testdir, "newfile")

    # go through the whole schtick again...
    file = nil
    checks = Puppet::Network::Handler.fileserver::CHECKPARAMS

    assert_nothing_raised {

      server = Puppet::Network::Handler.fileserver.new(

        :Local => true,

        :Config => false
      )
    }

    assert_nothing_raised {
      server.mount(testdir, "test")
    }

    list = nil
    sfile = "/test/"
    assert_nothing_raised {
      list = server.list(sfile, :manage, true, false)
    }

    # create the new file
    File.open(newfile, "w") { |f|
      3.times { f.puts rand(100) }
    }

    newlist = nil
    assert_nothing_raised {
      newlist = server.list(sfile, :manage, true, false)
    }

    # verify the list has changed
    assert(list != newlist)

    # and verify that we are specifically seeing the new file
    assert(newlist =~ /newfile/)
  end

  # verify we can mount /, which is what local file servers will
  # normally do
  def test_mountroot
    server = nil
    assert_nothing_raised {

      server = Puppet::Network::Handler.fileserver.new(

        :Local => true,

        :Config => false
      )
    }

    assert_nothing_raised {
      server.mount("/", "root")
    }

    testdir, pattern, tmpfile = mktestdir

    list = nil
    assert_nothing_raised {
      list = server.list("/root/#{testdir}", :manage, true, false)
    }

    assert(list =~ pattern)
    assert_nothing_raised {
      list = server.list("/root#{testdir}", :manage, true, false)
    }

    assert(list =~ pattern)
  end

  # verify that we're correctly recursing the right number of levels
  def test_recursionlevels
    server = nil
    assert_nothing_raised {

      server = Puppet::Network::Handler.fileserver.new(

        :Local => true,

        :Config => false
      )
    }

    # make our deep recursion
    basedir = File.join(tmpdir, "recurseremotetesting")
    testdir = "#{basedir}/with/some/sub/directories/for/the/purposes/of/testing"
    oldfile = File.join(testdir, "oldfile")
    assert_nothing_raised {
      system("mkdir -p #{testdir}")
      File.open(oldfile, "w") { |f|
        3.times { f.puts rand(100) }
      }
      @@tmpfiles << basedir
    }

    assert_nothing_raised {
      server.mount(basedir, "test")
    }

    # get our list
    list = nil
    assert_nothing_raised {
      list = server.list("/test/with", :manage, false, false)
    }

    # make sure we only got one line, since we're not recursing
    assert(list !~ /\n/)

    # for each level of recursion, make sure we get the right list
    [0, 1, 2].each { |num|
      assert_nothing_raised {
        list = server.list("/test/with", :manage, num, false)
      }

      count = 0
      while list =~ /\n/
        list.sub!(/\n/, '')
        count += 1
      end
      assert_equal(num, count)
    }
  end

  # verify that we're not seeing the dir we ask for; i.e., that our
  # list is relative to that dir, not it's parent dir
  def test_listedpath
    server = nil
    assert_nothing_raised {

      server = Puppet::Network::Handler.fileserver.new(

        :Local => true,

        :Config => false
      )
    }


    # create a deep dir
    basedir = tempfile
    testdir = "#{basedir}/with/some/sub/directories/for/testing"
    oldfile = File.join(testdir, "oldfile")
    assert_nothing_raised {
      system("mkdir -p #{testdir}")
      File.open(oldfile, "w") { |f|
        3.times { f.puts rand(100) }
      }
      @@tmpfiles << basedir
    }

    # mounty mounty
    assert_nothing_raised {
      server.mount(basedir, "localhost")
    }

    list = nil
    # and then check a few dirs
    assert_nothing_raised {
      list = server.list("/localhost/with", :manage, false, false)
    }

    assert(list !~ /with/)

    assert_nothing_raised {
      list = server.list("/localhost/with/some/sub", :manage, true, false)
    }

    assert(list !~ /sub/)
  end

  # test many dirs, not necessarily very deep
  def test_widelists
    server = nil
    assert_nothing_raised {

      server = Puppet::Network::Handler.fileserver.new(

        :Local => true,

        :Config => false
      )
    }

    basedir = tempfile
    dirs = %w{a set of directories}
    assert_nothing_raised {
      Dir.mkdir(basedir)
      dirs.each { |dir|
        Dir.mkdir(File.join(basedir, dir))
      }
      @@tmpfiles << basedir
    }

    assert_nothing_raised {
      server.mount(basedir, "localhost")
    }

    list = nil
    assert_nothing_raised {
      list = server.list("/localhost/", :manage, 1, false)
    }
    assert_instance_of(String, list, "Server returned %s instead of string")
    list = list.split("\n")

    assert_equal(dirs.length + 1, list.length)
  end

  # verify that 'describe' works as advertised
  def test_describe
    server = nil
    testdir = tstdir
    files = mktestfiles(testdir)

    file = nil
    checks = Puppet::Network::Handler.fileserver::CHECKPARAMS

    assert_nothing_raised {

      server = Puppet::Network::Handler.fileserver.new(

        :Local => true,

        :Config => false
      )
    }

    assert_nothing_raised {
      server.mount(testdir, "test")
    }

    # get our list
    list = nil
    sfile = "/test/"
    assert_nothing_raised {
      list = server.list(sfile, :manage, true, false)
    }

    # and describe each file in the list
    assert_nothing_raised {
      list.split("\n").each { |line|
        file, type = line.split("\t")

        desc = server.describe(sfile + file)
      }
    }

    # and then make sure we can describe everything that we know is there
    files.each { |file|
      assert_describe(sfile, file, server)
    }

    # And then describe some files that we know aren't there
    retval = nil
    assert_nothing_raised("Describing non-existent files raised an error") {
      retval = server.describe(sfile + "noexisties")
    }

    assert_equal("", retval, "Description of non-existent files returned a value")

    # Now try to describe some sources that don't even exist
    retval = nil

      assert_raise(
        Puppet::Network::Handler::FileServerError,

      "Describing non-existent mount did not raise an error") {
      retval = server.describe("/notmounted/noexisties")
    }

    assert_nil(retval, "Description of non-existent mounts returned a value")
  end

  def test_describe_does_not_fail_when_mount_does_not_find_file
    server = Puppet::Network::Handler.fileserver.new(:Local => true, :Config => false)

    assert_nothing_raised("Failed when describing missing plugins") do
      server.describe "/plugins"
    end
  end

  # test that our config file is parsing and working as planned
  def test_configfile
    server = nil
    basedir = File.join(tmpdir, "fileserverconfigfiletesting")
    @@tmpfiles << basedir

    # make some dirs for mounting
    Dir.mkdir(basedir)
    mounts = {}
    %w{thing thus the-se those}.each { |dir|
      path = File.join(basedir, dir)
      Dir.mkdir(path)
      mounts[dir] = mktestfiles(path)

    }

    # create an example file with each of them
    conffile = tempfile
    @@tmpfiles << conffile

    File.open(conffile, "w") { |f|
      f.print "# a test config file

[thing]
  path #{basedir}/thing
  allow 192.168.0.*

[thus]
  path #{basedir}/thus
  allow *.madstop.com, *.kanies.com
  deny *.sub.madstop.com

[the-se]
  path #{basedir}/the-se

[those]
  path #{basedir}/those

"
  }


  # create a server with the file
  assert_nothing_raised {

    server = Puppet::Network::Handler.fileserver.new(

      :Local => false,

      :Config => conffile
      )
    }

    list = nil
    # run through once with no host/ip info, to verify everything is working
    mounts.each { |mount, files|
      mount = "/#{mount}/"
      assert_nothing_raised {
        list = server.list(mount, :manage, true, false)
      }

      assert_nothing_raised {
        list.split("\n").each { |line|
          file, type = line.split("\t")

          desc = server.describe(mount + file)
        }
      }

      files.each { |f|
        assert_describe(mount, f, server)
      }
    }

    # now let's check that things are being correctly forbidden
    # this is just a map of names and expected results
    {
      "thing" => {
        :deny => [
          ["hostname.com", "192.168.1.0"],
          ["hostname.com", "192.158.0.0"]
        ],
        :allow => [
          ["hostname.com", "192.168.0.0"],
          ["hostname.com", "192.168.0.245"],
        ]
      },
      "thus" => {
        :deny => [
          ["hostname.com", "192.168.1.0"],
          ["name.sub.madstop.com", "192.158.0.0"]
        ],
        :allow => [
          ["luke.kanies.com", "192.168.0.0"],
          ["luke.madstop.com", "192.168.0.245"],
        ]
      }
    }.each { |mount, hash|
      mount = "/#{mount}/"

      # run through the map
      hash.each { |type, ary|
        ary.each { |sub|
          host, ip = sub

          case type
          when :deny

            assert_raise(
              Puppet::AuthorizationError,

              "Host #{host}, ip #{ip}, allowed #{mount}") {
                list = server.list(mount, :manage, true, false, host, ip)
            }
          when :allow
            assert_nothing_raised("Host #{host}, ip #{ip}, denied #{mount}") {
              list = server.list(mount, :manage, true, false, host, ip)
            }
          end
        }
      }
    }

  end

  # Test that we smoothly handle invalid config files
  def test_configfailures
    # create an example file with each of them
    conffile = tempfile

    invalidmounts = {
      "noexist" => "[noexist]
  path /this/path/does/not/exist
  allow 192.168.0.*
"
}

  invalidconfigs = [
    "[not valid]
  path /this/path/does/not/exist
  allow 192.168.0.*
",
"[valid]
  invalidstatement
  path /etc
  allow 192.168.0.*
",
"[valid]
  allow 192.168.0.*
"
]

  invalidmounts.each { |mount, text|
    File.open(conffile, "w") { |f|
      f.print text
      }


      # create a server with the file
      server = nil
      assert_nothing_raised {

        server = Puppet::Network::Handler.fileserver.new(

          :Local => true,

          :Config => conffile
        )
      }


        assert_raise(
          Puppet::Network::Handler::FileServerError,

          "Invalid mount was mounted") {
            server.list(mount, :manage)
      }
    }

    invalidconfigs.each_with_index { |text, i|
      File.open(conffile, "w") { |f|
        f.print text
      }


      # create a server with the file
      server = nil

        assert_raise(
          Puppet::Network::Handler::FileServerError,

          "Invalid config #{i} did not raise error") {

            server = Puppet::Network::Handler.fileserver.new(

              :Local => true,

              :Config => conffile
        )
      }
    }
  end

  # verify we reread the config file when it changes
  def test_filereread
    server = nil

    conffile = tempfile
    dir = tstdir

    files = mktestfiles(dir)
    File.open(conffile, "w") { |f|
      f.print "# a test config file

[thing]
  path #{dir}
  allow test1.domain.com
"
  }

  # Reset the timeout, so we reload faster
  Puppet[:filetimeout] = 0.5

  # start our server with a fast timeout
  assert_nothing_raised {

    server = Puppet::Network::Handler.fileserver.new(

      :Local => false,

      :Config => conffile
      )
    }

    list = nil
    assert_nothing_raised {

      list = server.list(
        "/thing/", :manage, false, false,

        "test1.domain.com", "127.0.0.1")
    }
    assert(list != "", "List returned nothing in rereard test")

    assert_raise(Puppet::AuthorizationError, "List allowed invalid host") {
      list = server.list("/thing/", :manage, false, false, "test2.domain.com", "127.0.0.1")
    }

    sleep 1
    File.open(conffile, "w") { |f|
      f.print "# a test config file

[thing]
  path #{dir}
  allow test2.domain.com
"
  }

  assert_raise(Puppet::AuthorizationError, "List allowed invalid host") {
    list = server.list("/thing/", :manage, false, false, "test1.domain.com", "127.0.0.1")
    }

    assert_nothing_raised {
      list = server.list("/thing/", :manage, false, false, "test2.domain.com", "127.0.0.1")
    }

    assert(list != "", "List returned nothing in rereard test")

    list = nil
  end

  # Verify that we get converted to the right kind of string
  def test_mountstring
    mount = nil
    name = "yaytest"
    path = tmpdir
    assert_nothing_raised {
      mount = Puppet::Network::Handler.fileserver::Mount.new(name, path)
    }

    assert_equal("mount[#{name}]", mount.to_s)
  end

  def test_servinglinks
    # Disable the checking, so changes propagate immediately.
    Puppet[:filetimeout] = -5
    server = nil
    source = tempfile
    file = File.join(source, "file")
    link = File.join(source, "link")
    Dir.mkdir(source)
    File.open(file, "w") { |f| f.puts "yay" }
    File.symlink(file, link)
    assert_nothing_raised {

      server = Puppet::Network::Handler.fileserver.new(

        :Local => true,

        :Config => false
      )
    }

    assert_nothing_raised {
      server.mount(source, "mount")
    }

    # First describe the link when following
    results = {}
    assert_nothing_raised {
      server.describe("/mount/link", :follow).split("\t").zip(
        Puppet::Network::Handler.fileserver::CHECKPARAMS
      ).each { |v,p| results[p] = v }
    }

    assert_equal("file", results[:type])

    # Then not
    results = {}
    assert_nothing_raised {
      server.describe("/mount/link", :manage).split("\t").zip(
        Puppet::Network::Handler.fileserver::CHECKPARAMS
      ).each { |v,p| results[p] = v }
    }

    assert_equal("link", results[:type])

    results.each { |p,v|
      assert(v, "#{p} has no value")
      assert(v != "", "#{p} has no value")
    }
  end

  # Test that substitution patterns in the path are exapanded
  # properly.  Disabled, because it was testing too much of the process
  # and in a non-portable way.  This is a thorough enough test that it should
  # be kept, but it should be done in a way that is clearly portable (e.g.,
  # no md5 sums of file paths).
  def test_host_specific
    client1 = "client1.example.com"
    client2 = "client2.example.com"
    ip = "127.0.0.1"

    # Setup a directory hierarchy for the tests
    fsdir = File.join(tmpdir, "host-specific")
    @@tmpfiles << fsdir
    hostdir = File.join(fsdir, "host")
    fqdndir = File.join(fsdir, "fqdn")
    client1_hostdir = File.join(hostdir, "client1")
    client2_fqdndir = File.join(fqdndir, client2)
    contents = {
      client1_hostdir => "client1\n",
      client2_fqdndir => client2 + "\n"
    }
    [fsdir, hostdir, fqdndir, client1_hostdir, client2_fqdndir].each { |d|  Dir.mkdir(d) }

    [client1_hostdir, client2_fqdndir].each do |d|
      File.open(File.join(d, "file.txt"), "w") do |f|
        f.print contents[d]
      end
    end
    conffile = tempfile
    File.open(conffile, "w") do |f|
      f.print("
[host]
path #{hostdir}/%h
allow *
[fqdn]
path #{fqdndir}/%H
allow *
")
  end

  server = nil
  assert_nothing_raised {

    server = Puppet::Network::Handler.fileserver.new(

      :Local => true,

      :Config => conffile
      )
    }

    # check that list returns the correct thing for the two clients
    list = nil
    sfile = "/host/file.txt"
    assert_nothing_raised {
      list = server.list(sfile, :manage, true, false, client1, ip)
    }
    assert_equal("/\tfile", list)
    assert_nothing_raised {
      list = server.list(sfile, :manage, true, false, client2, ip)
    }
    assert_equal("", list)

    sfile = "/fqdn/file.txt"
    assert_nothing_raised {
      list = server.list(sfile, :manage, true, false, client1, ip)
    }
    assert_equal("", list)
    assert_nothing_raised {
      list = server.list(sfile, :manage, true, false, client2, ip)
    }
    assert_equal("/\tfile", list)

    # check describe
    sfile = "/host/file.txt"
    assert_nothing_raised {
      list = server.describe(sfile, :manage, client1, ip).split("\t")
    }
    assert_equal(5, list.size)
    assert_equal("file", list[1])
    md5 = Digest::MD5.hexdigest(contents[client1_hostdir])
    assert_equal("{md5}#{md5}", list[4])

    assert_nothing_raised {
      list = server.describe(sfile, :manage, client2, ip).split("\t")
    }
    assert_equal([], list)

    sfile = "/fqdn/file.txt"
    assert_nothing_raised {
      list = server.describe(sfile, :manage, client1, ip).split("\t")
    }
    assert_equal([], list)

    assert_nothing_raised {
      list = server.describe(sfile, :manage, client2, ip).split("\t")
    }
    assert_equal(5, list.size)
    assert_equal("file", list[1])
    md5 = Digest::MD5.hexdigest(contents[client2_fqdndir])
    assert_equal("{md5}#{md5}", list[4])

    # Check retrieve
    sfile = "/host/file.txt"
    assert_nothing_raised {
      list = server.retrieve(sfile, :manage, client1, ip).chomp
    }
    assert_equal(contents[client1_hostdir].chomp, list)

    assert_nothing_raised {
      list = server.retrieve(sfile, :manage, client2, ip).chomp
    }
    assert_equal("", list)

    sfile = "/fqdn/file.txt"
    assert_nothing_raised {
      list = server.retrieve(sfile, :manage, client1, ip).chomp
    }
    assert_equal("", list)

    assert_nothing_raised {
      list = server.retrieve(sfile, :manage, client2, ip).chomp
    }
    assert_equal(contents[client2_fqdndir].chomp, list)
  end

  # Make sure the 'subdir' method in Mount works.
  def test_mount_subdir
    mount = nil
    base = tempfile
    Dir.mkdir(base)
    subdir = File.join(base, "subdir")
    Dir.mkdir(subdir)
    [base, subdir].each do |d|
      File.open(File.join(d, "file"), "w") { |f| f.puts "bazoo" }
    end
    mount = mkmount(base)

    assert_equal(base, mount.subdir, "Did not default to base path")
    assert_equal(subdir, mount.subdir("subdir"), "Did not default to base path")
  end

  # Make sure mounts get correctly marked expandable or not, depending on
  # the path.
  def test_expandable
    name = "yaytest"
    dir = tempfile
    Dir.mkdir(dir)

    mount = mkmount
    assert_nothing_raised {
      mount.path = dir
    }

    assert(! mount.expandable?, "Mount incorrectly called expandable")

    assert_nothing_raised {
      mount.path = "/dir/a%a"
    }
    assert(mount.expandable?, "Mount not called expandable")

    # This isn't a valid replacement pattern, so it should throw an error
    # because the dir doesn't exist
    assert_raise(Puppet::Network::Handler::FileServerError) {
      mount.path = "/dir/a%"
    }

    # Now send it back to a normal path
    assert_nothing_raised {
      mount.path = dir
    }
    # Make sure it got reverted
    assert(! mount.expandable?, "Mount incorrectly called expandable")


  end

  def test_mount_expand
    mount = mkmount

    check = proc do |client, pattern, repl|
      path = "/my/#{pattern}/file"
      assert_equal("/my/#{repl}/file", mount.expand(path, client))
    end

    # Do a round of checks with a fake client
    client = "host.domain.com"
    {"%h" => "host", # Short name
    "%H" => client, # Full name
    "%d" => "domain.com", # domain
    "%%" => "%", # escape
    "%o" => "%o" # other
    }.each do |pat, repl|
      result = check.call(client, pat, repl)
    end

    # Now, check that they use Facter info
    client = nil
    Facter.stubs(:value).with { |v| v.to_s == "hostname" }.returns("myhost")
    Facter.stubs(:value).with { |v| v.to_s == "domain" }.returns("mydomain.com")


      Facter.stubs(:to_hash).returns(
        {
          :ipaddress => "127.0.0.1",
          :hostname => "myhost",
          :domain   => "mydomain.com",

    })


    {"%h" => "myhost", # Short name
    "%H" => "myhost.mydomain.com", # Full name
    "%d" => "mydomain.com", # domain
    "%%" => "%", # escape
    "%o" => "%o" # other
    }.each do |pat, repl|
      check.call(client, pat, repl)
    end

  end

  # Test that the fileserver expands the %h and %d things.
  def test_fileserver_expansion
    server = nil
    assert_nothing_raised {

      server = Puppet::Network::Handler.fileserver.new(

        :Local => true,

        :Config => false
      )
    }

    dir = tempfile

    # When mocks attack, part 2
    kernel_fact = Facter.value(:kernel)

    ip = '127.0.0.1'


      Facter.stubs(:to_hash).returns(
        {
          :kernel => kernel_fact,
          :ipaddress => "127.0.0.1",
          :hostname => "myhost",
          :domain   => "mydomain.com",

    })

    Dir.mkdir(dir)
    host = "myhost.mydomain.com"
    {
      "%H" => "myhost.mydomain.com", "%h" => "myhost", "%d" => "mydomain.com"
    }.each do |pattern, string|
      file = File.join(dir, string)
      mount = File.join(dir, pattern)
      File.open(file, "w") do |f| f.puts "yayness: #{string}" end
      name = "name"
      obj = nil
      assert_nothing_raised {
        obj = server.mount(mount, name)
      }
      obj.allow "*"

      ret = nil
      assert_nothing_raised do
        ret = server.list("/name", :manage, false, false, host, ip)
      end

      assert_equal("/\tfile", ret)

      assert_nothing_raised do
        ret = server.describe("/name", :manage, host, ip)
      end
      assert(ret =~ /\tfile\t/, "Did not get valid a description (#{ret.inspect})")

      assert_nothing_raised do
        ret = server.retrieve("/name", :manage, host, ip)
      end

      assert_equal(ret, File.read(file))

      server.umount(name)

      File.unlink(file)
    end
  end

  # Test the default modules fileserving
  def test_modules_default
    moddir = tempfile
    Dir.mkdir(moddir)
    mounts = {}
    Puppet[:modulepath] = moddir

    mods = %w{green red}.collect do |name|
      path = File::join(moddir, name, Puppet::Module::FILES)
      FileUtils::mkdir_p(path)
      if name == "green"
        file = File::join(path, "test.txt")
        File::open(file, "w") { |f| f.print name }
      end

      Puppet::Module::find(name)
    end

    conffile = tempfile

    File.open(conffile, "w") { |f| f.puts "# a test config file" }

    # create a server with the file
    server = nil
    assert_nothing_raised {

      server = Puppet::Network::Handler::FileServer.new(

        :Local => false ,

        :Config => conffile
      )
    }

    mods.each do |mod|
      mount = "/#{mod.name}/"
      list = nil
      assert_nothing_raised {
        list = server.list(mount, :manage, true, false)
      }
      list = list.split("\n")
      if mod.name == "green"
        assert_equal(2, list.size)
        assert_equal("/\tdirectory", list[0])
        assert_equal("/test.txt\tfile", list[1])
      else
        assert_equal(1, list.size)
        assert_equal("/\tdirectory", list[0])
      end

      assert_nothing_raised("Host 'allow' denied #{mount}") {
        server.list(mount, :manage, true, false, 'allow.example.com', "192.168.0.1")
      }
    end
  end

  # Test that configuring deny/allow for modules works
  def test_modules_config
    moddir = tempfile
    Dir.mkdir(moddir)
    mounts = {}
    Puppet[:modulepath] = moddir

    path = File::join(moddir, "amod", Puppet::Module::FILES)
    file = File::join(path, "test.txt")
    FileUtils::mkdir_p(path)
    File::open(file, "w") { |f| f.print "Howdy" }

    mod = Puppet::Module::find("amod")

    conffile = tempfile
    @@tmpfiles << conffile

    File.open(conffile, "w") { |f|
      f.print "# a test config file
[modules]
  path #{basedir}/thing
  allow 192.168.0.*
"
  }

  # create a server with the file
  server = nil
  assert_nothing_raised {

    server = Puppet::Network::Handler::FileServer.new(

      :Local => false,

      :Config => conffile
      )
    }

    list = nil
    mount = "/#{mod.name}/"
    assert_nothing_raised {
      list = server.list(mount, :manage, true, false)
    }

    assert_nothing_raised {
      list.split("\n").each { |line|
        file, type = line.split("\t")
        server.describe(mount + file)
      }
    }

    assert_describe(mount, file, server)

    # now let's check that things are being correctly forbidden

      assert_raise(
        Puppet::AuthorizationError,

          "Host 'deny' allowed #{mount}") {
            server.list(mount, :manage, true, false, 'deny.example.com', "192.168.1.1")
    }
    assert_nothing_raised("Host 'allow' denied #{mount}") {
      server.list(mount, :manage, true, false, 'allow.example.com', "192.168.0.1")
    }
  end

  # Make sure we successfully throw errors -- someone ran into this with
  # 0.22.4.
  def test_failures
    # create a server with the file
    server = nil

    config = tempfile
    [
    "[this is invalid]\nallow one.two.com", # invalid name
    "[valid]\nallow *.testing something.com", # invalid allow
    "[valid]\nallow one.two.com\ndeny *.testing something.com", # invalid deny
    ].each do |failer|
      File.open(config, "w") { |f| f.puts failer }
      assert_raise(Puppet::Network::Handler::FileServerError, "Did not fail on #{failer.inspect}") {

        server = Puppet::Network::Handler::FileServer.new(

          :Local => false,

          :Config => config
        )
      }
    end
  end

  def test_can_start_without_configuration
    Puppet[:fileserverconfig] = tempfile
    assert_nothing_raised("Could not create fileserver when configuration is absent") do
      server = Puppet::Network::Handler::FileServer.new(
        :Local => false
        )
    end
  end

  def test_creates_default_mounts_when_no_configuration_is_available
    Puppet[:fileserverconfig] = tempfile
    server = Puppet::Network::Handler::FileServer.new(:Local => false)

    assert(server.mounted?("plugins"), "Did not create default plugins mount when missing configuration file")
    assert(server.mounted?("modules"), "Did not create default modules mount when missing configuration file")
  end
end


