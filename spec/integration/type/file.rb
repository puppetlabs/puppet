#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Type.type(:file), "when recursing" do
    def mkdir
    end

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

    it "should be able to recursively set properties on existing files" do
        @path = Tempfile.new("file_integration_tests")
        @path.close!()
        @path = @path.path

        build_path(@path)

        @file = Puppet::Type::File.create(:name => @path, :mode => 0644, :recurse => true)

        @catalog = Puppet::Node::Catalog.new
        @catalog.add_resource @file

        @catalog.apply

        @dirs.each do |path|
            (File.stat(path).mode & 007777).should == 0755
        end

        @files.each do |path|
            (File.stat(path).mode & 007777).should == 0644
        end
    end
end
