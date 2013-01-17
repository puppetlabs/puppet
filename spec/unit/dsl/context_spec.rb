require 'spec_helper'
require 'puppet_spec/dsl'

require 'puppet/dsl/parser'
require 'puppet/dsl/context'

include PuppetSpec::DSL

describe Puppet::DSL::Context do
  prepare_compiler_and_scope_for_evaluation

  context "when creating resources" do

    it "should raise a InvalidTypeError when trying to create a resource with invalid type" do
      lambda do
        evaluate_in_context do
          create_resource :foobar, "test"
        end
      end.should raise_error NoMethodError
    end

    it "should raise NoMethodError when creating resources in a imported file on top level scope" do
      lambda do
        scope = mock
        scope.stubs(:nil?).returns true
        scope.stubs(:known_resource_types).returns nil

        evaluate_in_context :scope => scope do
          create_resource :foobar, "test"
        end
      end.should raise_error NoMethodError
    end

    it "should create a resource" do
      evaluate_in_context do
        create_resource :file, "/tmp/test"
      end
      compiler.resources.map {|r| r.name}.should include "/tmp/test"
    end

    it "should return an array of created resources" do
      evaluate_in_context do
        create_resource :file, "/tmp/test"
      end.each do |r|
        r.should be_a Puppet::Parser::Resource
      end
    end

    it "should set proper title" do
      title = "/tmp/test"
      evaluate_in_context do
        create_resource :file, title
      end.first.title.should == title
    end

    it "converts title to string" do
      title = :foobarbaz
      evaluate_in_context do
        notify title
      end.first.title.should == title.to_s
    end

    it "sets resource parameters with stringified values" do
      parameters = {:ensure => :present, :mode => "0666"}
      res = evaluate_in_context do
        create_resource :file, "/tmp/test", parameters
      end.first

      parameters.each do |k, v|
        res[k].should == v.to_s
      end
    end

    it "should allow block syntax for creating resources" do
      res = evaluate_in_context do
        create_resource :file, "/tmp/test" do |r|
          r.ensure = :present
          r.mode   = "0666"
        end
      end.first

      res[:ensure].should == "present"
      res[:mode].should == "0666"
    end

    it "should allow both block and a hash; block overwrites hash" do
      res = evaluate_in_context do
        create_resource :file, "/tmp/test", :mode => "0600" do |r|
          r.mode   = "0666"
        end
      end.first[:mode].should == "0666"
    end

    it "should mark resource as virtual when virtualizing? is set" do
      evaluate_in_context do
        virtual do
          create_resource :notify, "foo"
        end
      end.first.virtual.should be true
    end

    it "should mark resource as exported when exporting? is set" do
      evaluate_in_context do
        export do
          create_resource :notify, "foo"
        end
      end.first.exported.should be true
    end

    it "should mark resource as exported when options[:export] is set" do
      evaluate_in_context do
        create_resource :notify, "foo", :export => true
      end.first.exported.should be true
    end

    it "should assign resource as a parameter if one exists" do
      evaluate_in_context do
        create_resource :file, "asdf"
        create_resource :file, "test", :require => type("file")["asdf"]
      end.last.parameters.map {|_, v| v.value.class }.should include(Puppet::Parser::Resource)
    end

    it "should assign value as a parameter if given resource doesn't exist" do
      ["foobar", :asdf, 3, 3.14].each do |i|
        evaluate_in_context do
          create_resource :notify, "test-#{i}", :message => i
        end.last.parameters.map {|_, v| v.value }.should include(i.to_s)
      end
    end

    context "with method_missing" do
      it "should work" do
        evaluate_in_context do
          file "/tmp/test"
        end
      end

      it "should create cached method for future use" do
        evaluate_in_context do
          file "/tmp/foo"
          file "/tmp/bar"
        end
      end

      it "should fail with NoMethodError when resource type doesn't exist" do
        lambda do; evaluate_it_context do
          self.foobarbaz "/tmp/test"
        end; end.should raise_error NoMethodError
      end

    end
  end

  context "when calling a function" do
    it "raises NoMethodError when calling functions in a imported file on top level scope" do
      lambda do
        scope = mock
        scope.stubs(:nil?).returns true
        scope.stubs :known_resource_types
        evaluate_in_context :scope => scope do
          call_function :foobar
        end
      end.should raise_error NoMethodError
    end

    it "should call function with passed arguments" do
      Puppet::Parser::Functions.stubs(:function).returns true
      scope.expects(:foobar).with(1, 2, 3)
      evaluate_in_context do
        call_function :foobar, 1, 2, 3
      end
    end

    context "with method_missing" do
      it "should work" do
        scope.expects :notice
        evaluate_in_context do
          notice
        end
      end

      it "should create cached version of the method" do
        evaluate_in_context do
          notice "foo"
          notice "bar"
        end
      end

      it "should fail with NoMethodError when the function doesn't exist" do
        lambda do; evaluate_in_context do
          self.foobar
        end; end.should raise_error NoMethodError
      end

    end
  end

  context "when creating definition" do

    it "should add a new type" do
      evaluate_in_context do
        define(:foo) {}
      end.should == known_resource_types.definition(:foo)
    end

    it "converts the name to string" do
      name = :foo
      evaluate_in_context do
        define(name) {}
      end.name.should == name.to_s
    end

    it "should call the block when evaluating type" do
      expected = nil
      evaluate_in_context do
        define :foo do
          expected = true
        end
      end.ruby_code.each {|c| c.evaluate scope, scope.known_resource_types}

      expected.should be true
    end

    it "should return Puppet::Resource::Type" do
      evaluate_in_context do
        define(:foo) {}
      end.should be_a Puppet::Resource::Type
    end

    it "should create a definition" do
      evaluate_in_context do
        define(:foo) {}
      end.type.should == :definition
    end

    it "should set proper name" do
      evaluate_in_context do
        define(:foo) {}
      end.name.should == "foo"
    end

    it "should raise NoMethodError when the nesting is invalid" do
      lambda do
        evaluate_in_context :nesting => 1 do
          define(:foo) {}
        end
      end.should raise_error NoMethodError
    end

    it "should raise ArgumentError when no block is given" do
      lambda do
        evaluate_in_context do
          define :foo
        end
      end.should raise_error ArgumentError
    end

    it "should assign arguments" do
      args = {"myparam" => "myvalue"}
      evaluate_in_context do
        define :foo, :arguments => args do
        end
      end.arguments.should == args
    end

    it "converts argument keys to strings" do
      args = {:answer => 42}
      evaluate_in_context do
        define :foo, :arguments => args do
        end
      end.arguments.should == {"answer" => 42}
    end

    it "should fail when passing invalid options" do
      lambda do; evaluate_in_context do
        define(:foo, :bar => "asdf") {}
      end; end.should raise_error ArgumentError
    end

    it "should be able to use created definition" do
      evaluate_in_context do
        define(:foo) { notify params[:name] }
        foo "bar"
      end
      compiler.findresource("Foo[bar]").should_not be nil
    end


  end

  context "when creating a node" do

    it "should add a new type" do
      evaluate_in_context do
        node("foo") {}
      end.should == known_resource_types.node(:foo)
    end

    it "converts the name to string unless it's a regexp" do
      name = :foo
      evaluate_in_context do
        node(name) {}
      end.name.should == name.to_s
    end

    it "doesn't convert the name to string when it's a regexp" do
      evaluate_in_context do
        node(/foo/) {}
      end.name_is_regex?.should be true
    end

    it "should set proper name" do
      evaluate_in_context do
        node("foo") {}
      end.name.should == "foo"
    end

    it "should return Puppet::Resource::Type" do
      evaluate_in_context do
        node("foo") {}
      end.should be_a Puppet::Resource::Type
    end

    it "should call the block when evaluating type" do
      expected = nil
      evaluate_in_context do
        node "foo" do
          expected = true
        end
      end.ruby_code.each {|c| c.evaluate scope, scope.known_resource_types}

      expected.should be true
    end

    it "should raise NoMethodError when the nesting is invalid" do
      lambda do
        evaluate_in_context :nesting => 1 do
          node("foo") {}
        end
      end.should raise_error NoMethodError
    end

    it "should raise ArgumentError when there is no block given" do
      lambda do
        evaluate_in_context do
          node "foo"
        end
      end.should raise_error ArgumentError
    end

    it "allows to assign a parent" do
      evaluate_in_context do
        node "foo", :inherits => "bar" do
        end
      end.parent.should == "bar"
    end

    it "converts name of the parent to string unless it's a regexp" do
      parent = :bar
      evaluate_in_context do
        node :foo, :inherits => parent do
        end
      end.parent.should == parent.to_s
    end

    it "should support passing a name as regex" do
      evaluate_in_context do
        node(/mac/) {}
      end.name_is_regex?.should be true
    end

    it "should fail when passing invalid options" do
      lambda do; evaluate_in_context do
        node("foo", :bar => :baz) {}
      end; end.should raise_error ArgumentError
    end

  end

  describe "when defining a class" do

    it "adds a new type" do
      evaluate_in_context do
        hostclass(:foo) {}
      end.should == known_resource_types.hostclass(:foo)
    end

    it "converts the name to string" do
      name = :foo
      evaluate_in_context do
        hostclass(name) {}
      end.name.should == name.to_s
    end

    it "calls the block when evaluating type" do
      expected = nil
      evaluate_in_context do
        hostclass :foo do
          expected = true
        end
      end.ruby_code.each {|c| c.evaluate scope, scope.known_resource_types}

      expected.should be true
    end

    it "should return Puppet::Resource::Type object" do
      evaluate_in_context do
        hostclass(:foo) {}
      end.should be_a Puppet::Resource::Type
    end

    it "should set proper name" do
      evaluate_in_context do
        hostclass(:foo) {}
      end.name.should == "foo"
    end

    it "should create a hostclass" do
      evaluate_in_context do
        hostclass(:foo) {}
      end.type.should == :hostclass
    end

    it "should raise NoMethodError when called in invalid nesting" do
      lambda do
        evaluate_in_context :nesting => 1 do
          hostclass(:foo) {}
        end
      end.should raise_error NoMethodError
    end

    it "should raise ArgumentError when no block is given" do
      lambda do
        evaluate_in_context do
          hostclass :foo
        end
      end.should raise_error ArgumentError
    end

    it "should set arguments" do
      args = {"myparam" => "foo"}
      evaluate_in_context do
        hostclass(:foo, :arguments => args) {}
      end.arguments.should == args
    end

    it "should stringify keys of the arguments" do
      args = {:my => 4}
      evaluate_in_context do
        hostclass(:foo, :arguments => args) {}
      end.arguments.should == {"my" => 4}

    end

    it "should set parent type" do
      parent = "parent"
      evaluate_in_context do
        hostclass(:foo, :inherits => parent) {}
      end.parent.should == parent
    end

    it "converts parent's name to string" do
      parent = :parent
      evaluate_in_context do
        hostclass(:foo, :inherits => parent) {}
      end.parent.should == parent.to_s
    end

    it "should fail when passing invalid options" do
      lambda do; evaluate_in_context do
        hostclass(:foo, :bar => :baz) {}
      end; end.should raise_error ArgumentError
    end

    it "should be able to use created class" do
      evaluate_in_context do
        hostclass(:foo) { notify params[:name] }
        use :foo
      end
      compiler.findresource("Class[foo]").should_not be nil
    end

  end

  context "when referencing type" do
    it "should return a type reference when accessing constant" do
      evaluate_in_context do
        # Full name needs to be used to trigger const_missing
        Puppet::DSL::Context::Notify
      end.should be_a Puppet::DSL::TypeReference
    end

    it "should return a type reference using `type' method" do
      evaluate_in_context do
        type "notify"
      end.should be_a Puppet::DSL::TypeReference
    end

    it "should raise NameError when there is no valid type" do
      lambda do
        evaluate_in_context do
          Puppet::DSL::Context::Foobar
        end
      end.should raise_error NameError
    end

    it "should return type reference for a given type" do
      evaluate_in_context do
        Puppet::DSL::Context::Notify
      end.type_name.should == "Notify"
    end
  end

  describe "utility methods" do

    describe "#raise" do
      it "should proxy raise to Object" do
        Object.expects :raise
        evaluate_in_context do
          raise
        end
      end
    end

    describe "#params" do
      it "should return current scope" do
        evaluate_in_context do
          params
        end.should be_a Puppet::Parser::Scope
      end
    end

    describe "#exporting?" do
      it "should return true when called from the export block" do
        evaluate_in_context do
          export do
            exporting?.should == true
          end
        end
      end

      it "should return false when called outside export block" do
        evaluate_in_context do
          exporting?.should == false
        end
      end
    end

    describe "#virtualizing?" do
      it "should return true when called from the virtual block" do
        evaluate_in_context do
          virtual do
            virtualizing?.should == true
          end
        end
      end

      it "should return false when called outside virtual block" do
        evaluate_in_context do
          virtualizing?.should == false
        end
      end
    end

    describe "#export" do
      it "should mark resources created in block as exported" do
        evaluate_in_context do
          export do
            file "foo"
          end
        end.first.exported.should be true
      end

      it "should mark resources as exported" do
        evaluate_in_context do
          export file "foo"
        end.first.exported.should be true
      end

      it "should mark referenced resources as exported" do
        evaluate_in_context do
          file "foo"
          export type("file")["foo"]
        end.first.resource.exported.should be true
      end

      it "should mark string references of resources as exported" do
        evaluate_in_context do
          resource = file "foo"
          export "File[foo]"
          resource
        end.first.exported.should be true
      end
    end

    describe "#virtual" do
      it "should mark resources created in block as virtual" do
        evaluate_in_context do
          virtual do
            file "foo"
          end
        end.first.virtual.should be true
      end

      it "should mark resources as virtual" do
        evaluate_in_context do
          virtual file "foo"
        end.first.virtual.should be true
      end

      it "should mark referenced resources as virtual" do
        evaluate_in_context do
          file "foo"
          virtual type("file")["foo"]
        end.first.resource.virtual.should be true
      end

      it "should mark string references of resources as virtual" do
        evaluate_in_context do
          resource = file "foo"
          virtual "File[foo]"
          resource
        end.first.virtual.should be true
      end
    end

    describe "#respond_to?" do
      it "should return true when function is defined" do
        evaluate_in_context do
          respond_to?(:notice).should == true
        end
      end

      it "should return true when resource type is defined" do
        evaluate_in_context do
          respond_to?(:file).should == true
        end
      end

      it "should fail otherwise" do
        evaluate_in_context do
          respond_to?(:asdf).should == false
        end
      end
    end

    describe "#ruby_eval" do
      it "should fail when called without block" do
        lambda do; evaluate_in_context do
          ruby_eval
        end; end.should raise_error
      end

      it "should be able to call methods from Object in the block" do
        Object.any_instance.expects(:puts).with "hello world"
        evaluate_in_context do
          ruby_eval { puts "hello world" }
        end
      end
    end

    describe "#inspect" do
      it "returns manifest filename if it is set" do
        filename = "foo.rb"
        evaluate_in_context(:filename => filename) {
          inspect
        }.should == filename.inspect
      end

      it "returns 'dsl_main' when no filename is set" do
        evaluate_in_context { inspect }.should == "dsl_main".inspect
      end

    end

  end
end

