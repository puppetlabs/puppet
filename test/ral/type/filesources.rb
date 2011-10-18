#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppettest/support/utils'
require 'cgi'
require 'fileutils'
require 'mocha'

class TestFileSources < Test::Unit::TestCase
  include PuppetTest::Support::Utils
  include PuppetTest::FileTesting
  def setup
    super
    if defined?(@port)
      @port += 1
    else
      @port = 12345
    end
    @file = Puppet::Type.type(:file)
    Puppet[:filetimeout] = -1
    Puppet::Util::SUIDManager.stubs(:asuser).yields
    Facter.stubs(:to_hash).returns({})
  end

  def teardown
    super
  end

  def use_storage
      initstorage
  rescue
      system("rm -rf #{Puppet[:statefile]}")
  end

  def initstorage
    Puppet::Util::Storage.init
    Puppet::Util::Storage.load
  end

  # Make a simple recursive tree.
  def mk_sourcetree
    source = tempfile
    sourcefile = File.join(source, "file")
    Dir.mkdir source
    File.open(sourcefile, "w") { |f| f.puts "yay" }

    dest = tempfile
    destfile = File.join(dest, "file")
    return source, dest, sourcefile, destfile
  end

  def recursive_source_test(fromdir, todir)
    initstorage
    tofile = nil
    trans = nil


          tofile = Puppet::Type.type(:file).new(
                
      :path => todir,
      :recurse => true,
      :backup => false,
        
      :source => fromdir
    )
    catalog = mk_catalog(tofile)
    catalog.apply

    assert(FileTest.exists?(todir), "Created dir #{todir} does not exist")
  end

  def run_complex_sources(networked = false)
    path = tempfile

    # first create the source directory
    FileUtils.mkdir_p path

    # okay, let's create a directory structure
    fromdir = File.join(path,"fromdir")
    Dir.mkdir(fromdir)
    FileUtils.cd(fromdir) {
      File.open("one", "w") { |f| f.puts "onefile"}
      File.open("two", "w") { |f| f.puts "twofile"}
    }

    todir = File.join(path, "todir")
    source = fromdir
    source = "puppet://localhost/#{networked}#{fromdir}" if networked
    recursive_source_test(source, todir)

    [fromdir,todir, File.join(todir, "one"), File.join(todir, "two")]
  end

  def test_complex_sources_twice
    fromdir, todir, one, two = run_complex_sources
    assert_trees_equal(fromdir,todir)
    recursive_source_test(fromdir, todir)
    assert_trees_equal(fromdir,todir)
    # Now remove the whole tree and try it again.
    [one, two].each do |f| File.unlink(f) end
    Dir.rmdir(todir)
    recursive_source_test(fromdir, todir)
    assert_trees_equal(fromdir,todir)
  end

  def test_sources_with_deleted_destfiles
    fromdir, todir, one, two = run_complex_sources
    assert(FileTest.exists?(todir))

    # then delete a file
    File.unlink(two)

    # and run
    recursive_source_test(fromdir, todir)

    assert(FileTest.exists?(two), "Deleted file was not recopied")

    # and make sure they're still equal
    assert_trees_equal(fromdir,todir)
  end

  def test_sources_with_readonly_destfiles
    fromdir, todir, one, two = run_complex_sources
    assert(FileTest.exists?(todir))
    File.chmod(0600, one)
    recursive_source_test(fromdir, todir)

    # and make sure they're still equal
    assert_trees_equal(fromdir,todir)

    # Now try it with the directory being read-only
    File.chmod(0111, todir)
    recursive_source_test(fromdir, todir)

    # and make sure they're still equal
    assert_trees_equal(fromdir,todir)
  end

  def test_sources_with_modified_dest_files
    fromdir, todir, one, two = run_complex_sources

    assert(FileTest.exists?(todir))

    # Modify a dest file
    File.open(two, "w") { |f| f.puts "something else" }

    recursive_source_test(fromdir, todir)

    # and make sure they're still equal
    assert_trees_equal(fromdir,todir)
  end

  def test_sources_with_added_destfiles
    fromdir, todir = run_complex_sources
    assert(FileTest.exists?(todir))
    # and finally, add some new files
    add_random_files(todir)

    recursive_source_test(fromdir, todir)

    fromtree = file_list(fromdir)
    totree = file_list(todir)

    assert(fromtree != totree, "Trees are incorrectly equal")

    # then remove our new files
    FileUtils.cd(todir) {
      %x{find . 2>/dev/null}.chomp.split(/\n/).each { |file|
        if file =~ /file[0-9]+/
          FileUtils.rm_rf(file)
        end
      }
    }

    # and make sure they're still equal
    assert_trees_equal(fromdir,todir)
  end

  # Make sure added files get correctly caught during recursion
  def test_RecursionWithAddedFiles
    basedir = tempfile
    Dir.mkdir(basedir)
    @@tmpfiles << basedir
    file1 = File.join(basedir, "file1")
    file2 = File.join(basedir, "file2")
    subdir1 = File.join(basedir, "subdir1")
    file3 = File.join(subdir1, "file")
    File.open(file1, "w") { |f| f.puts "yay" }
    rootobj = nil
    assert_nothing_raised {

            rootobj = Puppet::Type.type(:file).new(
                
        :name => basedir,
        :recurse => true,
        :check => %w{type owner},
        
        :mode => 0755
      )
    }

    assert_apply(rootobj)
    assert_equal(0755, filemode(file1))

    File.open(file2, "w") { |f| f.puts "rah" }
    assert_apply(rootobj)
    assert_equal(0755, filemode(file2))

    Dir.mkdir(subdir1)
    File.open(file3, "w") { |f| f.puts "foo" }
    assert_apply(rootobj)
    assert_equal(0755, filemode(file3))
  end

  def mkfileserverconf(mounts)
    file = tempfile
    File.open(file, "w") { |f|
      mounts.each { |path, name|
        f.puts "[#{name}]\n\tpath #{path}\n\tallow *\n"
      }
    }

    @@tmpfiles << file
    file
  end

  def test_sourcepaths
    files = []
    3.times {
      files << tempfile
    }

    to = tempfile

    File.open(files[-1], "w") { |f| f.puts "yee-haw" }

    file = nil
    assert_nothing_raised {

            file = Puppet::Type.type(:file).new(
                
        :name => to,
        
        :source => files
      )
    }

    comp = mk_catalog(file)
    assert_events([:file_created], comp)

    assert(File.exists?(to), "File does not exist")

    txt = nil
    File.open(to) { |f| txt = f.read.chomp }

    assert_equal("yee-haw", txt, "Contents do not match")
  end

  # Make sure that source-copying updates the checksum on the same run
  def test_sourcebeatsensure
    source = tempfile
    dest = tempfile
    File.open(source, "w") { |f| f.puts "yay" }

    file = nil
    assert_nothing_raised {
      file = Puppet::Type.type(:file).new(
        :name => dest,
        :ensure => "file",
        :source => source
      )
    }

    file.retrieve

    assert_events([:file_created], file)
    file.retrieve
    assert_events([], file)
    assert_events([], file)
  end

  def test_sourcewithlinks
    source = tempfile
    link = tempfile
    dest = tempfile

    File.open(source, "w") { |f| f.puts "yay" }
    File.symlink(source, link)

    file = Puppet::Type.type(:file).new(:name => dest, :source => link)

    catalog = mk_catalog(file)

    # Default to managing links
    catalog.apply
    assert(FileTest.symlink?(dest), "Did not create link")

    # Now follow the links
    file[:links] = :follow
    catalog.apply
    assert(FileTest.file?(dest), "Destination is not a file")
  end

  # Make sure files aren't replaced when replace is false, but otherwise
  # are.
  def test_replace
    dest = tempfile

          file = Puppet::Type.newfile(
                
      :path => dest,
      :content => "foobar",
        
      :recurse => true
    )


    assert_apply(file)

    File.open(dest, "w") { |f| f.puts "yayness" }

    file[:replace] = false

    assert_apply(file)

    # Make sure it doesn't change.
    assert_equal("yayness\n", File.read(dest), "File got replaced when :replace was false")

    file[:replace] = true
    assert_apply(file)

    # Make sure it changes.
    assert_equal("foobar", File.read(dest), "File was not replaced when :replace was true")
  end

  def test_sourceselect
    dest = tempfile
    sources = []
    2.times { |i|
      i = i + 1
      source = tempfile
      sources << source
      file = File.join(source, "file#{i}")
      Dir.mkdir(source)
      File.open(file, "w") { |f| f.print "yay" }
    }
    file1 = File.join(dest, "file1")
    file2 = File.join(dest, "file2")
    file3 = File.join(dest, "file3")

    # Now make different files with the same name in each source dir
    sources.each_with_index do |source, i|
      File.open(File.join(source, "file3"), "w") { |f|
        f.print i.to_s
      }
    end


          obj = Puppet::Type.newfile(
        :path => dest, :recurse => true,
        
      :source => sources)

    assert_equal(:first, obj[:sourceselect], "sourceselect has the wrong default")
    # First, make sure we default to just copying file1
    assert_apply(obj)

    assert(FileTest.exists?(file1), "File from source 1 was not copied")
    assert(! FileTest.exists?(file2), "File from source 2 was copied")
    assert(FileTest.exists?(file3), "File from source 1 was not copied")
    assert_equal("0", File.read(file3), "file3 got wrong contents")

    # Now reset sourceselect
    assert_nothing_raised do
      obj[:sourceselect] = :all
    end
    File.unlink(file1)
    File.unlink(file3)
    Puppet.err :yay
    assert_apply(obj)

    assert(FileTest.exists?(file1), "File from source 1 was not copied")
    assert(FileTest.exists?(file2), "File from source 2 was copied")
    assert(FileTest.exists?(file3), "File from source 1 was not copied")
    assert_equal("0", File.read(file3), "file3 got wrong contents")
  end

  def test_recursive_sourceselect
    dest = tempfile
    source1 = tempfile
    source2 = tempfile
    files = []
    [source1, source2, File.join(source1, "subdir"), File.join(source2, "subdir")].each_with_index do |dir, i|
      Dir.mkdir(dir)
      # Make a single file in each directory
      file = File.join(dir, "file#{i}")
      File.open(file, "w") { |f| f.puts "yay#{i}"}

      # Now make a second one in each directory
      file = File.join(dir, "second-file#{i}")
      File.open(file, "w") { |f| f.puts "yaysecond-#{i}"}
      files << file
    end

    obj = Puppet::Type.newfile(:path => dest, :source => [source1, source2], :sourceselect => :all, :recurse => true)

    assert_apply(obj)

    ["file0", "file1", "second-file0", "second-file1", "subdir/file2", "subdir/second-file2", "subdir/file3", "subdir/second-file3"].each do |file|
      path = File.join(dest, file)
      assert(FileTest.exists?(path), "did not create #{file}")

      assert_equal("yay#{File.basename(file).sub("file", '')}\n", File.read(path), "file was not copied correctly")
    end
  end

  # #594
  def test_purging_missing_remote_files
    source = tempfile
    dest = tempfile
    s1 = File.join(source, "file1")
    s2 = File.join(source, "file2")
    d1 = File.join(dest, "file1")
    d2 = File.join(dest, "file2")
    Dir.mkdir(source)
    [s1, s2].each { |name| File.open(name, "w") { |file| file.puts "something" } }

    # We have to add a second parameter, because that's the only way to expose the "bug".
    file = Puppet::Type.newfile(:path => dest, :source => source, :recurse => true, :purge => true, :mode => "755")

    assert_apply(file)

    assert(FileTest.exists?(d1), "File1 was not copied")
    assert(FileTest.exists?(d2), "File2 was not copied")

    File.unlink(s2)

    assert_apply(file)

    assert(FileTest.exists?(d1), "File1 was not kept")
    assert(! FileTest.exists?(d2), "File2 was not purged")
  end
end

