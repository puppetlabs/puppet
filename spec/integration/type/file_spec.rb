# coding: utf-8
require 'spec_helper'

require 'puppet_spec/files'

if Puppet::Util::Platform.windows?
  require 'puppet/util/windows'
  class WindowsSecurity
    extend Puppet::Util::Windows::Security
  end
end

describe Puppet::Type.type(:file), :uses_checksums => true do
  include PuppetSpec::Files
  include_context 'with supported checksum types'

  let(:catalog) { Puppet::Resource::Catalog.new }
  let(:path) do
    # we create a directory first so backups of :path that are stored in
    # the same directory will also be removed after the tests
    parent = tmpdir('file_spec')
    File.join(parent, 'file_testing')
  end

  let(:path_protected) do
    # we create a file inside windows protected folders (C:\Windows, C:\Windows\system32, etc)
    # the file will also be removed after the tests
    parent = 'C:\Windows'
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

  around :each do |example|
    Puppet.override(:environments => Puppet::Environments::Static.new) do
      example.run
    end
  end

  before do
    # stub this to not try to create state.yaml
    allow(Puppet::Util::Storage).to receive(:store)

    allow_any_instance_of(Puppet::Type.type(:file)).to receive(:file).and_return('my/file.pp')
    allow_any_instance_of(Puppet::Type.type(:file)).to receive(:line).and_return(5)
  end

  it "should not attempt to manage files that do not exist if no means of creating the file is specified" do
    source = tmpfile('source')

    catalog.add_resource described_class.new :path => source, :mode => '0755'

    status = catalog.apply.report.resource_statuses["File[#{source}]"]
    expect(status).not_to be_failed
    expect(status).not_to be_changed
    expect(Puppet::FileSystem.exist?(source)).to be_falsey
  end

  describe "when ensure is present using an empty file" do
    before(:each) do
      catalog.add_resource(described_class.new(:path => path, :ensure => :present, :backup => :false))
    end

    context "file is present" do
      before(:each) do
        FileUtils.touch(path)
      end

      it "should do nothing" do
        report = catalog.apply.report
        expect(report.resource_statuses["File[#{path}]"]).not_to be_failed
        expect(Puppet::FileSystem.exist?(path)).to be_truthy
      end

      it "should log nothing" do
        logs = catalog.apply.report.logs
        expect(logs).to be_empty
      end
    end

    context "file is not present" do
      it "should create the file" do
        report = catalog.apply.report
        expect(report.resource_statuses["File[#{path}]"]).not_to be_failed
        expect(Puppet::FileSystem.exist?(path)).to be_truthy
      end

      it "should log that the file was created" do
        logs = catalog.apply.report.logs
        expect(logs.first.source).to eq("/File[#{path}]/ensure")
        expect(logs.first.message).to eq("created")
      end
    end
  end

  describe "when ensure is absent" do
    before(:each) do
      catalog.add_resource(described_class.new(:path => path, :ensure => :absent, :backup => :false))
    end

    context "file is present" do
      before(:each) do
        FileUtils.touch(path)
      end

      it "should remove the file" do
        report = catalog.apply.report
        expect(report.resource_statuses["File[#{path}]"]).not_to be_failed
        expect(Puppet::FileSystem.exist?(path)).to be_falsey
      end

      it "should log that the file was removed" do
        logs = catalog.apply.report.logs
        expect(logs.first.source).to eq("/File[#{path}]/ensure")
        expect(logs.first.message).to eq("removed")
      end
    end

    context "file is not present" do
      it "should do nothing" do
        report = catalog.apply.report
        expect(report.resource_statuses["File[#{path}]"]).not_to be_failed
        expect(Puppet::FileSystem.exist?(path)).to be_falsey
      end

      it "should log nothing" do
        logs = catalog.apply.report.logs
        expect(logs).to be_empty
      end
    end

    # issue #14599
    it "should not fail if parts of path aren't directories" do
      FileUtils.touch(path)
      catalog.add_resource(described_class.new(:path => File.join(path,'no_such_file'), :ensure => :absent, :backup => :false))
      report = catalog.apply.report
      expect(report.resource_statuses["File[#{File.join(path,'no_such_file')}]"]).not_to be_failed
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

      expect(get_owner(target)).to eq(owner)
    end

    it "should set the group" do
      target = tmpfile_with_contents('target', '')
      group = get_group(target)

      catalog.add_resource described_class.new(
        :name    => target,
        :group   => group
      )

      catalog.apply

      expect(get_group(target)).to eq(group)
    end

    describe "when setting mode" do
      describe "for directories" do
        let(:target) { tmpdir('dir_mode') }

        it "should set executable bits for newly created directories" do
          catalog.add_resource described_class.new(:path => target, :ensure => :directory, :mode => '0600')

          catalog.apply

          expect(get_mode(target) & 07777).to eq(0700)
        end

        it "should set executable bits for existing readable directories" do
          set_mode(0600, target)

          catalog.add_resource described_class.new(:path => target, :ensure => :directory, :mode => '0644')
          catalog.apply

          expect(get_mode(target) & 07777).to eq(0755)
        end

        it "should not set executable bits for unreadable directories" do
          begin
            catalog.add_resource described_class.new(:path => target, :ensure => :directory, :mode => '0300')

            catalog.apply

            expect(get_mode(target) & 07777).to eq(0300)
          ensure
            # so we can cleanup
            set_mode(0700, target)
          end
        end

        it "should set user, group, and other executable bits" do
          catalog.add_resource described_class.new(:path => target, :ensure => :directory, :mode => '0664')

          catalog.apply

          expect(get_mode(target) & 07777).to eq(0775)
        end

        it "should set executable bits when overwriting a non-executable file" do
          target_path = tmpfile_with_contents('executable', '')
          set_mode(0444, target_path)

          catalog.add_resource described_class.new(:path => target_path, :ensure => :directory, :mode => '0666', :backup => false)
          catalog.apply

          expect(get_mode(target_path) & 07777).to eq(0777)
          expect(File).to be_directory(target_path)
        end
      end

      describe "for files" do
        it "should not set executable bits" do
          catalog.add_resource described_class.new(:path => path, :ensure => :file, :mode => '0666')
          catalog.apply

          expect(get_mode(path) & 07777).to eq(0666)
        end

        context "file is in protected windows directory", :if => Puppet.features.microsoft_windows? do
          after { FileUtils.rm(path_protected) }

          it "should set and get the correct mode for files inside protected windows folders" do
            catalog.add_resource described_class.new(:path => path_protected, :ensure => :file, :mode => '0640')
            catalog.apply
  
            expect(get_mode(path_protected) & 07777).to eq(0640)
          end

          it "should not change resource's status inside protected windows folders if mode is the same" do
            FileUtils.touch(path_protected)
            set_mode(0644, path_protected)
            catalog.add_resource described_class.new(:path => path_protected, :ensure => :file, :mode => '0644')
            result = catalog.apply
            status = result.report.resource_statuses["File[#{path_protected}]"]
            expect(status).not_to be_failed
            expect(status).not_to be_changed
          end
        end
        
        it "should not set executable bits when replacing an executable directory (#10365)" do
          pending("bug #10365")

          FileUtils.mkdir(path)
          set_mode(0777, path)

          catalog.add_resource described_class.new(:path => path, :ensure => :file, :mode => '0666', :backup => false, :force => true)
          catalog.apply

          expect(get_mode(path) & 07777).to eq(0666)
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

          it "should not set the executable bit on the link target" do
            catalog.add_resource described_class.new(:path => link, :ensure => :link, :mode => '0666', :target => link_target, :links => :manage)

            catalog.apply

            expected_target_permissions = Puppet::Util::Platform.windows? ? 0700 : 0444

            expect(Puppet::FileSystem.stat(link_target).mode & 07777).to eq(expected_target_permissions)
          end

          it "should ignore dangling symlinks (#6856)" do
            File.delete(link_target)

            catalog.add_resource described_class.new(:path => link, :ensure => :link, :mode => '0666', :target => link_target, :links => :manage)
            catalog.apply

            expect(Puppet::FileSystem.exist?(link)).to be_falsey
          end

          it "should create a link to the target if ensure is omitted" do
            FileUtils.touch(link_target)
            catalog.add_resource described_class.new(:path => link, :target => link_target)
            catalog.apply

            expect(Puppet::FileSystem.exist?(link)).to be_truthy
            expect(Puppet::FileSystem.lstat(link).ftype).to eq('link')
            expect(Puppet::FileSystem.readlink(link)).to eq(link_target)
          end
        end

        describe "when following links" do
          it "should ignore dangling symlinks (#6856)" do
            target = tmpfile('dangling')

            FileUtils.touch(target)
            Puppet::FileSystem.symlink(target, link)
            File.delete(target)

            catalog.add_resource described_class.new(:path => path, :source => link, :mode => '0600', :links => :follow)
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
                catalog.add_resource described_class.new(:path => path, :source => link, :mode => '0666', :links => :follow)
                catalog.apply

                expect(File).to be_directory(path)
                expect(get_mode(path) & 07777).to eq(0777)
              end

              it "should set the executable bits when overwriting the destination (#10315)" do
                FileUtils.touch(path)

                catalog.add_resource described_class.new(:path => path, :source => link, :mode => '0666', :links => :follow, :backup => false)
                catalog.apply

                expect(File).to be_directory(path)
                expect(get_mode(path) & 07777).to eq(0777)
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
                catalog.add_resource described_class.new(:path => path, :source => link, :mode => '0666', :links => :follow)
                catalog.apply

                expect(File).to be_directory(path)
                expect(get_mode(path) & 07777).to eq(0777)
              end

              it "should set executable bits when overwriting the destination" do
                FileUtils.touch(path)

                catalog.add_resource described_class.new(:path => path, :source => link, :mode => '0666', :links => :follow, :backup => false)
                catalog.apply

                expect(File).to be_directory(path)
                expect(get_mode(path) & 07777).to eq(0777)
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
              catalog.add_resource described_class.new(:path => path, :source => link, :mode => '0600', :links => :follow)
              catalog.apply

              expect(File).to be_file(path)
              expect(get_mode(path) & 07777).to eq(0600)
            end

            it "should not give a deprecation warning about using a checksum in content when using source to define content" do
              FileUtils.touch(path)
              expect(Puppet).not_to receive(:puppet_deprecation_warning)
              catalog.add_resource described_class.new(:path => path, :source => link, :links => :follow)
              catalog.apply
            end

            context "overwriting a file" do
              before :each do
                FileUtils.touch(path)
                set_mode(0644, path)
                catalog.add_resource described_class.new(:path => path, :source => link, :mode => '0600', :links => :follow)
              end

              it "should overwrite the file" do
                catalog.apply

                expect(File).to be_file(path)
                expect(get_mode(path) & 07777).to eq(0600)
              end

              it "should log that the mode changed" do
                report = catalog.apply.report

                expect(report.logs.first.message).to eq("mode changed '0644' to '0600'")
                expect(report.logs.first.source).to eq("/File[#{path}]/mode")
              end
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
                catalog.add_resource described_class.new(:path => path, :source => link, :mode => '0600', :links => :follow)
                catalog.apply

                expect(File).to be_directory(path)
                expect(get_mode(path) & 07777).to eq(0700)
              end

              it "should overwrite the destination and apply executable bits" do
                FileUtils.mkdir(path)

                catalog.add_resource described_class.new(:path => path, :source => link, :mode => '0600', :links => :follow)
                catalog.apply

                expect(File).to be_directory(path)
                expect(get_mode(path) & 0111).to eq(0100)
              end
            end
          end
        end
      end
    end
  end

  describe "when writing files" do
    shared_examples "files are backed up" do |resource_options|
      it "should backup files to a filebucket when one is configured" do |example|
        if Puppet::Util::Platform.windows? && ['sha512', 'sha384'].include?(example.metadata[:digest_algorithm])
          skip "PUP-8257: Skip file bucket test on windows for #{example.metadata[:digest_algorithm]} due to long path names"
        end

        filebucket = Puppet::Type.type(:filebucket).new :path => tmpfile("filebucket"), :name => "mybucket"
        file = described_class.new({:path => path, :backup => "mybucket", :content => "foo"}.merge(resource_options))
        catalog.add_resource file
        catalog.add_resource filebucket

        File.open(file[:path], "w") { |f| f.write("bar") }

        d = filebucket_digest.call(IO.binread(file[:path]))

        catalog.apply

        expect(filebucket.bucket.getfile(d)).to eq("bar")
      end

      it "should backup files in the local directory when a backup string is provided" do
        file = described_class.new({:path => path, :backup => ".bak", :content => "foo"}.merge(resource_options))
        catalog.add_resource file

        File.open(file[:path], "w") { |f| f.puts "bar" }

        catalog.apply

        backup = file[:path] + ".bak"
        expect(Puppet::FileSystem.exist?(backup)).to be_truthy
        expect(File.read(backup)).to eq("bar\n")
      end

      it "should fail if no backup can be performed" do
        dir = tmpdir("backups")

        file = described_class.new({:path => File.join(dir, "testfile"), :backup => ".bak", :content => "foo"}.merge(resource_options))
        catalog.add_resource file

        File.open(file[:path], 'w') { |f| f.puts "bar" }

        # Create a directory where the backup should be so that writing to it fails
        Dir.mkdir(File.join(dir, "testfile.bak"))

        allow(Puppet::Util::Log).to receive(:newmessage)

        catalog.apply

        expect(File.read(file[:path])).to eq("bar\n")
      end

      it "should not backup symlinks", :if => described_class.defaultprovider.feature?(:manages_symlinks) do
        link = tmpfile("link")
        dest1 = tmpfile("dest1")
        dest2 = tmpfile("dest2")
        bucket = Puppet::Type.type(:filebucket).new :path => tmpfile("filebucket"), :name => "mybucket"
        file = described_class.new({:path => link, :target => dest2, :ensure => :link, :backup => "mybucket"}.merge(resource_options))
        catalog.add_resource file
        catalog.add_resource bucket

        File.open(dest1, "w") { |f| f.puts "whatever" }
        Puppet::FileSystem.symlink(dest1, link)

        catalog.apply

        expect(Puppet::FileSystem.readlink(link)).to eq(dest2)
        expect(Puppet::FileSystem.exist?(bucket[:path])).to be_falsey
      end

      it "should backup directories to the local filesystem by copying the whole directory" do
        file = described_class.new({:path => path, :backup => ".bak", :content => "foo", :force => true}.merge(resource_options))
        catalog.add_resource file

        Dir.mkdir(path)

        otherfile = File.join(path, "foo")
        File.open(otherfile, "w") { |f| f.print "yay" }

        catalog.apply

        backup = "#{path}.bak"
        expect(FileTest).to be_directory(backup)

        expect(File.read(File.join(backup, "foo"))).to eq("yay")
      end

      it "should backup directories to filebuckets by backing up each file separately" do |example|
        if Puppet::Util::Platform.windows? && ['sha512', 'sha384'].include?(example.metadata[:digest_algorithm])
          skip "PUP-8257: Skip file bucket test on windows for #{example.metadata[:digest_algorithm]} due to long path names"
        end

        bucket = Puppet::Type.type(:filebucket).new :path => tmpfile("filebucket"), :name => "mybucket"
        file = described_class.new({:path => tmpfile("bucket_backs"), :backup => "mybucket", :content => "foo", :force => true}.merge(resource_options))
        catalog.add_resource file
        catalog.add_resource bucket

        Dir.mkdir(file[:path])
        foofile = File.join(file[:path], "foo")
        barfile = File.join(file[:path], "bar")
        File.open(foofile, "w") { |f| f.print "fooyay" }
        File.open(barfile, "w") { |f| f.print "baryay" }


        food = filebucket_digest.call(File.read(foofile))
        bard = filebucket_digest.call(File.read(barfile))

        catalog.apply

        expect(bucket.bucket.getfile(food)).to eq("fooyay")
        expect(bucket.bucket.getfile(bard)).to eq("baryay")
      end
    end

    it "should not give a checksum deprecation warning when given actual content" do
      expect(Puppet).not_to receive(:puppet_deprecation_warning)
      catalog.add_resource described_class.new(:path => path, :content => 'this is content')
      catalog.apply
    end

    with_digest_algorithms do
      it_should_behave_like "files are backed up", {} do
        let(:filebucket_digest) { method(:digest) }
      end

      it "should give a checksum deprecation warning" do
        expect(Puppet).to receive(:puppet_deprecation_warning).with('Using a checksum in a file\'s "content" property is deprecated. The ability to use a checksum to retrieve content from the filebucket using the "content" property will be removed in a future release. The literal value of the "content" property will be written to the file. The checksum retrieval functionality is being replaced by the use of static catalogs. See https://puppet.com/docs/puppet/latest/static_catalogs.html for more information.', {:file => 'my/file.pp', :line => 5})
        d = digest("this is some content")
        catalog.add_resource described_class.new(:path => path, :content => "{#{digest_algorithm}}#{d}")
        catalog.apply
      end

      it "should not give a checksum deprecation warning when no content is specified while checksum and checksum value are used" do
        expect(Puppet).not_to receive(:puppet_deprecation_warning)
        d = digest("this is some content")
        catalog.add_resource described_class.new(:path => path, :checksum => digest_algorithm, :checksum_value => d)
        catalog.apply
      end
    end

    CHECKSUM_TYPES_TO_TRY.each do |checksum_type, checksum|
      describe "when checksum_type is #{checksum_type}" do
        # FileBucket uses the globally configured default for lookup by digest, which right now is SHA256.
        it_should_behave_like "files are backed up", {:checksum => checksum_type} do
          let(:filebucket_digest) { Proc.new {|x| Puppet::Util::Checksums.sha256(x)} }
        end
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
        :mode    => '0644',
        :recurse => true,
        :backup  => false
      )

      catalog.add_resource @file

      expect { @file.eval_generate }.not_to raise_error
    end

    it "should be able to recursively set properties on existing files" do
      path = tmpfile("file_integration_tests")

      build_path(path)

      file = described_class.new(
        :name    => path,
        :mode    => '0644',
        :recurse => true,
        :backup  => false
      )

      catalog.add_resource file

      catalog.apply

      expect(@dirs).not_to be_empty
      @dirs.each do |dir|
        expect(get_mode(dir) & 007777).to eq(0755)
      end

      expect(@files).not_to be_empty
      @files.each do |dir|
        expect(get_mode(dir) & 007777).to eq(0644)
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

        expect(Puppet::FileSystem.lstat(link_path)).to be_directory
      end

      @files.each do |path|
        link_path = path.sub(source, dest)

        expect(Puppet::FileSystem.lstat(link_path).ftype).to eq("link")
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

        expect(Puppet::FileSystem.lstat(newpath)).to be_directory
      end

      @files.each do |path|
        newpath = path.sub(source, dest)

        expect(Puppet::FileSystem.lstat(newpath).ftype).to eq("file")
      end
    end

    it "should not recursively manage files set to be ignored" do
      srcdir = tmpfile("ignore_vs_recurse_1")
      dstdir = tmpfile("ignore_vs_recurse_2")

      FileUtils.mkdir_p(srcdir)
      FileUtils.mkdir_p(dstdir)

      srcfile = File.join(srcdir, "file.src")
      cpyfile = File.join(dstdir, "file.src")
      ignfile = File.join(srcdir, "file.ign")

      File.open(srcfile, "w") { |f| f.puts "don't ignore me" }
      File.open(ignfile, "w") { |f| f.puts "you better ignore me" }


      catalog.add_resource described_class.new(
                             :name => srcdir,
                             :ensure => 'directory',
                             :mode => '0755',)

      catalog.add_resource described_class.new(
                             :name => dstdir,
                             :ensure => 'directory',
                             :mode => "755",
                             :source => srcdir,
                             :recurse => true,
                             :ignore => '*.ign',)

      catalog.apply
      expect(Puppet::FileSystem.exist?(srcdir)).to be_truthy
      expect(Puppet::FileSystem.exist?(dstdir)).to be_truthy
      expect(File.read(srcfile).strip).to eq("don't ignore me")
      expect(File.read(cpyfile).strip).to eq("don't ignore me")
      expect(Puppet::FileSystem.exist?("#{dstdir}/file.ign")).to be_falsey
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

      expect(get_mode(file) & 007777).to eq(0644)
    end

    it "should recursively manage files even if there is an explicit file whose name is a prefix of the managed file" do
      managed      = File.join(path, "file")
      generated    = File.join(path, "file_with_a_name_starting_with_the_word_file")

      FileUtils.mkdir_p(path)
      FileUtils.touch(managed)
      FileUtils.touch(generated)

      catalog.add_resource described_class.new(:name => path,    :recurse => true, :backup => false, :mode => '0700')
      catalog.add_resource described_class.new(:name => managed, :recurse => true, :backup => false, :mode => "644")

      catalog.apply

      expect(get_mode(generated) & 007777).to eq(0700)
    end

    describe "when recursing remote directories" do
      describe "for the 2nd time" do
        with_checksum_types "one", "x" do
          let(:target_file) { File.join(path, 'x') }
          let(:second_catalog) { Puppet::Resource::Catalog.new }
          before(:each) do
            @options = {
              :path => path,
              :ensure => :directory,
              :backup => false,
              :recurse => true,
              :checksum => checksum_type,
              :source => env_path
            }
          end

          it "should not update the target directory" do
            # Ensure the test believes the source file was written in the past.
            FileUtils.touch checksum_file, :mtime => Time.now - 20
            catalog.add_resource Puppet::Type.send(:newfile, @options)
            catalog.apply
            expect(File).to be_directory(path)
            expect(Puppet::FileSystem.exist?(target_file)).to be_truthy

            # The 2nd time the resource should not change.
            second_catalog.add_resource Puppet::Type.send(:newfile, @options)
            result = second_catalog.apply
            status = result.report.resource_statuses["File[#{target_file}]"]
            expect(status).not_to be_failed
            expect(status).not_to be_changed
          end

          it "should update the target directory if contents change" do
            pending "a way to appropriately mock ctime checks for a particular file" if checksum_type == 'ctime'

            catalog.add_resource Puppet::Type.send(:newfile, @options)
            catalog.apply
            expect(File).to be_directory(path)
            expect(Puppet::FileSystem.exist?(target_file)).to be_truthy

            # Change the source file.
            File.open(checksum_file, "wb") { |f| f.write "some content" }
            FileUtils.touch target_file, mtime: Time.now - 20

            # The 2nd time should update the resource.
            second_catalog.add_resource Puppet::Type.send(:newfile, @options)
            result = second_catalog.apply
            status = result.report.resource_statuses["File[#{target_file}]"]
            expect(status).not_to be_failed
            expect(status).to be_changed
          end
        end
      end

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

            expect(File).to be_directory(path)
            expect(Puppet::FileSystem.exist?(File.join(path, 'one'))).to be_falsey
            expect(Puppet::FileSystem.exist?(File.join(path, 'three', 'four'))).to be_truthy
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

            expect(File).to be_directory(path)
            expect(Puppet::FileSystem.exist?(File.join(path, 'a'))).to be_falsey
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

            expect(Puppet::FileSystem.exist?(File.join(path, 'a'))).to be_truthy
            expect(Puppet::FileSystem.exist?(File.join(path, 'a', 'b'))).to be_falsey
            expect(Puppet::FileSystem.exist?(File.join(path, 'z'))).to be_falsey
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

            expect(File.read(path)).to eq('yay')
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

            expect(File.read(path)).to eq('')
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

            expect(File.read(File.join(dest, 'a'))).to eq(one)
            expect(File.read(File.join(dest, 'b'))).to eq(two)
            expect(File.read(File.join(dest, 'c'))).to eq(three)
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

            expect(Puppet::FileSystem.exist?(File.join(path, 'a'))).to be_truthy
            expect(Puppet::FileSystem.exist?(File.join(path, 'a', 'b'))).to be_falsey
            expect(Puppet::FileSystem.exist?(File.join(path, 'z'))).to be_truthy
            expect(Puppet::FileSystem.exist?(File.join(path, 'z', 'y'))).to be_falsey
          end
        end
      end
    end
  end

  describe "when generating resources" do
    before do
      source = tmpdir("generating_in_catalog_source")

      file_in_dir_with_contents(source, "one", "uno")
      file_in_dir_with_contents(source, "two", "dos")

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
        expect(catalog.resource(:file, File.join(path, "one"))).to be_a(described_class)
        expect(catalog.resource(:file, File.join(path, "two"))).to be_a(described_class)
      end
    end

    it "should have an edge to each resource in the relationship graph" do
      catalog.apply do |trans|
        one = catalog.resource(:file, File.join(path, "one"))
        expect(catalog.relationship_graph).to be_edge(@file, one)

        two = catalog.resource(:file, File.join(path, "two"))
        expect(catalog.relationship_graph).to be_edge(@file, two)
      end
    end
  end

  describe "when copying files" do
    it "should be able to copy files with pound signs in their names (#285)" do
      source = tmpfile_with_contents("filewith#signs", "foo")
      dest = tmpfile("destwith#signs")
      catalog.add_resource described_class.new(:name => dest, :source => source)

      catalog.apply

      expect(File.read(dest)).to eq("foo")
    end

    it "should be able to copy files with spaces in their names" do
      dest = tmpfile("destwith spaces")
      source = tmpfile_with_contents("filewith spaces", "foo")
      catalog.add_resource described_class.new(:path => dest, :source => source)

      catalog.apply

      expect(File.read(dest)).to eq("foo")
    end

    it "should maintain source URIs as UTF-8 with Unicode characters in their names and be able to copy such files" do
      # different UTF-8 widths
      # 1-byte A
      # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
      # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
      # 4-byte <U+070E> - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
      mixed_utf8 = "A\u06FF\u16A0\u{2070E}" # Aۿᚠ<U+070E>

      dest = tmpfile("destwith #{mixed_utf8}")
      source = tmpfile_with_contents("filewith #{mixed_utf8}", "foo")
      catalog.add_resource described_class.new(:path => dest, :source => source)

      catalog.apply

      # find the resource and verify
      resource = catalog.resources.first { |r| r.title == "File[#{dest}]" }
      uri_path = resource.parameters[:source].uri.path

      # note that Windows file:// style URIs get an extra / in front of c:/ like /c:/
      source_prefix = Puppet::Util::Platform.windows? ? '/' : ''

      # the URI can be round-tripped through unescape
      expect(Puppet::Util.uri_unescape(uri_path)).to eq(source_prefix + source)
      # and is properly UTF-8
      expect(uri_path.encoding).to eq (Encoding::UTF_8)

      expect(File.read(dest)).to eq('foo')
    end

    it "should be able to copy individual files even if recurse has been specified" do
      source = tmpfile_with_contents("source", "foo")
      dest = tmpfile("dest")
      catalog.add_resource described_class.new(:name => dest, :source => source, :recurse => true)

      catalog.apply

      expect(File.read(dest)).to eq("foo")
    end
  end

  CHECKSUM_TYPES_TO_TRY.each do |checksum_type, checksum|
    describe "when checksum_type is #{checksum_type}" do
      before(:each) do
        @options = {:path => path, :content => CHECKSUM_PLAINTEXT, :checksum => checksum_type}
      end

      context "when changing the content" do
        before :each do
          FileUtils.touch(path)
          catalog.add_resource described_class.send(:new, @options)
        end

        it "should overwrite contents" do
          catalog.apply
          expect(Puppet::FileSystem.binread(path)).to eq(CHECKSUM_PLAINTEXT)
        end

        it "should log that content changed" do
          report = catalog.apply.report
          expect(report.logs.first.source).to eq("/File[#{path}]/content")
          expect(report.logs.first.message).to match(/content changed '{#{checksum_type}}[0-9a-f]*' to '{#{checksum_type}}#{checksum}'/)
        end
      end

      context "ensure is present" do
        before(:each) do
          @options[:ensure] = "present"
        end

        it "should create a file with content" do
          catalog.add_resource described_class.send(:new, @options)
          catalog.apply
          expect(Puppet::FileSystem.binread(path)).to eq(CHECKSUM_PLAINTEXT)

          second_catalog = Puppet::Resource::Catalog.new
          second_catalog.add_resource described_class.send(:new, @options)
          status = second_catalog.apply.report.resource_statuses["File[#{path}]"]
          expect(status).not_to be_failed
          expect(status).not_to be_changed
        end

        it "should log the content checksum" do
          catalog.add_resource described_class.send(:new, @options)
          report = catalog.apply.report
          expect(report.logs.first.source).to eq("/File[#{path}]/ensure")
          expect(report.logs.first.message).to eq("defined content as '{#{checksum_type}}#{checksum}'")

          second_catalog = Puppet::Resource::Catalog.new
          second_catalog.add_resource described_class.send(:new, @options)
          logs = second_catalog.apply.report.logs
          expect(logs).to be_empty
        end
      end

      context "ensure is omitted" do
        it "should create a file with content" do
          catalog.add_resource described_class.send(:new, @options)
          catalog.apply
          expect(Puppet::FileSystem.binread(path)).to eq(CHECKSUM_PLAINTEXT)

          second_catalog = Puppet::Resource::Catalog.new
          second_catalog.add_resource described_class.send(:new, @options)
          status = second_catalog.apply.report.resource_statuses["File[#{path}]"]
          expect(status).not_to be_failed
          expect(status).not_to be_changed
        end

        it "should log the content checksum" do
          catalog.add_resource described_class.send(:new, @options)
          report = catalog.apply.report
          expect(report.logs.first.source).to eq("/File[#{path}]/ensure")
          expect(report.logs.first.message).to eq("defined content as '{#{checksum_type}}#{checksum}'")

          second_catalog = Puppet::Resource::Catalog.new
          second_catalog.add_resource described_class.send(:new, @options)
          logs = second_catalog.apply.report.logs
          expect(logs).to be_empty
        end
      end

      context "both content and ensure are set" do
        before(:each) do
          @options[:ensure] = "file"
        end

        it "should create files with content" do
          catalog.add_resource described_class.send(:new, @options)
          catalog.apply
          expect(Puppet::FileSystem.binread(path)).to eq(CHECKSUM_PLAINTEXT)

          second_catalog = Puppet::Resource::Catalog.new
          second_catalog.add_resource described_class.send(:new, @options)
          status = second_catalog.apply.report.resource_statuses["File[#{path}]"]
          expect(status).not_to be_failed
          expect(status).not_to be_changed
        end

        it "should log the content checksum" do
          catalog.add_resource described_class.send(:new, @options)
          report = catalog.apply.report
          expect(report.logs.first.source).to eq("/File[#{path}]/ensure")
          expect(report.logs.first.message).to eq("defined content as '{#{checksum_type}}#{checksum}'")

          second_catalog = Puppet::Resource::Catalog.new
          second_catalog.add_resource described_class.send(:new, @options)
          logs = second_catalog.apply.report.logs
          expect(logs).to be_empty
        end
      end
    end
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

    expect(Puppet::FileSystem.exist?(dest)).to be_falsey
  end

  describe "when sourcing" do
    it "should give a deprecation warning when the user sets source_permissions" do
      expect(Puppet).to receive(:puppet_deprecation_warning).with(
        'The `source_permissions` parameter is deprecated. Explicitly set `owner`, `group`, and `mode`.',
        {:file => 'my/file.pp', :line => 5})

      catalog.add_resource described_class.new(:path => path, :content => 'this is content', :source_permissions => :use_when_creating)
      catalog.apply
    end

    it "should not give a deprecation warning when the user does not set source_permissions" do
      expect(Puppet).not_to receive(:puppet_deprecation_warning)
      catalog.add_resource described_class.new(:path => path, :content => 'this is content')
      catalog.apply
    end

    with_checksum_types "source", "default_values" do
      before(:each) do
        set_mode(0770, checksum_file)
        @options = {
          :path   => path,
          :ensure => :file,
          :source => checksum_file,
          :checksum => checksum_type,
          :backup => false
        }
      end

      describe "on POSIX systems", :if => Puppet.features.posix? do
        it "should apply the source metadata values" do
          @options[:source_permissions] = :use

          catalog.add_resource described_class.send(:new, @options)
          catalog.apply
          expect(get_owner(path)).to eq(get_owner(checksum_file))
          expect(get_group(path)).to eq(get_group(checksum_file))
          expect(get_mode(path) & 07777).to eq(0770)

          second_catalog = Puppet::Resource::Catalog.new
          second_catalog.add_resource described_class.send(:new, @options)
          status = second_catalog.apply.report.resource_statuses["File[#{path}]"]
          expect(status).not_to be_failed
          expect(status).not_to be_changed
        end
      end

      it "should override the default metadata values" do
        @options[:mode] = '0440'

        catalog.add_resource described_class.send(:new, @options)
        catalog.apply
        expect(get_mode(path) & 07777).to eq(0440)

        second_catalog = Puppet::Resource::Catalog.new
        second_catalog.add_resource described_class.send(:new, @options)
        status = second_catalog.apply.report.resource_statuses["File[#{path}]"]
        expect(status).not_to be_failed
        expect(status).not_to be_changed
      end
    end

    let(:source) { tmpfile_with_contents("source_default_values", "yay") }

    describe "from http" do
      let(:http_source) { "http://my-server/file" }
      let(:httppath) { "#{path}http" }

      context "using mtime", :vcr => true do
        let(:resource) do
          described_class.new(
            :path   => httppath,
            :ensure => :file,
            :source => http_source,
            :backup => false,
            :checksum => :mtime
          )
        end

        it "should fetch if not on the local disk" do
          catalog.add_resource resource
          catalog.apply
          expect(Puppet::FileSystem.exist?(httppath)).to be_truthy
          expect(File.read(httppath)).to eq "Content via HTTP\n"
        end

        # The fixture has neither last-modified nor content-checksum headers.
        # Such upstream ressources are treated as "really fresh" and get
        # downloaded during every run.
        it "should fetch if no header specified" do
          File.open(httppath, "wb") { |f| f.puts "Content originally on disk\n" }
          # make sure the mtime is not "right now", lest we get a race
          FileUtils.touch httppath, mtime: Time.parse("Sun, 22 Mar 2015 22:57:43 GMT")
          catalog.add_resource resource
          catalog.apply
          expect(Puppet::FileSystem.exist?(httppath)).to be_truthy
          expect(File.read(httppath)).to eq "Content via HTTP\n"
        end

        it "should fetch if mtime is older on disk" do
          File.open(httppath, "wb") { |f| f.puts "Content originally on disk\n" }
          # fixture has Last-Modified: Sun, 22 Mar 2015 22:25:34 GMT
          FileUtils.touch httppath, mtime: Time.parse("Sun, 22 Mar 2015 22:22:34 GMT")
          catalog.add_resource resource
          catalog.apply
          expect(Puppet::FileSystem.exist?(httppath)).to be_truthy
          expect(File.read(httppath)).to eq "Content via HTTP\n"
        end

        it "should not update if mtime is newer on disk" do
          File.open(httppath, "wb") { |f| f.puts "Content via HTTP\n" }
          mtime = File.stat(httppath).mtime
          catalog.add_resource resource
          catalog.apply
          expect(Puppet::FileSystem.exist?(httppath)).to be_truthy
          expect(File.read(httppath)).to eq "Content via HTTP\n"
          expect(File.stat(httppath).mtime).to eq mtime
        end
      end

      context "using md5", :vcr => true do
        let(:resource) do
          described_class.new(
            :path   => httppath,
            :ensure => :file,
            :source => http_source,
            :backup => false,
          )
        end

        it "should fetch if not on the local disk" do
          catalog.add_resource resource
          catalog.apply
          expect(Puppet::FileSystem.exist?(httppath)).to be_truthy
          expect(File.read(httppath)).to eq "Content via HTTP\n"
        end

        it "should update if content differs on disk" do
          File.open(httppath, "wb") { |f| f.puts "Content originally on disk\n" }
          catalog.add_resource resource
          catalog.apply
          expect(Puppet::FileSystem.exist?(httppath)).to be_truthy
          expect(File.read(httppath)).to eq "Content via HTTP\n"
        end

        it "should not update if content on disk is up-to-date" do
          File.open(httppath, "wb") { |f| f.puts "Content via HTTP\n" }
          disk_mtime = Time.parse("Sun, 22 Mar 2015 22:22:34 GMT")
          FileUtils.touch httppath, mtime: disk_mtime
          catalog.add_resource resource
          catalog.apply
          expect(Puppet::FileSystem.exist?(httppath)).to be_truthy
          expect(File.read(httppath)).to eq "Content via HTTP\n"
          expect(File.stat(httppath).mtime).to eq disk_mtime
        end

      end
    end

    describe "on Windows systems", :if => Puppet::Util::Platform.windows? do
      def expects_sid_granted_full_access_explicitly(path, sid)
        inherited_ace = Puppet::Util::Windows::AccessControlEntry::INHERITED_ACE

        aces = get_aces_for_path_by_sid(path, sid)
        expect(aces).not_to be_empty

        aces.each do |ace|
          expect(ace.mask).to eq(Puppet::Util::Windows::File::FILE_ALL_ACCESS)
          expect(ace.flags & inherited_ace).not_to eq(inherited_ace)
        end
      end

      def expects_system_granted_full_access_explicitly(path)
        expects_sid_granted_full_access_explicitly(path, @sids[:system])
      end

      def expects_at_least_one_inherited_ace_grants_full_access(path, sid)
        inherited_ace = Puppet::Util::Windows::AccessControlEntry::INHERITED_ACE

        aces = get_aces_for_path_by_sid(path, sid)
        expect(aces).not_to be_empty

        expect(aces.any? do |ace|
          ace.mask == Puppet::Util::Windows::File::FILE_ALL_ACCESS &&
            (ace.flags & inherited_ace) == inherited_ace
        end).to be_truthy
      end

      def expects_at_least_one_inherited_system_ace_grants_full_access(path)
        expects_at_least_one_inherited_ace_grants_full_access(path, @sids[:system])
      end

      describe "when processing SYSTEM ACEs" do
        before do
          @sids = {
            :current_user => Puppet::Util::Windows::ADSI::User.current_user_sid.sid,
            :system => Puppet::Util::Windows::SID::LocalSystem,
            :users => Puppet::Util::Windows::SID::BuiltinUsers,
            :power_users => Puppet::Util::Windows::SID::PowerUsers,
            :none => Puppet::Util::Windows::SID::Nobody
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

          describe "when permissions are not insync?" do
            before :each do
              @file[:owner] = @sids[:none]
              @file[:group] = @sids[:none]
            end

            it "preserves the inherited SYSTEM ACE for an existing file" do
              FileUtils.touch(path)

              expects_at_least_one_inherited_system_ace_grants_full_access(path)

              catalog.apply

              expects_at_least_one_inherited_system_ace_grants_full_access(path)
            end

            it "applies the inherited SYSTEM ACEs for a new file" do
              catalog.apply

              expects_at_least_one_inherited_system_ace_grants_full_access(path)
            end
          end

          describe "created with SYSTEM as the group" do
            before :each do
              @file[:owner] = @sids[:users]
              @file[:group] = @sids[:system]
              @file[:mode] = '0644'

              catalog.apply
            end

            it "prepends SYSTEM ace when changing group from system to power users" do
              @file[:group] = @sids[:power_users]
              catalog.apply

              system_aces = get_aces_for_path_by_sid(path, @sids[:system])
              expect(system_aces.size).to eq(1)
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

          describe "when permissions are not insync?" do
            before :each do
              @directory[:owner] = @sids[:none]
              @directory[:group] = @sids[:none]
            end

            it "preserves the inherited SYSTEM ACEs for an existing directory" do
              FileUtils.mkdir(dir)

              expects_at_least_one_inherited_system_ace_grants_full_access(dir)

              catalog.apply

              expects_at_least_one_inherited_system_ace_grants_full_access(dir)
            end

            it "applies the inherited SYSTEM ACEs for a new directory" do
              catalog.apply

              expects_at_least_one_inherited_system_ace_grants_full_access(dir)
            end

            describe "created with SYSTEM as the group" do
              before :each do
                @directory[:owner] = @sids[:users]
                @directory[:group] = @sids[:system]
                @directory[:mode] = '0644'

                catalog.apply
              end

              it "prepends SYSTEM ace when changing group from system to power users" do
                @directory[:group] = @sids[:power_users]
                catalog.apply

                system_aces = get_aces_for_path_by_sid(dir, @sids[:system])
                expect(system_aces.size).to eq(1)
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
      expect(File.read(@copiedfile)).to eq('funtest')
    end

    it "should not purge managed, local files" do
      expect(File.read(@localfile)).to eq('rahtest')
    end

    it "should purge files that are neither remote nor otherwise managed" do
      expect(Puppet::FileSystem.exist?(@purgee)).to be_falsey
    end
  end

  describe "when using validate_cmd" do
    test_cmd = '/bin/test'
    if Puppet.runtime[:facter].value('os.family') == 'Debian'
      test_cmd = '/usr/bin/test'
    end

    if Puppet.runtime[:facter].value('os.name') == 'Darwin'
      stat_cmd = "stat -f '%Lp'"
    else
      stat_cmd = "stat --format=%a"
    end

    it "sets the default mode of the temporary file to '0644'", :unless => Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
      catalog.add_resource(described_class.new(:path => path, :content => "foo",
                                               :validate_replacement => '^',
                                               :validate_cmd => %Q{
                                               echo "The permissions of the file ($(#{stat_cmd} ^)) should equal 644";
                                               #{test_cmd} "644" == "$(#{stat_cmd} ^)"
                                               }))
      report = catalog.apply.report
      expect(report.resource_statuses["File[#{path}]"].events.first.message).to match(/defined content as '{sha256}/)
      expect(report.resource_statuses["File[#{path}]"]).not_to be_failed
      expect(Puppet::FileSystem.exist?(path)).to be_truthy
    end

    it "should change the permissions of the temp file to match the final file permissions", :unless => Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby?do
      catalog.add_resource(described_class.new(:path => path, :content => "foo",
                                               :mode => '0555',
                                               :validate_replacement => '^',
                                               :validate_cmd => %Q{
                                               echo "The permissions of the file ($(#{stat_cmd} ^)) should equal 555";
                                               #{test_cmd} "555" == "$(#{stat_cmd} ^)"
                                               }))
      report = catalog.apply.report
      expect(report.resource_statuses["File[#{path}]"].events.first.message).to match(/defined content as '{sha256}/)
      expect(report.resource_statuses["File[#{path}]"]).not_to be_failed
      expect(Puppet::FileSystem.exist?(path)).to be_truthy
    end

    it "should fail the file resource if command fails" do
      catalog.add_resource(described_class.new(:path => path, :content => "foo", :validate_cmd => "/usr/bin/env false"))
      expect(Puppet::Util::Execution).to receive(:execute).with("/usr/bin/env false", {:combine => true, :failonfail => true}).and_raise(Puppet::ExecutionFailure, "Failed")
      report = catalog.apply.report
      expect(report.resource_statuses["File[#{path}]"]).to be_failed
      expect(Puppet::FileSystem.exist?(path)).to be_falsey
    end

    it "should succeed the file resource if command succeeds" do
      catalog.add_resource(described_class.new(:path => path, :content => "foo", :validate_cmd => "/usr/bin/env true"))
      expect(Puppet::Util::Execution).to receive(:execute)
        .with("/usr/bin/env true", {:combine => true, :failonfail => true})
        .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
      report = catalog.apply.report
      expect(report.resource_statuses["File[#{path}]"]).not_to be_failed
      expect(Puppet::FileSystem.exist?(path)).to be_truthy
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

  describe "copying a file that is a link to a file", :if => Puppet.features.manages_symlinks? do
    let(:target) { tmpfile('target') }
    let(:link) { tmpfile('link') }
    let(:copy) { tmpfile('copy') }
    it "should copy the target of the link if :links => follow" do
      catalog.add_resource described_class.new(
        :name => target,
        :ensure => "present",
        :content => "Jenny I got your number / I need to make you mine")
      catalog.add_resource described_class.new(
        :name => link,
        :ensure => "link",
        :target => target)
      catalog.add_resource described_class.new(
        :name => copy,
        :ensure => "present",
        :source => link,
        :links => "follow")
      catalog.apply
      expect(Puppet::FileSystem).to be_file(copy)
      expect(File.read(target)).to eq(File.read(copy))
    end

    it "should copy the link itself if :links => manage" do
      catalog.add_resource described_class.new(
        :name => target,
        :ensure => "present",
        :content => "Jenny I got your number / I need to make you mine")
      catalog.add_resource described_class.new(
        :name => link,
        :ensure => "link",
        :target => target)
      catalog.add_resource described_class.new(
        :name => copy,
        :ensure => "present",
        :source => link,
        :links => "manage")
      catalog.apply
      expect(Puppet::FileSystem).to be_symlink(copy)
      expect(File.read(link)).to eq(File.read(copy))
    end
  end

  describe "copying a file that is a link to a directory", :if => Puppet.features.manages_symlinks? do
    let(:target) { tmpdir('target') }
    let(:link) { tmpfile('link') }
    let(:copy) { tmpfile('copy') }
    context "when the recurse attribute is false" do
      it "should copy the top-level directory if :links => follow" do
        catalog.add_resource described_class.new(
          :name => target,
          :ensure => "directory")
        catalog.add_resource described_class.new(
          :name => link,
          :ensure => "link",
          :target => target)
        catalog.add_resource described_class.new(
          :name => copy,
          :ensure => "present",
          :source => link,
          :recurse => false,
          :links => "follow")
        catalog.apply
        expect(Puppet::FileSystem).to be_directory(copy)
      end

      it "should copy the link itself if :links => manage" do
        catalog.add_resource described_class.new(
          :name => target,
          :ensure => "directory")
        catalog.add_resource described_class.new(
          :name => link,
          :ensure => "link",
          :target => target)
        catalog.add_resource described_class.new(
          :name => copy,
          :ensure => "present",
          :source => link,
          :recurse => false,
          :links => "manage")
        catalog.apply
        expect(Puppet::FileSystem).to be_symlink(copy)
        expect(Dir.entries(link)).to eq(Dir.entries(copy))
      end
    end

    context "and the recurse attribute is true" do
      it "should recursively copy the directory if :links => follow" do
        catalog.add_resource described_class.new(
          :name => target,
          :ensure => "directory")
        catalog.add_resource described_class.new(
          :name => link,
          :ensure => "link",
          :target => target)
        catalog.add_resource described_class.new(
          :name => copy,
          :ensure => "present",
          :source => link,
          :recurse => true,
          :links => "follow")
        catalog.apply
        expect(Puppet::FileSystem).to be_directory(copy)
        expect(Dir.entries(target)).to eq(Dir.entries(copy))
      end

      it "should copy the link itself if :links => manage" do
        catalog.add_resource described_class.new(
          :name => target,
          :ensure => "directory")
        catalog.add_resource described_class.new(
          :name => link,
          :ensure => "link",
          :target => target)
        catalog.add_resource described_class.new(
          :name => copy,
          :ensure => "present",
          :source => link,
          :recurse => true,
          :links => "manage")
        catalog.apply
        expect(Puppet::FileSystem).to be_symlink(copy)
        expect(Dir.entries(link)).to eq(Dir.entries(copy))
      end
    end
  end

  [:md5, :sha256, :md5lite, :sha256lite, :sha384, :sha512, :sha224].each do |checksum|
    describe "setting checksum_value explicitly with checksum #{checksum}" do
      let(:path) { tmpfile('target') }
      let(:contents) { 'yay' }

      before :each do
        @options = {
          :path           => path,
          :ensure         => :file,
          :checksum       => checksum,
          :checksum_value => Puppet::Util::Checksums.send(checksum, contents)
        }
      end

      def verify_file(transaction)
        status = transaction.report.resource_statuses["File[#{path}]"]
        expect(status).not_to be_failed
        expect(Puppet::FileSystem).to be_file(path)
        expect(File.read(path)).to eq(contents)
        status
      end

      [:source, :content].each do |prop|
        context "from #{prop}" do
          let(:source) { tmpfile_with_contents("source_default_values", contents) }

          before :each do
            @options[prop] = {:source => source, :content => contents}[prop]
          end

          it "should create a new file" do
            catalog.add_resource described_class.new(@options)
            status = verify_file catalog.apply
            expect(status).to be_changed
          end

          it "should overwrite an existing file" do
            File.open(path, "w") { |f| f.write('bar') }
            catalog.add_resource described_class.new(@options)
            status = verify_file catalog.apply
            expect(status).to be_changed
          end

          it "should not overwrite the same file" do
            File.open(path, "w") { |f| f.write(contents) }
            catalog.add_resource described_class.new(@options)
            status = verify_file catalog.apply
            expect(status).to_not be_changed
          end

          it "should not create a file when ensuring absent" do
            @options[:ensure] = :absent
            catalog.add_resource described_class.new(@options)
            catalog.apply
            expect(Puppet::FileSystem).to_not be_file(path)
          end
        end
      end
    end
  end

  describe "setting checksum_value explicitly with checksum mtime" do
    let(:path) { tmpfile('target_dir') }
    let(:time) { Time.now }

    before :each do
      @options = {
        :path           => path,
        :ensure         => :directory,
        :checksum       => :mtime,
        :checksum_value => time
      }
    end

    it "should create a new directory" do
      catalog.add_resource described_class.new(@options)
      status = catalog.apply.report.resource_statuses["File[#{path}]"]
      expect(status).not_to be_failed
      expect(status).to be_changed
      expect(Puppet::FileSystem).to be_directory(path)
    end

    it "should not update mtime on an old directory" do
      disk_mtime = Time.parse("Sun, 22 Mar 2015 22:22:34 GMT")
      FileUtils.mkdir_p path
      FileUtils.touch path, mtime: disk_mtime
      status = catalog.apply.report.resource_statuses["File[#{path}]"]
      expect(status).to be_nil
      expect(Puppet::FileSystem).to be_directory(path)
      expect(File.stat(path).mtime).to eq(disk_mtime)
    end
  end
end
