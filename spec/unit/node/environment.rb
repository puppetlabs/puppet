#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/node/environment'
require 'puppet/util/execution'

describe Puppet::Node::Environment do
    after do
        Puppet::Node::Environment.clear
    end

    it "should include the Cacher module" do
        Puppet::Node::Environment.ancestors.should be_include(Puppet::Util::Cacher)
    end
    
    it "should use the filetimeout for the ttl for the modulepath" do
        Puppet::Node::Environment.attr_ttl(:modulepath).should == Integer(Puppet[:filetimeout])
    end
    
    it "should use the filetimeout for the ttl for the module list" do
        Puppet::Node::Environment.attr_ttl(:modules).should == Integer(Puppet[:filetimeout])
    end

    it "should use the default environment if no name is provided while initializing an environment" do
        Puppet.settings.expects(:value).with(:environment).returns("one")
        Puppet::Node::Environment.new().name.should == :one
    end

    it "should treat environment instances as singletons" do
        Puppet::Node::Environment.new("one").should equal(Puppet::Node::Environment.new("one"))
    end

    it "should treat an environment specified as names or strings as equivalent" do
        Puppet::Node::Environment.new(:one).should equal(Puppet::Node::Environment.new("one"))
    end

    it "should return its name when converted to a string" do
        Puppet::Node::Environment.new(:one).to_s.should == "one"
    end

    it "should consider its module path to be the environment-specific modulepath setting" do
        FileTest.stubs(:directory?).returns true
        env = Puppet::Node::Environment.new("testing")
        module_path = %w{/one /two}.join(File::PATH_SEPARATOR)
        env.expects(:[]).with(:modulepath).returns module_path

        env.modulepath.should == %w{/one /two}
    end

    it "should prefix the value of the 'PUPPETLIB' environment variable to the module path if present" do
        FileTest.stubs(:directory?).returns true
        Puppet::Util::Execution.withenv("PUPPETLIB" => %w{/l1 /l2}.join(File::PATH_SEPARATOR)) do
            env = Puppet::Node::Environment.new("testing")
            module_path = %w{/one /two}.join(File::PATH_SEPARATOR)
            env.expects(:[]).with(:modulepath).returns module_path

            env.modulepath.should == %w{/l1 /l2 /one /two}
        end
    end

    it "should not return non-directories in the module path" do
        env = Puppet::Node::Environment.new("testing")
        module_path = %w{/one /two}.join(File::PATH_SEPARATOR)
        env.expects(:[]).with(:modulepath).returns module_path

        FileTest.expects(:directory?).with("/one").returns true
        FileTest.expects(:directory?).with("/two").returns false

        env.modulepath.should == %w{/one}
    end

    it "should use the current working directory to fully-qualify unqualified paths" do
        FileTest.stubs(:directory?).returns true
        env = Puppet::Node::Environment.new("testing")
        module_path = %w{/one two}.join(File::PATH_SEPARATOR)
        env.expects(:[]).with(:modulepath).returns module_path

        two = File.join(Dir.getwd, "two")
        env.modulepath.should == ["/one", two]
    end

    describe "when modeling a specific environment" do
        it "should have a method for returning the environment name" do
            Puppet::Node::Environment.new("testing").name.should == :testing
        end

        it "should provide an array-like accessor method for returning any environment-specific setting" do
            env = Puppet::Node::Environment.new("testing")
            env.should respond_to(:[])
        end

        it "should ask the Puppet settings instance for the setting qualified with the environment name" do
            Puppet.settings.expects(:value).with("myvar", :testing).returns("myval")
            env = Puppet::Node::Environment.new("testing")
            env["myvar"].should == "myval"
        end

        it "should be able to return its modules" do
            Puppet::Node::Environment.new("testing").should respond_to(:modules)
        end

        it "should return each module from the environment-specific module path when asked for its modules" do
            env = Puppet::Node::Environment.new("testing")
            module_path = %w{/one /two}.join(File::PATH_SEPARATOR)
            env.expects(:modulepath).returns module_path

            Puppet::Module.expects(:each_module).with(module_path).multiple_yields("mod1", "mod2")

            env.modules.should == %w{mod1 mod2}
        end

        it "should be able to return an individual module that exists in its module path" do
            env = Puppet::Node::Environment.new("testing")

            mod = mock 'module'
            Puppet::Module.expects(:new).with("one", env).returns mod
            mod.expects(:exist?).returns true

            env.module("one").should equal(mod)
        end

        it "should return nil if asked for a module that does not exist in its path" do
            env = Puppet::Node::Environment.new("testing")

            mod = mock 'module'
            Puppet::Module.expects(:new).with("one", env).returns mod
            mod.expects(:exist?).returns false

            env.module("one").should be_nil
        end
    end
end
