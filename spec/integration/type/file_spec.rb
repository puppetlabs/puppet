#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet_spec/files'

if Puppet.features.microsoft_windows?
  require 'puppet/util/windows'
  class WindowsSecurity
    extend Puppet::Util::Windows::Security
  end
end

describe Puppet::Type.type(:file), :uses_checksums => true do
  include PuppetSpec::Files

  let(:catalog) { Puppet::Resource::Catalog.new }
  let(:path) do
    # we create a directory first so backups of :path that are stored in
    # the same directory will also be removed after the tests
    parent = tmpdir('file_spec')
    File.join(parent, 'file_testing')
  end

  let(:dir) do
    # we create a directory first so backups of :path that are stored in
    # the same directory will also be removed after the tests
    parent = tmpdir('file_spec')
    File.join(parent, 'dir_testing')
  end

  if Puppet.features.posix?
    def set_mode(mode, file)
      File.chmod(mode, file)
    end

    def get_mode(file)
      Puppet::FileSystem.lstat(file).mode
    end

    def get_owner(file)
      Puppet::FileSystem.lstat(file).uid
    end

    def get_group(file)
      Puppet::FileSystem.lstat(file).gid
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

    def get_aces_for_path_by_sid(path, sid)
      SecurityHelper.get_aces_for_path_by_sid(path, sid)
    end
  end

  before do
    # stub this to not try to create state.yaml
    Puppet::Util::Storage.stubs(:store)
  end

  it "should not attempt to manage files that do not exist if no means of creating the file is specified" do
    source = tmpfile('source')

    catalog.add_resource described_class.new :path => source, :mode => '0755'

    status = catalog.apply.report.resource_statuses["File[#{source}]"]
    status.should_not be_failed
    status.should_not be_changed
    Puppet::FileSystem.exist?(source).should be_false
  end

  describe "when ensure is absent" do
    it "should remove the file if present" do
      FileUtils.touch(path)
      catalog.add_resource(described_class.new(:path => path, :ensure => :absent, :backup => :false))
      report = catalog.apply.report
      report.resource_statuses["File[#{path}]"].should_not be_failed
      Puppet::FileSystem.exist?(path).should be_false
    end

    it "should do nothing if file is not present" do
      catalog.add_resource(described_class.new(:path => path, :ensure => :absent, :backup => :false))
      report = catalog.apply.report
      report.resource_statuses["File[#{path}]"].should_not be_failed
      Puppet::FileSystem.exist?(path).should be_false
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

          catalog.add_resource described_class.new(:path => target, :ensure => :directory, :mode => '0644')
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

      describe "for links", :if => described_class.defaultprovider.feature?(:manages_symlinks) do
        let(:link) { tmpfile('link_mode') }

        describe "when managing links" do
          let(:link_target) { tmpfile('target') }

          before :each do
            FileUtils.touch(link_target)
            File.chmod(0444, link_target)

            Puppet::FileSystem.symlink(link_target, link)
          end

          it "should not set the executable bit on the link nor the target" do
            catalog.add_resource described_class.new(:path => link, :ensure => :link, :mode => 0666, :target => link_target, :links => :manage)

            catalog.apply

            (Puppet::FileSystem.stat(link).mode & 07777) == 0666
            (Puppet::FileSystem.lstat(link_target).mode & 07777) == 0444
          end

          it "should ignore dangling symlinks (#6856)" do
            File.delete(link_target)

            catalog.add_resource described_class.new(:path => link, :ensure => :link, :mode => 0666, :target => link_target, :links => :manage)
            catalog.apply

            Puppet::FileSystem.exist?(link).should be_false
          end

          it "should create a link to the target if ensure is omitted" do
            FileUtils.touch(link_target)
            catalog.add_resource described_class.new(:path => link, :target => link_target)
            catalog.apply

            Puppet::FileSystem.exist?(link).should be_true
            Puppet::FileSystem.lstat(link).ftype.should == 'link'
            Puppet::FileSystem.readlink(link).should == link_target
          end
        end

        describe "when following links" do
          it "should ignore dangling symlinks (#6856)" do
            target = tmpfile('dangling')

            FileUtils.touch(target)
            Puppet::FileSystem.symlink(target, link)
            File.delete(target)

            catalog.add_resource described_class.new(:path => path, :source => link, :mode => 0600, :links => :follow)
            catalog.apply
          end

          describe "to a directory" do
            let(:link_target) { tmpdir('dir_target') }

            before :each do
              File.chmod(0600, link_target)

              Puppet::FileSystem.symlink(link_target, link)
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

              Puppet::FileSystem.symlink(link_target, link)
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
              Puppet::FileSystem.symlink(real_target, target)
              Puppet::FileSystem.symlink(target, link)
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
    with_digest_algorithms do
      it "should backup files to a filebucket when one is configured" do
        filebucket = Puppet::Type.type(:filebucket).new :path => tmpfile("filebucket"), :name => "mybucket"
        file = described_class.new :path => path, :backup => "mybucket", :content => "foo"
        catalog.add_resource file
        catalog.add_resource filebucket

        File.open(file[:path], "w") { |f| f.write("bar") }

        d = digest(IO.binread(file[:path]))

        catalog.apply

        filebucket.bucket.getfile(d).should == "bar"
      end

      it "should backup files in the local directory when a backup string is provided" do
        file = described_class.new :path => path, :backup => ".bak", :content => "foo"
        catalog.add_resource file

        File.open(file[:path], "w") { |f| f.puts "bar" }

        catalog.apply

        backup = file[:path] + ".bak"
        Puppet::FileSystem.exist?(backup).should be_true
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

      it "should not backup symlinks", :if => described_class.defaultprovider.feature?(:manages_symlinks) do
        link = tmpfile("link")
        dest1 = tmpfile("dest1")
        dest2 = tmpfile("dest2")
        bucket = Puppet::Type.type(:filebucket).new :path => tmpfile("filebucket"), :name => "mybucket"
        file = described_class.new :path => link, :target => dest2, :ensure => :link, :backup => "mybucket"
        catalog.add_resource file
        catalog.add_resource bucket

        File.open(dest1, "w") { |f| f.puts "whatever" }
        Puppet::FileSystem.symlink(dest1, link)

        d = digest(File.read(file[:path]))

        catalog.apply

        Puppet::FileSystem.readlink(link).should == dest2
        Puppet::FileSystem.exist?(bucket[:path]).should be_false
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


        food = digest(File.read(foofile))
        bard = digest(File.read(barfile))

        catalog.apply

        bucket.bucket.getfile(food).should == "fooyay"
        bucket.bucket.getfile(bard).should == "baryay"
      end
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

    it "should be able to recursively make links to other files", :if => described_class.defaultprovider.feature?(:manages_symlinks) do
      source = tmpfile("file_link_integration_source")

      build_path(source)

      dest = tmpfile("file_link_integration_dest")

      @file = described_class.new(:name => dest, :target => source, :recurse => true, :ensure => :link, :backup => false)

      catalog.add_resource @file

      catalog.apply

      @dirs.each do |path|
        link_path = path.sub(source, dest)

        Puppet::FileSystem.lstat(link_path).should be_directory
      end

      @files.each do |path|
        link_path = path.sub(source, dest)

        Puppet::FileSystem.lstat(link_path).ftype.should == "link"
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

        Puppet::FileSystem.lstat(newpath).should be_directory
      end

      @files.each do |path|
        newpath = path.sub(source, dest)

        Puppet::FileSystem.lstat(newpath).ftype.should == "file"
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
            Puppet::FileSystem.exist?(File.join(path, 'one')).should be_false
            Puppet::FileSystem.exist?(File.join(path, 'three', 'four')).should be_true
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
            Puppet::FileSystem.exist?(File.join(path, 'a')).should be_false
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

            Puppet::FileSystem.exist?(File.join(path, 'a')).should be_true
            Puppet::FileSystem.exist?(File.join(path, 'a', 'b')).should be_false
            Puppet::FileSystem.exist?(File.join(path, 'z')).should be_false
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

            Puppet::FileSystem.exist?(File.join(path, 'a')).should be_true
            Puppet::FileSystem.exist?(File.join(path, 'a', 'b')).should be_false
            Puppet::FileSystem.exist?(File.join(path, 'z')).should be_true
            Puppet::FileSystem.exist?(File.join(path, 'z', 'y')).should be_false
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

      expected_mode = 0755
      Puppet::FileSystem.chmod(expected_mode, source)

      catalog.add_resource described_class.new(:path => dest, :source => source)

      catalog.apply

      File.read(dest).should == "foo"
      (Puppet::FileSystem.stat(dest).mode & 007777).should == expected_mode
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

    Puppet::FileSystem.exist?(dest).should be_false
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
      def expects_sid_granted_full_access_explicitly(path, sid)
        inherited_ace = Puppet::Util::Windows::AccessControlEntry::INHERITED_ACE

        aces = get_aces_for_path_by_sid(path, sid)
        aces.should_not be_empty

        aces.each do |ace|
          ace.mask.should == Puppet::Util::Windows::File::FILE_ALL_ACCESS
          (ace.flags & inherited_ace).should_not == inherited_ace
        end
      end

      def expects_system_granted_full_access_explicitly(path)
        expects_sid_granted_full_access_explicitly(path, @sids[:system])
      end

      def expects_at_least_one_inherited_ace_grants_full_access(path, sid)
        inherited_ace = Puppet::Util::Windows::AccessControlEntry::INHERITED_ACE

        aces = get_aces_for_path_by_sid(path, sid)
        aces.should_not be_empty

        aces.any? do |ace|
          ace.mask == Puppet::Util::Windows::File::FILE_ALL_ACCESS &&
            (ace.flags & inherited_ace) == inherited_ace
        end.should be_true
      end

      def expects_at_least_one_inherited_system_ace_grants_full_access(path)
        expects_at_least_one_inherited_ace_grants_full_access(path, @sids[:system])
      end

      it "should provide valid default values when ACLs are not supported" do
        Puppet::Util::Windows::Security.stubs(:supports_acl?).returns(false)
        Puppet::Util::Windows::Security.stubs(:supports_acl?).with(source).returns false

        file = described_class.new(
          :path   => path,
          :ensure => :file,
          :source => source,
          :backup => false
        )

        catalog.add_resource file
        catalog.apply

        get_owner(path).should =~ /^S\-1\-5\-.*$/
        get_group(path).should =~ /^S\-1\-0\-0.*$/
        get_mode(path).should == 0644
      end

      describe "when processing SYSTEM ACEs" do
        before do
          @sids = {
            :current_user => Puppet::Util::Windows::SID.name_to_sid(Puppet::Util::Windows::ADSI::User.current_user_name),
            :system => Win32::Security::SID::LocalSystem,
            :admin => Puppet::Util::Windows::SID.name_to_sid("Administrator"),
            :guest => Puppet::Util::Windows::SID.name_to_sid("Guest"),
            :users => Win32::Security::SID::BuiltinUsers,
            :power_users => Win32::Security::SID::PowerUsers,
            :none => Win32::Security::SID::Nobody
          }
        end

        describe "on files" do
          before :each do
            @file = described_class.new(
              :path   => path,
              :ensure => :file,
              :source => source,
              :backup => false
            )
            catalog.add_resource @file
          end

          describe "when source permissions are ignored" do
            before :each do
              @file[:source_permissions] = :ignore
            end

            it "preserves the inherited SYSTEM ACE" do
              catalog.apply

              expects_at_least_one_inherited_system_ace_grants_full_access(path)
            end
          end

          describe "when permissions are insync?" do
            it "preserves the explicit SYSTEM ACE" do
              FileUtils.touch(path)

              sd = Puppet::Util::Windows::Security.get_security_descriptor(path)
              sd.protect = true
              sd.owner = @sids[:none]
              sd.group = @sids[:none]
              Puppet::Util::Windows::Security.set_security_descriptor(source, sd)
              Puppet::Util::Windows::Security.set_security_descriptor(path, sd)

              catalog.apply

              expects_system_granted_full_access_explicitly(path)
            end
          end

          describe "when permissions are not insync?" do
            before :each do
              @file[:owner] = 'None'
              @file[:group] = 'None'
            end

            it "replaces inherited SYSTEM ACEs with an uninherited one for an existing file" do
              FileUtils.touch(path)

              expects_at_least_one_inherited_system_ace_grants_full_access(path)

              catalog.apply

              expects_system_granted_full_access_explicitly(path)
            end

            it "replaces inherited SYSTEM ACEs for a new file with an uninherited one" do
              catalog.apply

              expects_system_granted_full_access_explicitly(path)
            end
          end

          describe "created with SYSTEM as the group" do
            before :each do
              @file[:owner] = @sids[:users]
              @file[:group] = @sids[:system]
              @file[:mode] = 0644

              catalog.apply
            end

            it "should allow the user to explicitly set the mode to 4" do
              system_aces = get_aces_for_path_by_sid(path, @sids[:system])
              system_aces.should_not be_empty

              system_aces.each do |ace|
                ace.mask.should == Puppet::Util::Windows::File::FILE_GENERIC_READ
              end
            end

            it "prepends SYSTEM ace when changing group from system to power users" do
              @file[:group] = @sids[:power_users]
              catalog.apply

              system_aces = get_aces_for_path_by_sid(path, @sids[:system])
              system_aces.size.should == 1
            end
          end

          describe "with :links set to :follow" do
            it "should not fail to apply" do
              # at minimal, we need an owner and/or group
              @file[:owner] = @sids[:users]
              @file[:links] = :follow

              catalog.apply do |transaction|
                if transaction.any_failed?
                  pretty_transaction_error(transaction)
                end
              end
            end
          end
        end

        describe "on directories" do
          before :each do
            @directory = described_class.new(
              :path   => dir,
              :ensure => :directory
            )
            catalog.add_resource @directory
          end

          def grant_everyone_full_access(path)
            sd = Puppet::Util::Windows::Security.get_security_descriptor(path)
            sd.dacl.allow(
              'S-1-1-0', #everyone
              Puppet::Util::Windows::File::FILE_ALL_ACCESS,
              Puppet::Util::Windows::AccessControlEntry::OBJECT_INHERIT_ACE |
              Puppet::Util::Windows::AccessControlEntry::CONTAINER_INHERIT_ACE)
            Puppet::Util::Windows::Security.set_security_descriptor(path, sd)
          end

          after :each do
            grant_everyone_full_access(dir)
          end

          describe "when source permissions are ignored" do
            before :each do
              @directory[:source_permissions] = :ignore
            end

            it "preserves the inherited SYSTEM ACE" do
              catalog.apply

              expects_at_least_one_inherited_system_ace_grants_full_access(dir)
            end
          end

          describe "when permissions are insync?" do
            it "preserves the explicit SYSTEM ACE" do
              Dir.mkdir(dir)

              source_dir = tmpdir('source_dir')
              @directory[:source] = source_dir

              sd = Puppet::Util::Windows::Security.get_security_descriptor(source_dir)
              sd.protect = true
              sd.owner = @sids[:none]
              sd.group = @sids[:none]
              Puppet::Util::Windows::Security.set_security_descriptor(source_dir, sd)
              Puppet::Util::Windows::Security.set_security_descriptor(dir, sd)

              catalog.apply

              expects_system_granted_full_access_explicitly(dir)
            end
          end

          describe "when permissions are not insync?" do
            before :each do
              @directory[:owner] = 'None'
              @directory[:group] = 'None'
              @directory[:mode] = 0444
            end

            it "replaces inherited SYSTEM ACEs with an uninherited one for an existing directory" do
              FileUtils.mkdir(dir)

              expects_at_least_one_inherited_system_ace_grants_full_access(dir)

              catalog.apply

              expects_system_granted_full_access_explicitly(dir)
            end

            it "replaces inherited SYSTEM ACEs with an uninherited one for an existing directory" do
              catalog.apply

              expects_system_granted_full_access_explicitly(dir)
            end

            describe "created with SYSTEM as the group" do
              before :each do
                @directory[:owner] = @sids[:users]
                @directory[:group] = @sids[:system]
                @directory[:mode] = 0644

                catalog.apply
              end

              it "should allow the user to explicitly set the mode to 4" do
                system_aces = get_aces_for_path_by_sid(dir, @sids[:system])
                system_aces.should_not be_empty

                system_aces.each do |ace|
                  # unlike files, Puppet sets execute bit on directories that are readable
                  ace.mask.should == Puppet::Util::Windows::File::FILE_GENERIC_READ | Puppet::Util::Windows::File::FILE_GENERIC_EXECUTE
                end
              end

              it "prepends SYSTEM ace when changing group from system to power users" do
                @directory[:group] = @sids[:power_users]
                catalog.apply

                system_aces = get_aces_for_path_by_sid(dir, @sids[:system])
                system_aces.size.should == 1
              end
            end

            describe "with :links set to :follow" do
              it "should not fail to apply" do
                # at minimal, we need an owner and/or group
                @directory[:owner] = @sids[:users]
                @directory[:links] = :follow

                catalog.apply do |transaction|
                  if transaction.any_failed?
                    pretty_transaction_error(transaction)
                  end
                end
              end
            end
          end
        end
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
      Puppet::FileSystem.exist?(@purgee).should be_false
    end
  end

  describe "when using validate_cmd" do
    it "should fail the file resource if command fails" do
      catalog.add_resource(described_class.new(:path => path, :content => "foo", :validate_cmd => "/usr/bin/env false"))
      Puppet::Util::Execution.expects(:execute).with("/usr/bin/env false", {:combine => true, :failonfail => true}).raises(Puppet::ExecutionFailure, "Failed")
      report = catalog.apply.report
      report.resource_statuses["File[#{path}]"].should be_failed
      Puppet::FileSystem.exist?(path).should be_false
    end

    it "should succeed the file resource if command succeeds" do
      catalog.add_resource(described_class.new(:path => path, :content => "foo", :validate_cmd => "/usr/bin/env true"))
      Puppet::Util::Execution.expects(:execute).with("/usr/bin/env true", {:combine => true, :failonfail => true}).returns ''
      report = catalog.apply.report
      report.resource_statuses["File[#{path}]"].should_not be_failed
      Puppet::FileSystem.exist?(path).should be_true
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

  def pretty_transaction_error(transaction)
    report = transaction.report
    status_failures = report.resource_statuses.values.select { |r| r.failed? }
    status_fail_msg = status_failures.
      collect(&:events).
      flatten.
      select { |event| event.status == 'failure' }.
      collect { |event| "#{event.resource}: #{event.message}" }.join("; ")

    raise "Got #{status_failures.length} failure(s) while applying: #{status_fail_msg}"
  end
end
