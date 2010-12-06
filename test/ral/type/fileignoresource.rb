#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppettest/support/utils'
require 'cgi'
require 'fileutils'

class TestFileIgnoreSources < Test::Unit::TestCase
  include PuppetTest::Support::Utils
  include PuppetTest::FileTesting

  def setup
    super
    begin
      initstorage
    rescue
      system("rm -rf #{Puppet[:statefile]}")
    end

    Facter.stubs(:to_hash).returns({})
  end

#This is not needed unless using md5 (correct me if I'm wrong)
  def initstorage
    Puppet::Util::Storage.init
    Puppet::Util::Storage.load
  end

  def clearstorage
    Puppet::Util::Storage.store
    Puppet::Util::Storage.clear
  end

  def test_ignore_simple_source

    #Temp directory to run tests in
    path = tempfile
    @@tmpfiles.push path

    #source directory
    sourcedir = "sourcedir"
    sourcefile1 = "sourcefile1"
    sourcefile2 = "sourcefile2"

    frompath = File.join(path,sourcedir)
    FileUtils.mkdir_p frompath

    topath = File.join(path,"destdir")
    FileUtils.mkdir topath

    #initialize variables before block
    tofile = nil
    trans = nil

    #create source files


      File.open(
        File.join(frompath,sourcefile1),

      File::WRONLY|File::CREAT|File::APPEND) { |of|
        of.puts "yayness"
    }


      File.open(
        File.join(frompath,sourcefile2),

      File::WRONLY|File::CREAT|File::APPEND) { |of|
        of.puts "even yayer"
    }


    #makes Puppet file Object
    assert_nothing_raised {

      tofile = Puppet::Type.type(:file).new(

        :name => topath,
        :source => frompath,
        :recurse => true,

        :ignore => "sourcefile2"
      )
    }

    config = mk_catalog(tofile)
    config.apply


    #topath should exist as a directory with sourcedir as a directory

    #This file should exist
    assert(FileTest.exists?(File.join(topath,sourcefile1)))

    #This file should not
    assert(!(FileTest.exists?(File.join(topath,sourcefile2))))
  end

  def test_ignore_with_wildcard
    #Temp directory to run tests in
    path = tempfile
    @@tmpfiles.push path

    #source directory
    sourcedir = "sourcedir"
    subdir = "subdir"
    subdir2 = "subdir2"
    sourcefile1 = "sourcefile1"
    sourcefile2 = "sourcefile2"

    frompath = File.join(path,sourcedir)
    FileUtils.mkdir_p frompath

    FileUtils.mkdir_p(File.join(frompath, subdir))
    FileUtils.mkdir_p(File.join(frompath, subdir2))
    dir =  Dir.glob(File.join(path,"**/*"))

    topath = File.join(path,"destdir")
    FileUtils.mkdir topath

    #initialize variables before block
    tofile = nil
    trans = nil

    #create source files

    dir.each { |dir|

      File.open(
        File.join(dir,sourcefile1),

      File::WRONLY|File::CREAT|File::APPEND) { |of|
        of.puts "yayness"
      }


        File.open(
          File.join(dir,sourcefile2),

      File::WRONLY|File::CREAT|File::APPEND) { |of|
        of.puts "even yayer"
      }

    }

    #makes Puppet file Object
    assert_nothing_raised {

      tofile = Puppet::Type.type(:file).new(

        :name => topath,
        :source => frompath,
        :recurse => true,

        :ignore => "*2"
      )
    }

    config = mk_catalog(tofile)
    config.apply

    #topath should exist as a directory with sourcedir as a directory

    #This file should exist
    assert(FileTest.exists?(File.join(topath,sourcefile1)))
    assert(FileTest.exists?(File.join(topath,subdir)))
    assert(FileTest.exists?(File.join(File.join(topath,subdir),sourcefile1)))

    #This file should not
    assert(!(FileTest.exists?(File.join(topath,sourcefile2))))
    assert(!(FileTest.exists?(File.join(topath,subdir2))))
    assert(!(FileTest.exists?(File.join(File.join(topath,subdir),sourcefile2))))
  end

  def test_ignore_array
    #Temp directory to run tests in
    path = tempfile
    @@tmpfiles.push path

    #source directory
    sourcedir = "sourcedir"
    subdir = "subdir"
    subdir2 = "subdir2"
    subdir3 = "anotherdir"
    sourcefile1 = "sourcefile1"
    sourcefile2 = "sourcefile2"

    frompath = File.join(path,sourcedir)
    FileUtils.mkdir_p frompath

    FileUtils.mkdir_p(File.join(frompath, subdir))
    FileUtils.mkdir_p(File.join(frompath, subdir2))
    FileUtils.mkdir_p(File.join(frompath, subdir3))
    sourcedir =  Dir.glob(File.join(path,"**/*"))

    topath = File.join(path,"destdir")
    FileUtils.mkdir topath

    #initialize variables before block
    tofile = nil
    trans = nil

    #create source files



    sourcedir.each { |dir|

      File.open(
        File.join(dir,sourcefile1),

      File::WRONLY|File::CREAT|File::APPEND) { |of|
        of.puts "yayness"
      }


        File.open(
          File.join(dir,sourcefile2),

      File::WRONLY|File::CREAT|File::APPEND) { |of|
        of.puts "even yayer"
      }

    }


    #makes Puppet file Object
    assert_nothing_raised {

      tofile = Puppet::Type.type(:file).new(

        :name => topath,
        :source => frompath,
        :recurse => true,

        :ignore => ["*2", "an*"]
        # :ignore => ["*2", "an*", "nomatch"]
      )
    }

    config = mk_catalog(tofile)
    config.apply

    #topath should exist as a directory with sourcedir as a directory

    # This file should exist
    # proper files in destination
    assert(FileTest.exists?(File.join(topath,sourcefile1)), "file1 not in destdir")
    assert(FileTest.exists?(File.join(topath,subdir)), "subdir1 not in destdir")
    assert(FileTest.exists?(File.join(File.join(topath,subdir),sourcefile1)), "file1 not in subdir")
    # proper files in source
    assert(FileTest.exists?(File.join(frompath,subdir)), "subdir not in source")
    assert(FileTest.exists?(File.join(frompath,subdir2)), "subdir2 not in source")
    assert(FileTest.exists?(File.join(frompath,subdir3)), "subdir3 not in source")

    # This file should not
    assert(!(FileTest.exists?(File.join(topath,sourcefile2))), "file2 in dest")
    assert(!(FileTest.exists?(File.join(topath,subdir2))), "subdir2 in dest")
    assert(!(FileTest.exists?(File.join(topath,subdir3))), "anotherdir in dest")
    assert(!(FileTest.exists?(File.join(File.join(topath,subdir),sourcefile2))), "file2 in dest/sub")
  end
end
