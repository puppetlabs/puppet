#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Type.type(:file) do
    before do
        @path = Tempfile.new("puppetspec")
        @path.close!()
        @path = @path.path
        @file = Puppet::Type::File.create(:name => @path)

        @catalog = mock 'catalog'
        @catalog.stub_everything
        @file.catalog = @catalog
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

        it "should use the provided path as the key to the search" do
            Puppet::FileServing::Metadata.expects(:search).with { |key, options| key == "/foo" }
            @file.perform_recursion("/foo")
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

    describe "when doing local recursion" do
        before do
            @metadata = stub 'metadata', :relative_path => "my/file"
        end

        it "should pass its to the :perform_recursion method" do
            @file.expects(:perform_recursion).with(@file[:path]).returns [@metadata]
            @file.stubs(:newchild)
            @file.recurse_local
        end

        it "should create a new child resource with each generated metadata instance's relative path" do
            @file.expects(:perform_recursion).returns [@metadata]
            @file.expects(:newchild).with(@metadata.relative_path).returns "fiebar"
            @file.recurse_local
        end

        it "should not create a new child resource for the '.' directory" do
            @metadata.stubs(:relative_path).returns "."

            @file.expects(:perform_recursion).returns [@metadata]
            @file.expects(:newchild).never
            @file.recurse_local
        end

        it "should return a hash of the created resources with the relative paths as the hash keys" do
            @file.expects(:perform_recursion).returns [@metadata]
            @file.expects(:newchild).with("my/file").returns "fiebar"
            @file.recurse_local.should == {"my/file" => "fiebar"}
        end
    end

    it "should have a method for performing link recursion" do
        @file.must respond_to(:recurse_link)
    end

    describe "when doing link recursion" do
        before do
            @first = stub 'first', :relative_path => "first", :full_path => "/my/first", :ftype => "directory"
            @second = stub 'second', :relative_path => "second", :full_path => "/my/second", :ftype => "file"

            @resource = stub 'file', :[]= => nil
        end

        it "should pass its target to the :perform_recursion method" do
            @file[:target] = "mylinks"
            @file.expects(:perform_recursion).with("mylinks").returns [@first]
            @file.stubs(:newchild).returns @resource
            @file.recurse_link({})
        end

        it "should create a new child resource for each generated metadata instance's relative path that doesn't already exist in the children hash" do
            @file.expects(:perform_recursion).returns [@first, @second]
            @file.expects(:newchild).with(@first.relative_path).returns @resource
            @file.recurse_link("second" => @resource)
        end

        it "should not create a new child resource for paths that already exist in the children hash" do
            @file.expects(:perform_recursion).returns [@first]
            @file.expects(:newchild).never
            @file.recurse_link("first" => @resource)
        end

        it "should set the target to the full path of discovered file and set :ensure to :link if the file is not a directory" do
            file = stub 'file'
            file.expects(:[]=).with(:target, "/my/second")
            file.expects(:[]=).with(:ensure, :link)

            @file.stubs(:perform_recursion).returns [@first, @second]
            @file.recurse_link("first" => @resource, "second" => file)
        end

        it "should :ensure to :directory if the file is a directory" do
            file = stub 'file'
            file.expects(:[]=).with(:ensure, :directory)

            @file.stubs(:perform_recursion).returns [@first, @second]
            @file.recurse_link("first" => file, "second" => @resource)
        end

        it "should return a hash with both created and existing resources with the relative paths as the hash keys" do
            file = stub 'file', :[]= => nil

            @file.expects(:perform_recursion).returns [@first, @second]
            @file.stubs(:newchild).returns file
            @file.recurse_link("second" => @resource).should == {"second" => @resource, "first" => file}
        end
    end

    it "should have a method for performing remote recursion" do
        @file.must respond_to(:recurse_remote)
    end

    describe "when doing remote recursion" do
        before do
            @file[:source] = "puppet://foo/bar"

            @first = Puppet::FileServing::Metadata.new("/my", :relative_path => "first")
            @second = Puppet::FileServing::Metadata.new("/my", :relative_path => "second")

            @property = stub 'property', :metadata= => nil
            @resource = stub 'file', :[]= => nil, :property => @property
        end

        it "should pass its source to the :perform_recursion method" do
            data = Puppet::FileServing::Metadata.new("/whatever", :relative_path => "foobar")
            @file.expects(:perform_recursion).with("puppet://foo/bar").returns [data]
            @file.stubs(:newchild).returns @resource
            @file.recurse_remote({})
        end

        it "should set the source of each returned file to the searched-for URI plus the found relative path" do
            @first.expects(:source=).with File.join("puppet://foo/bar", @first.relative_path)
            @file.expects(:perform_recursion).returns [@first]
            @file.stubs(:newchild).returns @resource
            @file.recurse_remote({})
        end

        it "should create a new resource for any relative file paths that do not already have a resource" do
            @file.stubs(:perform_recursion).returns [@first]
            @file.expects(:newchild).with("first").returns @resource
            @file.recurse_remote({}).should == {"first" => @resource}
        end

        it "should not create a new resource for any relative file paths that do already have a resource" do
            @file.stubs(:perform_recursion).returns [@first]
            @file.expects(:newchild).never
            @file.recurse_remote("first" => @resource)
        end

        it "should set the source of each resource to the source of the metadata" do
            @file.stubs(:perform_recursion).returns [@first]
            @resource.expects(:[]=).with(:source, File.join("puppet://foo/bar", @first.relative_path))
            @file.recurse_remote("first" => @resource)
        end

        it "should store the metadata in the source property for each resource so the source does not have to requery the metadata" do
            @file.stubs(:perform_recursion).returns [@first]
            @resource.expects(:property).with(:source).returns @property
            
            @property.expects(:metadata=).with(@first)

            @file.recurse_remote("first" => @resource)
        end

        describe "and purging is enabled" do
            before do
                @file[:purge] = true
            end

            it "should configure each file not on the remote system to be removed" do
                @file.stubs(:perform_recursion).returns [@second]

                @resource.expects(:[]=).with(:ensure, :absent)

                @file.expects(:newchild).returns stub('secondfile', :[]= => nil, :property => @property)

                @file.recurse_remote("first" => @resource)
            end
        end

        describe "and multiple sources are provided" do
            describe "and :sourceselect is set to :first" do
                it "should create file instances for the results for the first source to return any values" do
                    data = Puppet::FileServing::Metadata.new("/whatever", :relative_path => "foobar")
                    @file[:source] = %w{/one /two /three /four}
                    @file.expects(:perform_recursion).with("/one").returns nil
                    @file.expects(:perform_recursion).with("/two").returns []
                    @file.expects(:perform_recursion).with("/three").returns [data]
                    @file.expects(:perform_recursion).with("/four").never
                    @file.expects(:newchild).with("foobar").returns @resource
                    @file.recurse_remote({})
                end
            end

            describe "and :sourceselect is set to :all" do
                before do
                    @file[:sourceselect] = :all
                end

                it "should return every found file that is not in a previous source" do
                    klass = Puppet::FileServing::Metadata
                    @file[:source] = %w{/one /two /three /four}
                    @file.stubs(:newchild).returns @resource

                    one = [klass.new("/one", :relative_path => "a")]
                    @file.expects(:perform_recursion).with("/one").returns one
                    @file.expects(:newchild).with("a").returns @resource

                    two = [klass.new("/two", :relative_path => "a"), klass.new("/two", :relative_path => "b")]
                    @file.expects(:perform_recursion).with("/two").returns two
                    @file.expects(:newchild).with("b").returns @resource

                    three = [klass.new("/three", :relative_path => "a"), klass.new("/three", :relative_path => "c")]
                    @file.expects(:perform_recursion).with("/three").returns three
                    @file.expects(:newchild).with("c").returns @resource

                    @file.expects(:perform_recursion).with("/four").returns []

                    @file.recurse_remote({})
                end
            end
        end
    end

    describe "when returning resources with :eval_generate" do
        before do
            @catalog = mock 'catalog'
            @catalog.stub_everything

            @graph = stub 'graph', :add_edge => nil
            @catalog.stubs(:relationship_graph).returns @graph

            @file.catalog = @catalog
            @file[:recurse] = true
        end

        it "should recurse if recursion is enabled" do
            resource = stub('resource', :[] => "resource")
            @file.expects(:recurse?).returns true
            @file.expects(:recurse).returns [resource]
            @file.eval_generate.should == [resource]
        end

        it "should not recurse if recursion is disabled" do
            @file.expects(:recurse?).returns false
            @file.expects(:recurse).never
            @file.eval_generate.should be_nil
        end

        it "should fail if no catalog is set" do
            @file.catalog = nil
            lambda { @file.eval_generate }.should raise_error(Puppet::DevError)
        end

        it "should skip resources that are already in the catalog" do
            foo = stub 'foo', :[] => "/foo"
            bar = stub 'bar', :[] => "/bar"
            bar2 = stub 'bar2', :[] => "/bar"

            @catalog.expects(:resource).with(:file, "/foo").returns nil
            @catalog.expects(:resource).with(:file, "/bar").returns bar2

            @file.expects(:recurse).returns [foo, bar]

            @file.eval_generate.should == [foo]
        end

        it "should add each resource to the catalog" do
            foo = stub 'foo', :[] => "/foo"
            bar = stub 'bar', :[] => "/bar"
            bar2 = stub 'bar2', :[] => "/bar"

            @catalog.expects(:add_resource).with(foo)
            @catalog.expects(:add_resource).with(bar)

            @file.expects(:recurse).returns [foo, bar]

            @file.eval_generate
        end

        it "should add a relationshp edge for each returned resource" do
            foo = stub 'foo', :[] => "/foo"

            @file.expects(:recurse).returns [foo]

            graph = mock 'graph'
            @catalog.stubs(:relationship_graph).returns graph

            graph.expects(:add_edge).with(@file, foo)

            @file.eval_generate
        end
    end

    describe "when recursing" do
        before do
            @file[:recurse] = true
            @metadata = Puppet::FileServing::Metadata
        end

        describe "and a source is set" do
            before { @file[:source] = "/my/source" }

            it "should pass the already-discovered resources to recurse_remote" do
                @file.stubs(:recurse_local).returns(:foo => "bar")
                @file.expects(:recurse_remote).with(:foo => "bar").returns []
                @file.recurse
            end
        end

        describe "and a target is set" do
            before { @file[:target] = "/link/target" }

            it "should use recurse_link" do
                @file.stubs(:recurse_local).returns(:foo => "bar")
                @file.expects(:recurse_link).with(:foo => "bar").returns []
                @file.recurse
            end
        end

        it "should use recurse_local" do
            @file.expects(:recurse_local).returns({})
            @file.recurse
        end

        it "should return the generated resources as an array sorted by file path" do
            one = stub 'one', :[] => "/one"
            two = stub 'two', :[] => "/one/two"
            three = stub 'three', :[] => "/three"
            @file.expects(:recurse_local).returns(:one => one, :two => two, :three => three)
            @file.recurse.should == [one, two, three]
        end

        describe "and making a new child resource" do
            it "should create an implicit resource using the provided relative path joined with the file's path" do
                path = File.join(@file[:path], "my/path")
                Puppet::Type.type(:file).expects(:create).with { |options| options[:implicit] == true and options[:path] == path }
                @file.newchild("my/path")
            end

            it "should copy most of the parent resource's 'should' values to the new resource" do
                @file.expects(:to_hash).returns :foo => "bar", :fee => "fum"
                Puppet::Type.type(:file).expects(:create).with { |options| options[:foo] == "bar" and options[:fee] == "fum" }
                @file.newchild("my/path")
            end

            it "should not copy the parent resource's parent" do
                @file.expects(:to_hash).returns :parent => "foo"
                Puppet::Type.type(:file).expects(:create).with { |options| ! options.include?(:parent) }
                @file.newchild("my/path")
            end

            it "should not copy the parent resource's recurse value" do
                @file.expects(:to_hash).returns :recurse => true
                Puppet::Type.type(:file).expects(:create).with { |options| ! options.include?(:recurse) }
                @file.newchild("my/path")
            end
        end
    end
end
