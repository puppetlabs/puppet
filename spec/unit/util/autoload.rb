#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/autoload'

describe Puppet::Util::Autoload do
    before do
        @autoload = Puppet::Util::Autoload.new("foo", "tmp")

        @autoload.stubs(:eachdir).yields "/my/dir"
    end

    describe "when loading a file" do
        [RuntimeError, LoadError, SyntaxError].each do |error|
            it "should not die an if a #{error.to_s} exception is thrown" do
                FileTest.stubs(:exists?).returns true

                Kernel.expects(:load).raises error

                lambda { @autoload.load("foo") }.should_not raise_error
            end
        end
    end

    describe "when loading all files" do
        before do
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
