#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Type.type(:file) do
    before do
        @path = Tempfile.new("puppetspec")
        @path.close!()
        @path = @path.path
        @file = Puppet::Type::File.create(:name => @path)
    end

    describe "when used with content and replace=>false" do
        before do
            @file[:content] = "foo"
            @file[:replace] = false
        end

        it "should be insync if the file exists and the content is different" do
            File.open(@path, "w") do |f| f.puts "bar" end
            @file.property(:content).insync?("bar").should be_true
        end

        it "should be insync if the file exists and the content is right" do
            File.open(@path, "w") do |f| f.puts "foo" end
            @file.property(:content).insync?("foo").should be_true
        end

        it "should not be insync if the file does not exist" do
            @file.property(:content).insync?(:nil).should be_false
        end
    end

    describe "when managing links" do
        require 'puppettest/support/assertions'
        include PuppetTest
        require 'tempfile'

        before do
            @basedir = tempfile
            Dir.mkdir(@basedir)
            @file = File.join(@basedir, "file")
            @link = File.join(@basedir, "link")

            File.open(@file, "w", 0644) { |f| f.puts "yayness"; f.flush }
            File.symlink(@file, @link)

            @resource = Puppet.type(:file).create(
                :path => @link,
                :mode => "755"
            )
            @catalog = Puppet::Node::Catalog.new
            @catalog.add_resource @resource
        end

        after do
            remove_tmp_files
        end

        it "should default to managing the link" do
            @catalog.apply
            # I convert them to strings so they display correctly if there's an error.
            ("%o" % (File.stat(@file).mode & 007777)).should == "%o" % 0644
        end

        it "should be able to follow links" do
            @resource[:links] = :follow
            @catalog.apply

            ("%o" % (File.stat(@file).mode & 007777)).should == "%o" % 0755
        end
    end

    describe "when flushing" do
        it "should flush all properties that respond to :flush" do
            @resource = Puppet.type(:file).create(:path => "/foo/bar", :source => "/bar/foo")
            @resource.property(:source).expects(:flush)
            @resource.flush
        end
    end

    it "should have a method for performing recursion" do
        @file.must respond_to(:perform_recursion)
    end

    describe "when executing a recursive search" do
        it "should use Metadata to do its recursion" do
            Puppet::FileServing::Metadata.expects(:search)
            @file.perform_recursion(@file[:path])
        end

        it "should use its path as the key to the search" do
            Puppet::FileServing::Metadata.expects(:search).with { |key, options| key = @file[:path] }
            @file.perform_recursion(@file[:path])
        end

        it "should return the results of the metadata search" do
            Puppet::FileServing::Metadata.expects(:search).returns "foobar"
            @file.perform_recursion(@file[:path]).should == "foobar"
        end

        it "should pass its recursion value to the search" do
            @file[:recurse] = 10
            Puppet::FileServing::Metadata.expects(:search).with { |key, options| options[:recurse] == 10 }
            @file.perform_recursion(@file[:path])
        end

        it "should configure the search to ignore or manage links" do
            @file[:links] = :manage
            Puppet::FileServing::Metadata.expects(:search).with { |key, options| options[:links] == :manage }
            @file.perform_recursion(@file[:path])
        end

        it "should pass its 'ignore' setting to the search if it has one" do
            @file[:ignore] = %w{.svn CVS}
            Puppet::FileServing::Metadata.expects(:search).with { |key, options| options[:ignore] == %w{.svn CVS} }
            @file.perform_recursion(@file[:path])
        end
    end

    it "should have a method for performing local recursion" do
        @file.must respond_to(:recurse_local)
    end

    it "should pass its path to the :perform_recursion method to do local recursion" do
        @file.expects(:perform_recursion).with(@file[:path]).returns "foobar"
        @file.recurse_local.should == "foobar"
    end

    it "should have a method for performing link recursion" do
        @file.must respond_to(:recurse_link)
    end

    it "should pass its target to the :perform_recursion method to do link recursion" do
        @file[:target] = "mylinks"
        @file.expects(:perform_recursion).with("mylinks").returns "foobar"
        @file.recurse_link.should == "foobar"
    end

    it "should have a method for performing remote recursion" do
        @file.must respond_to(:recurse_remote)
    end

    it "should pass its source to the :perform_recursion method to do source recursion" do
        data = Puppet::FileServing::Metadata.new("/whatever", :relative_path => "foobar")
        @file[:source] = "puppet://foo/bar"
        @file.expects(:perform_recursion).with("puppet://foo/bar").returns [data]
        @file.recurse_remote.should == [data]
    end

    it "should set the source of each returned file to the searched-for URI plus the found relative path" do
        metadata = stub 'metadata', :relative_path => "foobar"
        metadata.expects(:source=).with "puppet://foo/bar/foobar"
        @file[:source] = "puppet://foo/bar"
        @file.expects(:perform_recursion).with("puppet://foo/bar").returns [metadata]
        @file.recurse_remote.should == [metadata]
    end

    describe "when multiple sources are provided" do
        describe "and :sourceselect is set to :first" do
            it "should return the results for the first source to return any values" do
                data = Puppet::FileServing::Metadata.new("/whatever", :relative_path => "foobar")
                @file[:source] = %w{/one /two /three /four}
                @file.expects(:perform_recursion).with("/one").returns nil
                @file.expects(:perform_recursion).with("/two").returns []
                @file.expects(:perform_recursion).with("/three").returns [data]
                @file.expects(:perform_recursion).with("/four").never
                @file.recurse_remote.should == [data]
            end
        end

        describe "and :sourceselect is set to :all" do
            before do
                @file[:sourceselect] = :all
            end

            it "should return every found file that is not in a previous source" do
                klass = Puppet::FileServing::Metadata
                @file[:source] = %w{/one /two /three /four}

                one = [klass.new("/one", :relative_path => "a")]
                @file.expects(:perform_recursion).with("/one").returns one

                two = [klass.new("/two", :relative_path => "a"), klass.new("/two", :relative_path => "b")]
                @file.expects(:perform_recursion).with("/two").returns two

                three = [klass.new("/three", :relative_path => "a"), klass.new("/three", :relative_path => "c")]
                @file.expects(:perform_recursion).with("/three").returns three

                @file.expects(:perform_recursion).with("/four").returns []

                @file.recurse_remote.should == [one[0], two[1], three[1]]
            end
        end
    end

    it "should recurse during eval_generate if recursion is enabled" do
        @file.expects(:recurse?).returns true
        @file.expects(:recurse).returns "foobar"
        @file.eval_generate.should == "foobar"
    end

    it "should not recurse during eval_generate if recursion is disabled" do
        @file.expects(:recurse?).returns false
        @file.expects(:recurse).never
        @file.eval_generate.should be_nil
    end

    describe "when recursing" do
        before do
            @file[:recurse] = true
            @metadata = Puppet::FileServing::Metadata
        end

        describe "and a source is set" do
            before { @file[:source] = "/my/source" }

            it "should use recurse_remote" do
                @file.stubs(:recurse_local).returns []
                @file.expects(:recurse_remote)
                @file.recurse
            end

            it "should create a new file resource for each remote file"

            it "should set the source for each new file resource"

            it "should copy the metadata to the new file's source property so the file does not have to requery the remote system for metadata"

            describe "and purging is enabled" do
                it "should configure each file not on the remote system to be removed"
            end
        end

        describe "and a target is set" do
            before { @file[:target] = "/link/target" }

            it "should use recurse_link" do
                @file.stubs(:recurse_local).returns []
                @file.expects(:recurse_link).returns []
                @file.recurse
            end

            it "should return a new file resource for each link destination found"

            it "should set the target for each new file resource"
        end

        it "should use recurse_local" do
            @file.expects(:recurse_local).returns []
            @file.recurse
        end

        it "should attempt to turn each found file into a child resource" do
            a = @metadata.new("/foo", :relative_path => "a")
            @file.expects(:recurse_local).returns [a]
            @file.expects(:newchild).with("a")

            @file.recurse
        end

        it "should not return nil for those files that could not be turned into children" do
            a = @metadata.new("/foo", :relative_path => "a")
            b = @metadata.new("/foo", :relative_path => "b")
            @file.expects(:recurse_local).returns [a, b]
            @file.expects(:newchild).with("a").returns "A"
            @file.expects(:newchild).with("b").returns nil

            @file.recurse.should == ["A"]
        end
    end
end
