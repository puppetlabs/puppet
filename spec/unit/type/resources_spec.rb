#!/usr/bin/env rspec
require 'spec_helper'

resources = Puppet::Type.type(:resources)

# There are still plenty of tests to port over from test/.
describe resources do
  describe "when initializing" do
    it "should fail if the specified resource type does not exist" do
      Puppet::Type.stubs(:type).with { |x| x.to_s.downcase == "resources"}.returns resources
      Puppet::Type.expects(:type).with("nosuchtype").returns nil
      lambda { resources.new :name => "nosuchtype" }.should raise_error(Puppet::Error)
    end

    it "should not fail when the specified resource type exists" do
      lambda { resources.new :name => "file" }.should_not raise_error
    end

    it "should set its :resource_type attribute" do
      resources.new(:name => "file").resource_type.should == Puppet::Type.type(:file)
    end
  end

  describe "#generate" do
    before do
      @host1 = Puppet::Type.type(:host).new(:name => 'localhost', :ip => '127.0.0.1')
      @catalog = Puppet::Resource::Catalog.new
      @context = Puppet::Transaction.new(@catalog)
    end

      describe "when dealing with non-purging resources" do
        before do
          @resources = Puppet::Type.type(:resources).new(:name => 'host')
        end

        it "should not generate any resource" do
          @resources.generate.should be_empty
        end
      end

      describe "when the catalog contains a purging resource" do
        before do
          @resources = Puppet::Type.type(:resources).new(:name => 'host', :purge => true)
          @purgeable_resource = Puppet::Type.type(:host).new(:name => 'localhost', :ip => '127.0.0.1')
          @catalog.add_resource @resources
        end

        it "should not generate a duplicate of that resource" do
          Puppet::Type.type(:host).stubs(:instances).returns [@host1]
          @catalog.add_resource @host1
          @resources.generate.collect { |r| r.ref }.should_not include(@host1.ref)
        end

        it "should not include the skipped users", :'fails_on_ruby_1.9.2' => true do
          res = Puppet::Type.type(:resources).new :name => :user, :purge => true
          res.catalog = Puppet::Resource::Catalog.new

          users = [
            Puppet::Type.type(:user).new(:name => "root")
          ]
          Puppet::Type.type(:user).expects(:instances).returns users
          list = res.generate

          names = list.collect { |r| r[:name] }
          names.should_not be_include("root")
        end

        describe "when generating a purgeable resource" do
          it "should be included in the generated resources" do
            Puppet::Type.type(:host).stubs(:instances).returns [@purgeable_resource]
            @resources.generate.collect { |r| r.ref }.should include(@purgeable_resource.ref)
          end
        end

        describe "when the instance's do not have an ensure property" do
          it "should not be included in the generated resources" do
            @no_ensure_resource = Puppet::Type.type(:exec).new(:name => "#{File.expand_path('/usr/bin/env')} echo")
            Puppet::Type.type(:host).stubs(:instances).returns [@no_ensure_resource]
            @resources.generate.collect { |r| r.ref }.should_not include(@no_ensure_resource.ref)
          end
        end

        describe "when the instance's ensure property does not accept absent" do
          it "should not be included in the generated resources" do
            @no_absent_resource = Puppet::Type.type(:service).new(:name => 'foobar')
            Puppet::Type.type(:host).stubs(:instances).returns [@no_absent_resource]
            @resources.generate.collect { |r| r.ref }.should_not include(@no_absent_resource.ref)
          end
        end

        describe "when checking the instance fails" do
          it "should not be included in the generated resources" do
            @purgeable_resource = Puppet::Type.type(:host).new(:name => 'foobar')
            Puppet::Type.type(:host).stubs(:instances).returns [@purgeable_resource]
            @resources.expects(:check).with(@purgeable_resource).returns(false)
            @resources.generate.collect { |r| r.ref }.should_not include(@purgeable_resource.ref)
          end
        end
      end
  end
end
