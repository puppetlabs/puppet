#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet_spec/files'

if Puppet.features.microsoft_windows?
  require 'puppet/util/windows'
  class WindowsSecurity
    extend Puppet::Util::Windows::Security
  end
end

describe Puppet::Type.type(:file) do
  include PuppetSpec::Files

  let(:catalog) { Puppet::Resource::Catalog.new }
  let(:path) do
    # we create a directory first so backups of :path that are stored in
    # the same directory will also be removed after the tests
    parent = tmpdir('file_spec')
    File.join(parent, 'file_testing')
  end

  if Puppet.features.posix?
    def set_mode(mode, file)
      File.chmod(mode, file)
    end

    def get_mode(file)
      File.lstat(file).mode
    end

    def get_owner(file)
      File.lstat(file).uid
    end

    def get_group(file)
      File.lstat(file).gid
    end
  else
    class SecurityHelper
      extend Puppet::Util::Windows::Security
    end

    def set_mode(mode, file)
      SecurityHelper.set_mode(mode, file)
    end

    def get_mode(file)
      SecurityHelper.get_mode(file)
    end

    def get_owner(file)
      SecurityHelper.get_owner(file)
    end

    def get_group(file)
      SecurityHelper.get_group(file)
    end
  end

  before do
    # stub this to not try to create state.yaml
    Puppet::Util::Storage.stubs(:store)
  end

  it "should not attempt to manage files that do not exist if no means of creating the file is specified" do
    source = tmpfile('source')

    catalog.add_resource described_class.new :path => source, :mode => 0755

    status = catalog.apply.report.resource_statuses["File[#{source}]"]
    status.should_not be_failed
    status.should_not be_changed
    File.should_not be_exist(source)
  end

  describe "when ensure is absent" do
    it "should remove the file if present" do
      FileUtils.touch(path)
      catalog.add_resource(described_class.new(:path => path, :ensure => :absent, :backup => :false))
      report = catalog.apply.report
      report.resource_statuses["File[#{path}]"].should_not be_failed
      File.should_not be_exist(path)
    end

    it "should do nothing if file is not present" do
      catalog.add_resource(described_class.new(:path => path, :ensure => :absent, :backup => :false))
      report = catalog.apply.report
      report.resource_statuses["File[#{path}]"].should_not be_failed
      File.should_not be_exist(path)
    end

    # issue #14599
    it "should not fail if parts of path aren't directories" do
      FileUtils.touch(path)
      catalog.add_resource(described_class.new(:path => File.join(path,'no_such_file'), :ensure => :absent, :backup => :false))
      report = catalog.apply.report
      report.resource_statuses["File[#{File.join(path,'no_such_file')}]"].should_not be_failed
    end
  end

  describe "when setting permissions" do
    it "should set the owner" do
      target = tmpfile_with_contents('target', '')
      owner = get_owner(target)

      catalog.add_resource described_class.new(
        :name    => target,
        :owner   => owner
      )

      catalog.apply

      get_owner(target).should == owner
    end

    it "should set the group" do
      target = tmpfile_with_contents('target', '')
      group = get_group(target)

      catalog.add_resource described_class.new(
        :name    => target,
        :group   => group
      )

      catalog.apply

      get_group(target).should == group
    end

    describe "when setting mode" do
      describe "for directories" do
        let(:target) { tmpdir('dir_mode') }

        it "should set executable bits for newly created directories" do
          catalog.add_resource described_class.new(:path => target, :ensure => :directory, :mode => 0600)

          catalog.apply

          (get_mode(target) & 07777).should == 0700
        end

        it "should set executable bits for existing readable directories" do
          set_mode(0600, target)

          catalog.add_resource described_class.new(:path => target, :ensure => :directory, :mode => 0644)
          catalog.apply

          (get_mode(target) & 07777).should == 0755
        end

        it "should not set executable bits for unreadable directories" do
          begin
            catalog.add_resource described_class.new(:path => target, :ensure => :directory, :mode => 0300)

            catalog.apply

            (get_mode(target) & 07777).should == 0300
          ensure
            # so we can cleanup
            set_mode(0700, target)
          end
        end

        it "should set user, group, and other executable bits" do
          catalog.add_resource described_class.new(:path => target, :ensure => :directory, :mode => 0664)

          catalog.apply

          (get_mode(target) & 07777).should == 0775
        end

        it "should set executable bits when overwriting a non-executable file" do
          target_path = tmpfile_with_contents('executable', '')
          set_mode(0444, target_path)

          catalog.add_resource described_class.new(:path => target_path, :ensure => :directory, :mode => 0666, :backup => false)
          catalog.apply

          (get_mode(target_path) & 07777).should == 0777
          File.should be_directory(target_path)
        end
      end

      describe "for files" do
        it "should not set executable bits" do
          catalog.add_resource described_class.new(:path => path, :ensure => :file, :mode => 0666)
          catalog.apply

          (get_mode(path) & 07777).should == 0666
        end

        it "should not set executable bits when replacing an executable directory (#10365)" do
          pending("bug #10365")

          FileUtils.mkdir(path)
          set_mode(0777, path)

          catalog.add_resource described_class.new(:path => path, :ensure => :file, :mode => 0666, :backup => false, :force => true)
          catalog.apply

          (get_mode(path) & 07777).should == 0666
        end
      end

      describe "for links", :unless => Puppet.features.microsoft_windows? do
        let(:link) { tmpfile('link_mode') }

        describe "when managing links" do
          let(:link_target) { tmpfile('target') }

          before :each do
            FileUtils.touch(link_target)
            File.chmod(0444, link_target)

            File.symlink(link_target, link)
          end

          it "should not set the executable bit on the link nor the target" do
            catalog.add_resource described_class.new(:path => link, :ensure => :link, :mode => 0666, :target => link_target, :links => :manage)

            catalog.apply

            (File.stat(link).mode & 07777) == 0666
            (File.lstat(link_target).mode & 07777) == 0444
          end

          it "should ignore dangling symlinks (#6856)" do
            File.delete(link_target)

            catalog.add_resource described_class.new(:path => link, :ensure => :link, :mode => 0666, :target => link_target, :links => :manage)
            catalog.apply

            File.should_not be_exist(link)
          end

          it "should create a link to the target if ensure is omitted" do
            FileUtils.touch(link_target)
            catalog.add_resource described_class.new(:path => link, :target => link_target)
            catalog.apply

            File.should be_exist link
            File.lstat(link).ftype.should == 'link'
            File.readlink(link).should == link_target
          end
        end

        describe "when following links" do
          it "should ignore dangling symlinks (#6856)" do
            target = tmpfile('dangling')

            FileUtils.touch(target)
            File.symlink(target, link)
            File.delete(target)

            catalog.add_resource described_class.new(:path => path, :source => link, :mode => 0600, :links => :follow)
            catalog.apply
          end

          describe "to a directory" do
            let(:link_target) { tmpdir('dir_target') }

            before :each do
              File.chmod(0600, link_target)

              File.symlink(link_target, link)
            end

            after :each do
              File.chmod(0750, link_target)
            end

            describe "that is readable" do
              it "should set the executable bits when creating the destination (#10315)" do
                catalog.add_resource described_class.new(:path => path, :source => link, :mode => 0666, :links => :follow)
                catalog.apply

                File.should be_directory(path)
                (get_mode(path) & 07777).should == 0777
              end

              it "should set the executable bits when overwriting the destination (#10315)" do
                FileUtils.touch(path)

                catalog.add_resource described_class.new(:path => path, :source => link, :mode => 0666, :links => :follow, :backup => false)
                catalog.apply

                File.should be_directory(path)
                (get_mode(path) & 07777).should == 0777
              end
            end

            describe "that is not readable" do
              before :each do
                set_mode(0300, link_target)
              end

              # so we can cleanup
              after :each do
                set_mode(0700, link_target)
              end

              it "should set executable bits when creating the destination (#10315)" do
                catalog.add_resource described_class.new(:path => path, :source => link, :mode => 0666, :links => :follow)
                catalog.apply

                File.should be_directory(path)
                (get_mode(path) & 07777).should == 0777
              end

              it "should set executable bits when overwriting the destination" do
                FileUtils.touch(path)

                catalog.add_resource described_class.new(:path => path, :source => link, :mode => 0666, :links => :follow, :backup => false)
                catalog.apply

                File.should be_directory(path)
                (get_mode(path) & 07777).should == 0777
              end
            end
          end

          describe "to a file" do
            let(:link_target) { tmpfile('file_target') }

            before :each do
              FileUtils.touch(link_target)

              File.symlink(link_target, link)
            end

            it "should create the file, not a symlink (#2817, #10315)" do
              catalog.add_resource described_class.new(:path => path, :source => link, :mode => 0600, :links => :follow)
              catalog.apply

              File.should be_file(path)
              (get_mode(path) & 07777).should == 0600
            end

            it "should overwrite the file" do
              FileUtils.touch(path)

              catalog.add_resource described_class.new(:path => path, :source => link, :mode => 0600, :links => :follow)
              catalog.apply

              File.should be_file(path)
              (get_mode(path) & 07777).should == 0600
            end
          end

          describe "to a link to a directory" do
            let(:real_target) { tmpdir('real_target') }
            let(:target) { tmpfile('target') }

            before :each do
              File.chmod(0666, real_target)

              # link -> target -> real_target
              File.symlink(real_target, target)
              File.symlink(target, link)
            end

            after :each do
              File.chmod(0750, real_target)
            end

            describe "when following all links" do
              it "should create the destination and apply executable bits (#10315)" do
                catalog.add_resource described_class.new(:path => path, :source => link, :mode => 0600, :links => :follow)
                catalog.apply

                File.should be_directory(path)
                (get_mode(path) & 07777).should == 0700
              end

              it "should overwrite the destination and apply executable bits" do
                FileUtils.mkdir(path)

                catalog.add_resource described_class.new(:path => path, :source => link, :mode => 0600, :links => :follow)
                catalog.apply

                File.should be_directory(path)
                (get_mode(path) & 0111).should == 0100
              end
            end
          end
        end
      end
    end
  end

  describe "when writing files" do
    it "should backup files to a filebucket when one is configured" do
      filebucket = Puppet::Type.type(:filebucket).new :path => tmpfile("filebucket"), :name => "mybucket"
      file = described_class.new :path => path, :backup => "mybucket", :content => "foo"
      catalog.add_resource file
      catalog.add_resource filebucket

      File.open(file[:path], "wb") { |f| f.puts "bar" }

      md5 = Digest::MD5.hexdigest(IO.binread(file[:path]))

      catalog.apply

      filebucket.bucket.getfile(md5).should == "bar\n"
    end

    it "should backup files in the local directory when a backup string is provided" do
      file = described_class.new :path => path, :backup => ".bak", :content => "foo"
      catalog.add_resource file

      File.open(file[:path], "w") { |f| f.puts "bar" }

      catalog.apply

      backup = file[:path] + ".bak"
      FileTest.should be_exist(backup)
      File.read(backup).should == "bar\n"
    end

    it "should fail if no backup can be performed" do
      dir = tmpdir("backups")

      file = described_class.new :path => File.join(dir, "testfile"), :backup => ".bak", :content => "foo"
      catalog.add_resource file

      File.open(file[:path], 'w') { |f| f.puts "bar" }

      # Create a directory where the backup should be so that writing to it fails
      Dir.mkdir(File.join(dir, "testfile.bak"))

      Puppet::Util::Log.stubs(:newmessage)

      catalog.apply

      File.read(file[:path]).should == "bar\n"
    end

    it "should not backup symlinks", :unless => Puppet.features.microsoft_windows? do
      link = tmpfile("link")
      dest1 = tmpfile("dest1")
      dest2 = tmpfile("dest2")
      bucket = Puppet::Type.type(:filebucket).new :path => tmpfile("filebucket"), :name => "mybucket"
      file = described_class.new :path => link, :target => dest2, :ensure => :link, :backup => "mybucket"
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
      file = described_class.new :path => path, :backup => ".bak", :content => "foo", :force => true
      catalog.add_resource file

      Dir.mkdir(path)

      otherfile = File.join(path, "foo")
      File.open(otherfile, "w") { |f| f.print "yay" }

      catalog.apply

      backup = "#{path}.bak"
      FileTest.should be_directory(backup)

      File.read(File.join(backup, "foo")).should == "yay"
    end

    it "should backup directories to filebuckets by backing up each file separately" do
      bucket = Puppet::Type.type(:filebucket).new :path => tmpfile("filebucket"), :name => "mybucket"
      file = described_class.new :path => tmpfile("bucket_backs"), :backup => "mybucket", :content => "foo", :force => true
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
      file = described_class.new :path => path, :content => "foo"
      file.stubs(:perform_backup).returns(true)

      catalog.add_resource file

      File.open(path, "w") { |f| f.print "bar" }

      File.expects(:rename).raises ArgumentError

      expect { file.write(:content) }.to raise_error(Puppet::Error, /Could not rename temporary file/)
      File.read(path).should == "bar"
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
      @file = described_class.new(
        :name    => path,
        :mode    => 0644,
        :recurse => true,
        :backup  => false
      )

      catalog.add_resource @file

      lambda { @file.eval_generate }.should_not raise_error
    end

    it "should be able to recursively set properties on existing files" do
      path = tmpfile("file_integration_tests")

      build_path(path)

      file = described_class.new(
        :name    => path,
        :mode    => 0644,
        :recurse => true,
        :backup  => false
      )

      catalog.add_resource file

      catalog.apply

      @dirs.should_not be_empty
      @dirs.each do |path|
        (get_mode(path) & 007777).should == 0755
      end

      @files.should_not be_empty
      @files.each do |path|
        (get_mode(path) & 007777).should == 0644
      end
    end

    it "should be able to recursively make links to other files", :unless => Puppet.features.microsoft_windows? do
      source = tmpfile("file_link_integration_source")

      build_path(source)

      dest = tmpfile("file_link_integration_dest")

      @file = described_class.new(:name => dest, :target => source, :recurse => true, :ensure => :link, :backup => false)

      catalog.add_resource @file

      catalog.apply

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

      @file = described_class.new(:name => dest, :source => source, :recurse => true, :backup => false)

      catalog.add_resource @file

      catalog.apply

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

      base = described_class.new(:name => dir, :recurse => true, :backup => false, :mode => "755")
      sub = described_class.new(:name => subdir, :recurse => true, :backup => false, :mode => "644")

      catalog.add_resource base
      catalog.add_resource sub

      catalog.apply

      (get_mode(file) & 007777).should == 0644
    end

    it "should recursively manage files even if there is an explicit file whose name is a prefix of the managed file" do
      managed      = File.join(path, "file")
      generated    = File.join(path, "file_with_a_name_starting_with_the_word_file")
      managed_mode = 0700

      FileUtils.mkdir_p(path)
      FileUtils.touch(managed)
      FileUtils.touch(generated)

      catalog.add_resource described_class.new(:name => path,    :recurse => true, :backup => false, :mode => managed_mode)
      catalog.add_resource described_class.new(:name => managed, :recurse => true, :backup => false, :mode => "644")

      catalog.apply

      (get_mode(generated) & 007777).should == managed_mode
    end

    describe "when recursing remote directories" do
      describe "when sourceselect first" do
        describe "for a directory" do
          it "should recursively copy the first directory that exists" do
            one = File.expand_path('thisdoesnotexist')
            two = tmpdir('two')

            FileUtils.mkdir_p(File.join(two, 'three'))
            FileUtils.touch(File.join(two, 'three', 'four'))

            catalog.add_resource Puppet::Type.newfile(
                               :path    => path,
                               :ensure  => :directory,
                               :backup  => false,
                               :recurse => true,
                               :sourceselect => :first,
                               :source => [one, two]
                               )

            catalog.apply

            File.should be_directory(path)
            File.should_not be_exist(File.join(path, 'one'))
            File.should be_exist(File.join(path, 'three', 'four'))
          end

          it "should recursively copy an empty directory" do
            one = File.expand_path('thisdoesnotexist')
            two = tmpdir('two')
            three = tmpdir('three')
            file_in_dir_with_contents(three, 'a', '')

            catalog.add_resource Puppet::Type.newfile(
                               :path    => path,
                               :ensure  => :directory,
                               :backup  => false,
                               :recurse => true,
                               :sourceselect => :first,
                               :source => [one, two, three]
                               )

            catalog.apply

            File.should be_directory(path)
            File.should_not be_exist(File.join(path, 'a'))
          end

          it "should only recurse one level" do
            one = tmpdir('one')
            FileUtils.mkdir_p(File.join(one, 'a', 'b'))
            FileUtils.touch(File.join(one, 'a', 'b', 'c'))

            two = tmpdir('two')
            FileUtils.mkdir_p(File.join(two, 'z'))
            FileUtils.touch(File.join(two, 'z', 'y'))

            catalog.add_resource Puppet::Type.newfile(
                               :path    => path,
                               :ensure  => :directory,
                               :backup  => false,
                               :recurse => true,
                               :recurselimit => 1,
                               :sourceselect => :first,
                               :source => [one, two]
                               )

            catalog.apply

            File.should be_exist(File.join(path, 'a'))
            File.should_not be_exist(File.join(path, 'a', 'b'))
            File.should_not be_exist(File.join(path, 'z'))
          end
        end

        describe "for a file" do
          it "should copy the first file that exists" do
            one = File.expand_path('thisdoesnotexist')
            two = tmpfile_with_contents('two', 'yay')
            three = tmpfile_with_contents('three', 'no')

            catalog.add_resource Puppet::Type.newfile(
                               :path    => path,
                               :ensure  => :file,
                               :backup  => false,
                               :sourceselect => :first,
                               :source => [one, two, three]
                               )

            catalog.apply

            File.read(path).should == 'yay'
          end

          it "should copy an empty file" do
            one = File.expand_path('thisdoesnotexist')
            two = tmpfile_with_contents('two', '')
            three = tmpfile_with_contents('three', 'no')

            catalog.add_resource Puppet::Type.newfile(
                               :path    => path,
                               :ensure  => :file,
                               :backup  => false,
                               :sourceselect => :first,
                               :source => [one, two, three]
                               )

            catalog.apply

            File.read(path).should == ''
          end
        end
      end

      describe "when sourceselect all" do
        describe "for a directory" do
          it "should recursively copy all sources from the first valid source" do
            dest = tmpdir('dest')
            one = tmpdir('one')
            two = tmpdir('two')
            three = tmpdir('three')
            four = tmpdir('four')

            file_in_dir_with_contents(one, 'a', one)
            file_in_dir_with_contents(two, 'a', two)
            file_in_dir_with_contents(two, 'b', two)
            file_in_dir_with_contents(three, 'a', three)
            file_in_dir_with_contents(three, 'c', three)

            obj = Puppet::Type.newfile(
                               :path    => dest,
                               :ensure  => :directory,
                               :backup  => false,
                               :recurse => true,
                               :sourceselect => :all,
                               :source => [one, two, three, four]
                               )

            catalog.add_resource obj
            catalog.apply

            File.read(File.join(dest, 'a')).should == one
            File.read(File.join(dest, 'b')).should == two
            File.read(File.join(dest, 'c')).should == three
          end

          it "should only recurse one level from each valid source" do
            one = tmpdir('one')
            FileUtils.mkdir_p(File.join(one, 'a', 'b'))
            FileUtils.touch(File.join(one, 'a', 'b', 'c'))

            two = tmpdir('two')
            FileUtils.mkdir_p(File.join(two, 'z'))
            FileUtils.touch(File.join(two, 'z', 'y'))

            obj = Puppet::Type.newfile(
                               :path    => path,
                               :ensure  => :directory,
                               :backup  => false,
                               :recurse => true,
                               :recurselimit => 1,
                               :sourceselect => :all,
                               :source => [one, two]
                               )

            catalog.add_resource obj
            catalog.apply

            File.should be_exist(File.join(path, 'a'))
            File.should_not be_exist(File.join(path, 'a', 'b'))
            File.should be_exist(File.join(path, 'z'))
            File.should_not be_exist(File.join(path, 'z', 'y'))
          end
        end
      end
    end
  end

  describe "when generating resources" do
    before do
      source = tmpdir("generating_in_catalog_source")

      s1 = file_in_dir_with_contents(source, "one", "uno")
      s2 = file_in_dir_with_contents(source, "two", "dos")

      @file = described_class.new(
        :name => path,
        :source => source,
        :recurse => true,
        :backup => false
      )

      catalog.add_resource @file
    end

    it "should add each generated resource to the catalog" do
      catalog.apply do |trans|
        catalog.resource(:file, File.join(path, "one")).must be_a(described_class)
        catalog.resource(:file, File.join(path, "two")).must be_a(described_class)
      end
    end

    it "should have an edge to each resource in the relationship graph" do
      catalog.apply do |trans|
        one = catalog.resource(:file, File.join(path, "one"))
        catalog.relationship_graph.should be_edge(@file, one)

        two = catalog.resource(:file, File.join(path, "two"))
        catalog.relationship_graph.should be_edge(@file, two)
      end
    end
  end

  describe "when copying files" do
    it "should be able to copy files with pound signs in their names (#285)" do
      source = tmpfile_with_contents("filewith#signs", "foo")
      dest = tmpfile("destwith#signs")
      catalog.add_resource described_class.new(:name => dest, :source => source)

      catalog.apply

      File.read(dest).should == "foo"
    end

    it "should be able to copy files with spaces in their names" do
      dest = tmpfile("destwith spaces")
      source = tmpfile_with_contents("filewith spaces", "foo")
      File.chmod(0755, source)

      catalog.add_resource described_class.new(:path => dest, :source => source)

      catalog.apply

      expected_mode = Puppet.features.microsoft_windows? ? 0644 : 0755
      File.read(dest).should == "foo"
      (File.stat(dest).mode & 007777).should == expected_mode
    end

    it "should be able to copy individual files even if recurse has been specified" do
      source = tmpfile_with_contents("source", "foo")
      dest = tmpfile("dest")
      catalog.add_resource described_class.new(:name => dest, :source => source, :recurse => true)

      catalog.apply

      File.read(dest).should == "foo"
    end
  end

  it "should create a file with content if ensure is omitted" do
    catalog.add_resource described_class.new(
      :path => path,
      :content => "this is some content, yo"
    )

    catalog.apply

    File.read(path).should == "this is some content, yo"
  end

  it "should create files with content if both content and ensure are set" do
    file = described_class.new(
      :path    => path,
      :ensure  => "file",
      :content => "this is some content, yo"
    )

    catalog.add_resource file
    catalog.apply

    File.read(path).should == "this is some content, yo"
  end

  it "should delete files with sources but that are set for deletion" do
    source = tmpfile_with_contents("source_source_with_ensure", "yay")
    dest = tmpfile_with_contents("source_source_with_ensure", "boo")

    file = described_class.new(
      :path   => dest,
      :ensure => :absent,
      :source => source,
      :backup => false
    )

    catalog.add_resource file
    catalog.apply

    File.should_not be_exist(dest)
  end

  describe "when sourcing" do
    let(:source) { tmpfile_with_contents("source_default_values", "yay") }

    it "should apply the source metadata values" do
      set_mode(0770, source)

      file = described_class.new(
        :path   => path,
        :ensure => :file,
        :source => source,
        :backup => false
      )

      catalog.add_resource file
      catalog.apply

      get_owner(path).should == get_owner(source)
      get_group(path).should == get_group(source)
      (get_mode(path) & 07777).should == 0770
    end

    it "should override the default metadata values" do
      set_mode(0770, source)

      file = described_class.new(
         :path   => path,
         :ensure => :file,
         :source => source,
         :backup => false,
         :mode => 0440
       )

      catalog.add_resource file
      catalog.apply

      (get_mode(path) & 07777).should == 0440
    end

    describe "on Windows systems", :if => Puppet.features.microsoft_windows? do
      it "should provide valid default values when ACLs are not supported" do
        Puppet::Util::Windows::Security.stubs(:supports_acl?).with(source).returns false

        file = described_class.new(
          :path   => path,
          :ensure => :file,
          :source => source,
          :backup => false
        )

        catalog.add_resource file
        catalog.apply

        get_owner(path).should == 'S-1-5-32-544'
        get_group(path).should == 'S-1-0-0'
        get_mode(path).should == 0644
      end
    end
  end

  describe "when purging files" do
    before do
      sourcedir = tmpdir("purge_source")
      destdir = tmpdir("purge_dest")
      sourcefile = File.join(sourcedir, "sourcefile")

      @copiedfile = File.join(destdir, "sourcefile")
      @localfile  = File.join(destdir, "localfile")
      @purgee     = File.join(destdir, "to_be_purged")

      File.open(@localfile, "w") { |f| f.print "oldtest" }
      File.open(sourcefile, "w") { |f| f.print "funtest" }
      # this file should get removed
      File.open(@purgee, "w") { |f| f.print "footest" }

      lfobj = Puppet::Type.newfile(
        :title   => "localfile",
        :path    => @localfile,
        :content => "rahtest",
        :ensure  => :file,
        :backup  => false
      )

      destobj = Puppet::Type.newfile(
        :title   => "destdir",
        :path    => destdir,
        :source  => sourcedir,
        :backup  => false,
        :purge   => true,
        :recurse => true
      )

      catalog.add_resource lfobj, destobj
      catalog.apply
    end

    it "should still copy remote files" do
      File.read(@copiedfile).should == 'funtest'
    end

    it "should not purge managed, local files" do
      File.read(@localfile).should == 'rahtest'
    end

    it "should purge files that are neither remote nor otherwise managed" do
      FileTest.should_not be_exist(@purgee)
    end
  end

  def tmpfile_with_contents(name, contents)
    file = tmpfile(name)
    File.open(file, "w") { |f| f.write contents }
    file
  end

  def file_in_dir_with_contents(dir, name, contents)
    full_name = File.join(dir, name)
    File.open(full_name, "w") { |f| f.write contents }
    full_name
  end
end
