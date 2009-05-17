#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/autoload'

describe Puppet::Util::Autoload do
    before do
        @autoload = Puppet::Util::Autoload.new("foo", "tmp")

        @autoload.stubs(:eachdir).yields "/my/dir"
    end

    it "should use the Cacher module" do
        Puppet::Util::Autoload.ancestors.should be_include(Puppet::Util::Cacher)
    end

    it "should use a ttl of 15 for the search path" do
        Puppet::Util::Autoload.attr_ttl(:searchpath).should == 15
    end

    describe "when building the search path" do
        it "should collect all of the plugins and lib directories that exist in the current environment's module path" do
            Puppet.settings.expects(:value).with(:environment).returns "foo"
            Puppet.settings.expects(:value).with(:modulepath, "foo").returns %w{/a /b /c}
            Dir.expects(:entries).with("/a").returns %w{/a/one /a/two}
            Dir.expects(:entries).with("/b").returns %w{/b/one /b/two}

            FileTest.stubs(:directory?).returns false
            FileTest.expects(:directory?).with("/a").returns true
            FileTest.expects(:directory?).with("/b").returns true
            %w{/a/one/plugins /a/two/lib /b/one/plugins /b/two/lib}.each do |d|
                FileTest.expects(:directory?).with(d).returns true
            end

            @autoload.module_directories.should == %w{/a/one/plugins /a/two/lib /b/one/plugins /b/two/lib}
        end

        it "should include the module directories, the Puppet libdir, and all of the Ruby load directories" do
            @autoload.expects(:module_directories).returns %w{/one /two}
            @autoload.search_directories.should == ["/one", "/two", Puppet[:libdir], $:].flatten
        end

        it "should include in its search path all of the search directories that have a subdirectory matching the autoload path" do
            @autoload = Puppet::Util::Autoload.new("foo", "loaddir")
            @autoload.expects(:search_directories).returns %w{/one /two /three}
            FileTest.expects(:directory?).with("/one/loaddir").returns true
            FileTest.expects(:directory?).with("/two/loaddir").returns false
            FileTest.expects(:directory?).with("/three/loaddir").returns true
            @autoload.searchpath.should == ["/one/loaddir", "/three/loaddir"]
        end
    end

    describe "when loading a file" do
        before do
            @autoload.stubs(:searchpath).returns %w{/a}
        end

        [RuntimeError, LoadError, SyntaxError].each do |error|
            it "should not die an if a #{error.to_s} exception is thrown" do
                FileTest.stubs(:directory?).returns true
                FileTest.stubs(:exist?).returns true

                Kernel.expects(:load).raises error

                @autoload.load("foo")
            end
        end
    end

    describe "when loading all files" do
        before do
            @autoload.stubs(:searchpath).returns %w{/a}
            Dir.stubs(:glob).returns "file.rb"
        end

        [RuntimeError, LoadError, SyntaxError].each do |error|
            it "should not die an if a #{error.to_s} exception is thrown" do
                Kernel.expects(:require).raises error

                lambda { @autoload.loadall }.should_not raise_error
            end
        end
    end
end
