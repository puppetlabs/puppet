#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet_spec/files'

describe Puppet::Type.type(:file) do
    include PuppetSpec::Files

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
                    File.open(ffile, "w") { |f| f.puts "test %s" % file }
                    File.chmod(0640, ffile)
                end
            end
        end

        it "should be able to recurse over a nonexistent file" do
            @path = tmpfile("file_integration_tests")

            @file = Puppet::Type::File.new(:name => @path, :mode => 0644, :recurse => true)

            @catalog = Puppet::Resource::Catalog.new
            @catalog.add_resource @file

            lambda { @file.eval_generate }.should_not raise_error
        end

        it "should be able to recursively set properties on existing files" do
            @path = tmpfile("file_integration_tests")

            build_path(@path)

            @file = Puppet::Type::File.new(:name => @path, :mode => 0644, :recurse => true)

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

            @file = Puppet::Type::File.new(:name => dest, :target => source, :recurse => true, :ensure => :link)

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

            @file = Puppet::Type::File.new(:name => dest, :source => source, :recurse => true)

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

            @file = Puppet::Type::File.new(:name => @dest, :source => @source, :recurse => true)

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
                @catalog.relationship_graph.should be_edge(@file, one)

                two = @catalog.resource(:file, File.join(@dest, "two"))
                @catalog.relationship_graph.should be_edge(@file, two)
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

            file = Puppet::Type::File.new(:path => dest, :source => source)

            catalog = Puppet::Resource::Catalog.new
            catalog.add_resource file

            catalog.apply

            File.read(dest).should == "foo"
        end

        it "should be able to notice changed files in the same process" do
            source = tmpfile("source")
            dest = tmpfile("dest")

            File.open(source, "w") { |f| f.print "foo" }

            file = Puppet::Type::File.new(:name => dest, :source => source)

            catalog = Puppet::Resource::Catalog.new
            catalog.add_resource file
            catalog.apply

            File.read(dest).should == "foo"

            # Now change the file
            File.open(source, "w") { |f| f.print "bar" }
            catalog.apply

            # And make sure it's changed
            File.read(dest).should == "bar"
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
            :name => dest,
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
            :name => dest,
            :ensure => "file",
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
            :name => dest,
            :ensure => :absent,
            :source => source
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
                :title => "localfile",
                :path => @localfile,
                :content => "rahtest\n",
                :ensure => :file,
                :backup => false
            )

            @destobj = Puppet::Type.newfile(:title => "destdir", :path => @destdir,
                                        :source => @sourcedir,
                                        :backup => false,
                                        :purge => true,
                                        :recurse => true)

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
