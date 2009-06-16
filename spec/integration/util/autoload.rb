#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/autoload'

class AutoloadIntegrator
    @things = []
    def self.newthing(name)
        @things << name
    end

    def self.thing?(name)
        @things.include? name
    end

    def self.clear
        @things.clear
    end
end

require 'puppet_spec/files'

describe Puppet::Util::Autoload do
    include PuppetSpec::Files

    def mkfile(name, path)
        # Now create a file to load
        File.open(path, "w") do |f|
            f.puts %{
AutoloadIntegrator.newthing(:#{name.to_s})
            }
        end
    end

    def mk_loader(name, path)
        dir = tmpfile(name + path)
        $: << dir

        Dir.mkdir(dir)

        rbdir = File.join(dir, path.to_s)

        Dir.mkdir(rbdir)

        loader = Puppet::Util::Autoload.new(name, path)
        return rbdir, loader
    end

    it "should make instances available by the loading class" do
        loader = Puppet::Util::Autoload.new("foo", "bar")
        Puppet::Util::Autoload["foo"].should == loader
    end

    it "should not fail when asked to load a missing file" do
        Puppet::Util::Autoload.new("foo", "bar").load(:eh).should be_false
    end

    it "should load and return true when it successfully loads a file" do
        dir, loader = mk_loader("foo", "bar")
        path = File.join(dir, "mything.rb")
        mkfile(:mything, path)
        loader.load(:mything).should be_true
        loader.should be_loaded(:mything)
        AutoloadIntegrator.should be_thing(:mything)
    end

    it "should consider a file loaded when asked for the name without an extension" do
        dir, loader = mk_loader("foo", "bar")
        path = File.join(dir, "noext.rb")
        mkfile(:noext, path)
        loader.load(:noext)
        loader.should be_loaded(:noext)
    end

    it "should consider a file loaded when asked for the name with an extension" do
        dir, loader = mk_loader("foo", "bar")
        path = File.join(dir, "withext.rb")
        mkfile(:noext, path)
        loader.load(:withext)
        loader.should be_loaded("withext.rb")
    end

    it "should register the fact that the instance is loaded with the Autoload base class" do
        dir, loader = mk_loader("foo", "bar")
        path = File.join(dir, "baseload.rb")
        mkfile(:baseload, path)
        loader.load(:baseload)
        Puppet::Util::Autoload.should be_loaded("bar/withext.rb")
    end
end
