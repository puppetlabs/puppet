require 'spec_helper'
require 'hiera/backend/module_data_backend'

class Hiera
  module Backend
    describe Module_data_backend do
      before do
        Hiera.stubs(:debug)
        Hiera.stubs(:warn)

        @cache = mock
        @backend = Module_data_backend.new(@cache)
      end

      describe "#load_module_config" do
        it "should attempt to load the config from a puppet module directory" do
          Puppet::Module.expects(:find).with("rspec", "testing").returns(OpenStruct.new(:path => "/nonexisting"))

          config_path = File.join("/nonexisting", "data", "hiera.yaml")

          File.expects(:exist?).with(config_path).returns(true)
          @backend.expects(:load_data).with(config_path).returns({:hierarchy => ["x"]})

          @backend.load_module_config("rspec", "testing").should == {:hierarchy => ["x"], "path" => "/nonexisting"}
        end

        it "should return default config if the JSON config file is not a hash" do
          Puppet::Module.expects(:find).with("rspec", "testing").returns(OpenStruct.new(:path => "/nonexisting"))

          config_path = File.join("/nonexisting", "data", "hiera.yaml")

          File.expects(:exist?).with(config_path).returns(true)
          @backend.expects(:load_data).with(config_path).returns("rspec")

          @backend.load_module_config("rspec", "testing").should == {:hierarchy => ["default"], "path" => "/nonexisting"}
        end

        it "should return the default if not found" do
          Puppet::Module.expects(:find).returns(nil)
          @backend.load_module_config("rspec", "rspec").should == {:hierarchy => ["default"]}
        end
      end

      describe "#load_data" do
        it "should fall back to direct loading if the cache is not present" do
          cacheless_backend = Module_data_backend.new(nil)
          File.expects(:exist?).with("/nonexisting/1.yaml").returns(true)
          YAML.expects(:load_file).with("/nonexisting/1.yaml").returns({"rspec" => true})
          cacheless_backend.load_data("/nonexisting/1.yaml").should == {"rspec" => true}
        end

        it "should return an empty hash when the file does not exist" do
          File.expects(:exist?).with("/nonexisting").returns(false)
          @backend.load_data("/nonexisting").should == {}
        end

        it "should read using the caching system" do
          File.expects(:exist?).with("/nonexisting").returns(true)
          @cache.expects(:read).with("/nonexisting", Hash, {}).yields('rspec: true').returns({"rspec" => true})

          @backend.load_data("/nonexisting").should == {"rspec" => true}
        end
      end

      describe "#lookup" do
        it "should only resolve data when puppet has set module_name" do
          Hiera.expects(:debug).with(regexp_matches(/does not look like a module/))
          @backend.lookup("x", {}, nil, nil).should == nil
        end

        it "should fail if the config loader did not find a module path" do
          @backend.expects(:load_module_config).with("rspec", "testing").returns({})
          Hiera.expects(:debug).with(regexp_matches(/Could not find a path to the module/))

          @backend.lookup("x", {"module_name" => "rspec", "environment" => "testing"}, nil, nil).should == nil
        end

        it "should load data from the hierarchies" do
          scope = {"module_name" => "rspec", "environment" => "testing"}

          @backend.expects(:load_module_config).returns({:hierarchy => ["one", "two"], "path" => "/nonexisting"})
          Backend.expects(:parse_string).with("one", scope).returns("one")
          Backend.expects(:parse_string).with("two", scope).returns("two")
          Backend.expects(:parse_answer).with("rspec", scope).returns("rspec")

          @backend.expects(:load_data).with(File.join("/nonexisting", "data", "one.yaml")).returns({})
          @backend.expects(:load_data).with(File.join("/nonexisting", "data", "two.yaml")).returns({"rspec" => "rspec"})

          @backend.lookup("rspec", scope, nil, nil).should == "rspec"
        end

        it "should support array merges" do
          scope = {"module_name" => "rspec", "environment" => "testing"}

          @backend.expects(:load_module_config).returns({:hierarchy => ["one", "two"], "path" => "/nonexisting"})
          Backend.expects(:parse_string).with("one", scope).returns("one")
          Backend.expects(:parse_string).with("two", scope).returns("two")
          Backend.expects(:parse_answer).with("rspec1", scope).returns("rspec1")
          Backend.expects(:parse_answer).with("rspec2", scope).returns("rspec2")

          @backend.expects(:load_data).with(File.join("/nonexisting", "data", "one.yaml")).returns({"rspec" => "rspec1"})
          @backend.expects(:load_data).with(File.join("/nonexisting", "data", "two.yaml")).returns({"rspec" => "rspec2"})

          @backend.lookup("rspec", scope, nil, :array).should == ["rspec1", "rspec2"]
        end

        it "should support hash merges" do
          scope = {"module_name" => "rspec", "environment" => "testing"}

          @backend.expects(:load_module_config).returns({:hierarchy => ["one", "two"], "path" => "/nonexisting"})
          Backend.expects(:parse_string).with("one", scope).returns("one")
          Backend.expects(:parse_string).with("two", scope).returns("two")

          @backend.expects(:load_data).with(File.join("/nonexisting", "data", "one.yaml")).returns({"rspec" => {"one" => "1"}})
          @backend.expects(:load_data).with(File.join("/nonexisting", "data", "two.yaml")).returns({"rspec" => {"two" => "2"}})

          @backend.lookup("rspec", scope, nil, :hash).should == {"one"=>"1", "two"=>"2"}
        end
      end
    end
  end
end
