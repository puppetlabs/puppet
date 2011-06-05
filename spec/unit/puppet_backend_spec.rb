require File.dirname(__FILE__) + '/../spec_helper'

class Hiera
    module Backend
        describe Puppet_backend do
            before do
                Hiera.stubs(:warn)
                Hiera.stubs(:debug)
                Backend.stubs(:datasources).yields([])
                Puppet::Parser::Functions.stubs(:function).with(:include)

                @mockresource = mock
                @mockresource.stubs(:name).returns("ntp::config")

                @mockscope = mock
                @mockscope.stubs(:resource).returns(@mockresource)

                @scope = Scope.new(@mockscope)

                @backend = Puppet_backend.new
            end

            describe "#hierarchy" do
                it "should use the configured datasource" do
                    Config.expects("[]").with(:puppet).returns({:datasource => "rspec"})
                    Config.expects("[]").with(:hierarchy)

                    ["ntp", "ntp::config"].each do |klass|
                        Backend.expects(:parse_string).with(klass, @scope, {"calling_module" => "ntp", "calling_class" => "ntp::config"}).returns(klass)
                    end

                    @backend.hierarchy(@scope, nil).should == ["rspec::ntp::config", "rspec::ntp", "ntp::config::rspec", "ntp::rspec"]
                end

                it "should allow for an override data source" do
                    Config.expects("[]").with(:puppet).returns({:datasource => "rspec"})
                    Config.expects("[]").with(:hierarchy)

                    ["ntp", "ntp::config"].each do |klass|
                        Backend.expects(:parse_string).with(klass, @scope, {"calling_module" => "ntp", "calling_class" => "ntp::config"}).returns(klass)
                    end

                    @backend.hierarchy(@scope, "override").should == ["rspec::override", "rspec::ntp::config", "rspec::ntp", "ntp::config::rspec", "ntp::rspec"]
                end

                describe "#lookup" do
                    it "should attempt to load data from unincluded classes" do
                        catalog = mock
                        catalog.expects(:classes).returns([])
                        @mockscope.expects(:catalog).returns(catalog)
                        @mockscope.expects(:function_include).with("rspec")
                        @mockscope.expects(:lookupvar).with("rspec::key").returns("rspec")

                        @backend.expects(:hierarchy).with(@scope, nil).returns(["rspec"])
                        @backend.lookup("key", @scope, nil, nil).should == "rspec"
                    end

                    it "should not load loaded classes" do
                        catalog = mock
                        catalog.expects(:classes).returns(["rspec"])
                        @mockscope.expects(:catalog).returns(catalog)
                        @mockscope.expects(:function_include).never
                        @mockscope.expects(:lookupvar).with("rspec::key").returns("rspec")

                        @backend.expects(:hierarchy).with(@scope, nil).returns(["rspec"])
                        @backend.lookup("key", @scope, nil, nil).should == "rspec"
                    end

                    it "should return the first found data" do
                        catalog = mock
                        catalog.expects(:classes).returns(["rspec", "override"])
                        @mockscope.expects(:catalog).returns(catalog)
                        @mockscope.expects(:function_include).never
                        @mockscope.expects(:lookupvar).with("override::key").returns("rspec")
                        @mockscope.expects(:lookupvar).with("rspec::key").never

                        @backend.expects(:hierarchy).with(@scope, "override").returns(["override", "rspec"])
                        @backend.lookup("key", @scope, "override", nil).should == "rspec"
                    end
                end
            end
        end
    end
end

