require 'spec_helper'

class Hiera
  describe Scope do
    describe "#initialize" do
      it "should store the supplied puppet scope" do
        real = {}
        scope = Scope.new(real)
        scope.real.should == real
      end
    end

    describe "#[]" do
      it "should treat '' as nil" do
        real = mock
        real.expects(:lookupvar).with("foo").returns("")

        scope = Scope.new(real)
        scope["foo"].should == nil
      end

      it "sould return found data" do
        real = mock
        real.expects(:lookupvar).with("foo").returns("bar")

        scope = Scope.new(real)
        scope["foo"].should == "bar"
      end

      it "should get calling_class and calling_module from puppet scope" do
        real = mock
        resource = mock
        resource.expects(:name).returns("Foo::Bar").twice

        real.expects(:resource).returns(resource).twice

        scope = Scope.new(real)
        scope["calling_class"].should == "foo::bar"
        scope["calling_module"].should == "foo"
      end
    end

    describe "#include?" do
      it "should correctly report missing data" do
        real = mock
        real.expects(:lookupvar).with("foo").returns("")

        scope = Scope.new(real)
        scope.include?("foo").should == false
      end

      it "should always return true for calling_class and calling_module" do
        real = mock
        real.expects(:lookupvar).with("calling_class").never
        real.expects(:lookupvar).with("calling_module").never

        scope = Scope.new(real)
        scope.include?("calling_class").should == true
        scope.include?("calling_module").should == true
      end
    end
  end
end

