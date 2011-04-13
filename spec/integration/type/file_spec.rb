#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet_spec/files'

describe Puppet::Type.type(:file) do
  include PuppetSpec::Files

  before do
    # stub this to not try to create state.yaml
    Puppet::Util::Storage.stubs(:store)
  end

  it "should not attempt to manage files that do not exist if no means of creating the file is specified" do
    file = Puppet::Type.type(:file).new :path => "/my/file", :mode => "755"
    catalog = Puppet::Resource::Catalog.new
    catalog.add_resource file

    file.parameter(:mode).expects(:retrieve).never

    transaction = Puppet::Transaction.new(catalog)
    transaction.resource_harness.evaluate(file).should_not be_failed
  end

  describe "when writing files" do
    it "should backup files to a filebucket when one is configured" do
      bucket = Puppet::Type.type(:filebucket).new :path => tmpfile("filebucket"), :name => "mybucket"
      file = Puppet::Type.type(:file).new :path => tmpfile("bucket_backs"), :backup => "mybucket", :content => "foo"
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource file
      catalog.add_resource bucket

      File.open(file[:path], "w") { |f| f.puts "bar" }

      md5 = Digest::MD5.hexdigest(File.read(file[:path]))

      catalog.apply

      bucket.bucket.getfile(md5).should == "bar\n"
    end

    it "should backup files in the local directory when a backup string is provided" do
      file = Puppet::Type.type(:file).new :path => tmpfile("bucket_backs"), :backup => ".bak", :content => "foo"
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource file

      File.open(file[:path], "w") { |f| f.puts "bar" }

      catalog.apply

      backup = file[:path] + ".bak"
      FileTest.should be_exist(backup)
      File.read(backup).should == "bar\n"
    end

    it "should fail if no backup can be performed" do
      dir = tmpfile("backups")
      Dir.mkdir(dir)
      path = File.join(dir, "testfile")
      file = Puppet::Type.type(:file).new :path => path, :backup => ".bak", :content => "foo"
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource file

      File.open(file[:path], "w") { |f| f.puts "bar" }

      # Create a directory where the backup should be so that writing to it fails
      Dir.mkdir(File.join(dir, "testfile.bak"))

      Puppet::Util::Log.stubs(:newmessage)

      catalog.apply

      File.read(file[:path]).should == "bar\n"
    end

    it "should not backup symlinks" do
      link = tmpfile("link")
      dest1 = tmpfile("dest1")
      dest2 = tmpfile("dest2")
      bucket = Puppet::Type.type(:filebucket).new :path => tmpfile("filebucket"), :name => "mybucket"
      file = Puppet::Type.type(:file).new :path => link, :target => dest2, :ensure => :link, :backup => "mybucket"
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource file
      catalog.add_resource bucket

      File.open(dest1, "w") { |f| f.puts "whatever" }
      File.symlink(dest1, link)

      md5 = Digest::MD5.hexdigest(File.read(file[:path]))

      catalog.apply

      File.readlink(link).should == dest2
      Find.find(bucket[:path]) { |f| File.file?(f) }.should be_nil
    end

    it "should backup directories to the local filesystem by copying the whole directory" do
      file = Puppet::Type.type(:file).new :path => tmpfile("bucket_backs"), :backup => ".bak", :content => "foo", :force => true
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource file

      Dir.mkdir(file[:path])
      otherfile = File.join(file[:path], "foo")
      File.open(otherfile, "w") { |f| f.print "yay" }

      catalog.apply

      backup = file[:path] + ".bak"
      FileTest.should be_directory(backup)
      File.read(File.join(backup, "foo")).should == "yay"
    end

    it "should backup directories to filebuckets by backing up each file separately" do
      bucket = Puppet::Type.type(:filebucket).new :path => tmpfile("filebucket"), :name => "mybucket"
      file = Puppet::Type.type(:file).new :path => tmpfile("bucket_backs"), :backup => "mybucket", :content => "foo", :force => true
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource file
      catalog.add_resource bucket

      Dir.mkdir(file[:path])
      foofile = File.join(file[:path], "foo")
      barfile = File.join(file[:path], "bar")
      File.open(foofile, "w") { |f| f.print "fooyay" }
      File.open(barfile, "w") { |f| f.print "baryay" }


      foomd5 = Digest::MD5.hexdigest(File.read(foofile))
      barmd5 = Digest::MD5.hexdigest(File.read(barfile))

      catalog.apply

      bucket.bucket.getfile(foomd5).should == "fooyay"
      bucket.bucket.getfile(barmd5).should == "baryay"
    end

    it "should propagate failures encountered when renaming the temporary file" do
      file = Puppet::Type.type(:file).new :path => tmpfile("fail_rename"), :content => "foo"
      file.stubs(:remove_existing) # because it tries to make a backup

      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource file

      File.open(file[:path], "w") { |f| f.print "bar" }

      File.expects(:rename).raises ArgumentError

      lambda { file.write(:content) }.should raise_error(Puppet::Error)
      File.read(file[:path]).should == "bar"
    end
  end

  describe "when recursing" do
    def build_path(dir)
      Dir.mkdir(dir)
      File.chmod(0750, dir)

      @dirs = [dir]
      @files = []

      %w{one two}.each do |subdir|
        fdir = File.join(dir, subdir)
        Dir.mkdir(fdir)
        File.chmod(0750, fdir)
        @dirs << fdir

        %w{three}.each do |file|
          ffile = File.join(fdir, file)
          @files << ffile
          File.open(ffile, "w") { |f| f.puts "test #{file}" }
          File.chmod(0640, ffile)
        end
      end
    end

    it "should be able to recurse over a nonexistent file" do
      @path = tmpfile("file_integration_tests")

      @file = Puppet::Type::File.new(
        :name    => @path,
        :mode    => 0644,
        :recurse => true,
        :backup  => false
      )

      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource @file

      lambda { @file.eval_generate }.should_not raise_error
    end

    it "should be able to recursively set properties on existing files" do
      @path = tmpfile("file_integration_tests")

      build_path(@path)

      @file = Puppet::Type::File.new(
        :name    => @path,
        :mode    => 0644,
        :recurse => true,
        :backup  => false
      )

      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource @file

      @catalog.apply

      @dirs.each do |path|
        (File.stat(path).mode & 007777).should == 0755
      end

      @files.each do |path|
        (File.stat(path).mode & 007777).should == 0644
      end
    end

    it "should be able to recursively make links to other files" do
      source = tmpfile("file_link_integration_source")

      build_path(source)

      dest = tmpfile("file_link_integration_dest")

      @file = Puppet::Type::File.new(:name => dest, :target => source, :recurse => true, :ensure => :link, :backup => false)

      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource @file

      @catalog.apply

      @dirs.each do |path|
        link_path = path.sub(source, dest)

        File.lstat(link_path).should be_directory
      end

      @files.each do |path|
        link_path = path.sub(source, dest)

        File.lstat(link_path).ftype.should == "link"
      end
    end

    it "should be able to recursively copy files" do
      source = tmpfile("file_source_integration_source")

      build_path(source)

      dest = tmpfile("file_source_integration_dest")

      @file = Puppet::Type::File.new(:name => dest, :source => source, :recurse => true, :backup => false)

      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource @file

      @catalog.apply

      @dirs.each do |path|
        newpath = path.sub(source, dest)

        File.lstat(newpath).should be_directory
      end

      @files.each do |path|
        newpath = path.sub(source, dest)

        File.lstat(newpath).ftype.should == "file"
      end
    end

    it "should not recursively manage files managed by a more specific explicit file" do
      dir = tmpfile("recursion_vs_explicit_1")

      subdir = File.join(dir, "subdir")
      file = File.join(subdir, "file")

      FileUtils.mkdir_p(subdir)
      File.open(file, "w") { |f| f.puts "" }

      base = Puppet::Type::File.new(:name => dir, :recurse => true, :backup => false, :mode => "755")
      sub = Puppet::Type::File.new(:name => subdir, :recurse => true, :backup => false, :mode => "644")

      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource base
      @catalog.add_resource sub

      @catalog.apply

      (File.stat(file).mode & 007777).should == 0644
    end

    it "should recursively manage files even if there is an explicit file whose name is a prefix of the managed file" do
      dir = tmpfile("recursion_vs_explicit_2")

      managed   = File.join(dir, "file")
      generated = File.join(dir, "file_with_a_name_starting_with_the_word_file")

      FileUtils.mkdir_p(dir)
      File.open(managed,   "w") { |f| f.puts "" }
      File.open(generated, "w") { |f| f.puts "" }

      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource Puppet::Type::File.new(:name => dir,     :recurse => true, :backup => false, :mode => "755")
      @catalog.add_resource Puppet::Type::File.new(:name => managed, :recurse => true, :backup => false, :mode => "644")

      @catalog.apply

      (File.stat(generated).mode & 007777).should == 0755
    end
  end

  describe "when generating resources" do
    before do
      @source = tmpfile("generating_in_catalog_source")

      @dest = tmpfile("generating_in_catalog_dest")

      Dir.mkdir(@source)

      s1 = File.join(@source, "one")
      s2 = File.join(@source, "two")

      File.open(s1, "w") { |f| f.puts "uno" }
      File.open(s2, "w") { |f| f.puts "dos" }

      @file = Puppet::Type::File.new(:name => @dest, :source => @source, :recurse => true, :backup => false)

      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource @file
    end

    it "should add each generated resource to the catalog" do
      @catalog.apply do |trans|
        @catalog.resource(:file, File.join(@dest, "one")).should be_instance_of(@file.class)
        @catalog.resource(:file, File.join(@dest, "two")).should be_instance_of(@file.class)
      end
    end

    it "should have an edge to each resource in the relationship graph" do
      @catalog.apply do |trans|
        one = @catalog.resource(:file, File.join(@dest, "one"))
        @catalog.relationship_graph.edge?(@file, one).should be

        two = @catalog.resource(:file, File.join(@dest, "two"))
        @catalog.relationship_graph.edge?(@file, two).should be
      end
    end
  end

  describe "when copying files" do
    # Ticket #285.
    it "should be able to copy files with pound signs in their names" do
      source = tmpfile("filewith#signs")

      dest = tmpfile("destwith#signs")

      File.open(source, "w") { |f| f.print "foo" }

      file = Puppet::Type::File.new(:name => dest, :source => source)

      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource file

      catalog.apply

      File.read(dest).should == "foo"
    end

    it "should be able to copy files with spaces in their names" do
      source = tmpfile("filewith spaces")

      dest = tmpfile("destwith spaces")

      File.open(source, "w") { |f| f.print "foo" }
      File.chmod(0755, source)

      file = Puppet::Type::File.new(:path => dest, :source => source)

      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource file

      catalog.apply

      File.read(dest).should == "foo"
      (File.stat(dest).mode & 007777).should == 0755
    end

    it "should be able to copy individual files even if recurse has been specified" do
      source = tmpfile("source")
      dest = tmpfile("dest")

      File.open(source, "w") { |f| f.print "foo" }

      file = Puppet::Type::File.new(:name => dest, :source => source, :recurse => true)

      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource file
      catalog.apply

      File.read(dest).should == "foo"
    end
  end

  it "should be able to create files when 'content' is specified but 'ensure' is not" do
    dest = tmpfile("files_with_content")


    file = Puppet::Type.type(:file).new(
      :name    => dest,
      :content => "this is some content, yo"
    )

    catalog = Puppet::Resource::Catalog.new
    catalog.add_resource file
    catalog.apply

    File.read(dest).should == "this is some content, yo"
  end

  it "should create files with content if both 'content' and 'ensure' are set" do
    dest = tmpfile("files_with_content")


    file = Puppet::Type.type(:file).new(
      :name    => dest,
      :ensure  => "file",
      :content => "this is some content, yo"
    )

    catalog = Puppet::Resource::Catalog.new
    catalog.add_resource file
    catalog.apply

    File.read(dest).should == "this is some content, yo"
  end

  it "should delete files with sources but that are set for deletion" do
    dest = tmpfile("dest_source_with_ensure")
    source = tmpfile("source_source_with_ensure")
    File.open(source, "w") { |f| f.puts "yay" }
    File.open(dest, "w") { |f| f.puts "boo" }


    file = Puppet::Type.type(:file).new(
      :name   => dest,
      :ensure => :absent,
      :source => source,
      :backup => false
    )

    catalog = Puppet::Resource::Catalog.new
    catalog.add_resource file
    catalog.apply

    File.should_not be_exist(dest)
  end

  describe "when purging files" do
    before do
      @sourcedir = tmpfile("purge_source")
      @destdir = tmpfile("purge_dest")
      Dir.mkdir(@sourcedir)
      Dir.mkdir(@destdir)
      @sourcefile = File.join(@sourcedir, "sourcefile")
      @copiedfile = File.join(@destdir, "sourcefile")
      @localfile = File.join(@destdir, "localfile")
      @purgee = File.join(@destdir, "to_be_purged")
      File.open(@localfile, "w") { |f| f.puts "rahtest" }
      File.open(@sourcefile, "w") { |f| f.puts "funtest" }
      # this file should get removed
      File.open(@purgee, "w") { |f| f.puts "footest" }


      @lfobj = Puppet::Type.newfile(
        :title   => "localfile",
        :path    => @localfile,
        :content => "rahtest\n",
        :ensure  => :file,
        :backup  => false
      )


      @destobj = Puppet::Type.newfile(
        :title   => "destdir",
        :path    => @destdir,
        :source  => @sourcedir,
        :backup  => false,
        :purge   => true,
        :recurse => true
      )

      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource @lfobj, @destobj
    end

    it "should still copy remote files" do
      @catalog.apply
      FileTest.should be_exist(@copiedfile)
    end

    it "should not purge managed, local files" do
      @catalog.apply
      FileTest.should be_exist(@localfile)
    end

    it "should purge files that are neither remote nor otherwise managed" do
      @catalog.apply
      FileTest.should_not be_exist(@purgee)
    end
  end
end
