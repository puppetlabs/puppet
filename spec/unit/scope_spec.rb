require File.dirname(__FILE__) + '/../spec_helper'

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
        end

        describe "#include?" do
            it "should correctly report missing data" do
                real = mock
                real.expects(:lookupvar).with("foo").returns("")

                scope = Scope.new(real)
                scope.include?("foo").should == false
            end
        end
    end
end

