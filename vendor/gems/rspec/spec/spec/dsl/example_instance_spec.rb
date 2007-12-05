require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module DSL
    describe Example, " instance" do
      predicate_matchers[:is_a] = [:is_a?]
      
      before(:each) do
        @reporter = stub("reporter", :example_started => nil, :example_finished => nil)
      end
      
      it "should send reporter example_started" do
        example=Example.new("example") {}
        @reporter.should_receive(:example_started).with(equal(example))
        example.run(@reporter, nil, nil, false, nil)
      end

      it "should report its name for dry run" do
        example=Example.new("example") {}
        @reporter.should_receive(:example_finished).with(equal(example))
        example.run(@reporter, nil, nil, true, nil) #4th arg indicates dry run
      end

      it "should report success" do
        example=Example.new("example") {}
        @reporter.should_receive(:example_finished).with(equal(example), nil, nil, false)
        example.run(@reporter, nil, nil, nil, nil)
      end

      it "should report failure due to failure" do
        example=Example.new("example") do
          (2+2).should == 5
        end
        @reporter.should_receive(:example_finished).with(equal(example), is_a(Spec::Expectations::ExpectationNotMetError), "example", false)
        example.run(@reporter, nil, nil, nil, nil)
      end

      it "should report failure due to error" do
        error=NonStandardError.new
        example=Example.new("example") do
          raise(error)
        end
        @reporter.should_receive(:example_finished).with(equal(example), error, "example", false)
        example.run(@reporter, nil, nil, nil, nil)
      end

      it "should run example in scope of supplied object" do
        scope_class = Class.new
        example=Example.new("should pass") do
          self.instance_of?(Example).should == false
          self.instance_of?(scope_class).should == true
        end
        @reporter.should_receive(:example_finished).with(equal(example), nil, nil, false)
        example.run(@reporter, nil, nil, nil, scope_class.new)
      end

      it "should not run example block if before_each fails" do
        example_ran = false
        example=Example.new("should pass") {example_ran = true}
        before_each = lambda {raise NonStandardError}
        example.run(@reporter, before_each, nil, nil, Object.new)
        example_ran.should == false
      end

      it "should run after_each block if before_each fails" do
        after_each_ran = false
        example=Example.new("should pass") {}
        before_each = lambda {raise NonStandardError}
        after_each = lambda {after_each_ran = true}
        example.run(@reporter, before_each, after_each, nil, Object.new)
        after_each_ran.should == true
      end

      it "should run after_each block when example fails" do
        example=Example.new("example") do
          raise(NonStandardError.new("in body"))
        end
        after_each=lambda do
          raise("in after_each")
        end
        @reporter.should_receive(:example_finished) do |example, error, location|
          example.should equal(example)
          location.should eql("example")
          error.message.should eql("in body")
        end
        example.run(@reporter, nil, after_each, nil, nil)
      end

      it "should report failure location when in before_each" do
        example=Example.new("example") {}
        before_each=lambda { raise(NonStandardError.new("in before_each")) }
        @reporter.should_receive(:example_finished) do |name, error, location|
          name.should equal(example)
          error.message.should eql("in before_each")
          location.should eql("before(:each)")
        end
        example.run(@reporter, before_each, nil, nil, nil)
      end

      it "should report failure location when in after_each" do
        example = Example.new("example") {}
        after_each = lambda { raise(NonStandardError.new("in after_each")) }
        @reporter.should_receive(:example_finished) do |name, error, location|
          name.should equal(example)
          error.message.should eql("in after_each")
          location.should eql("after(:each)")
        end
        example.run(@reporter, nil, after_each, nil, nil)
      end

      it "should accept an options hash following the example name" do
        example = Example.new("name", :key => 'value')
      end

      it "should report NO NAME when told to use generated description with --dry-run" do
        example = Example.new(:__generate_description) {
          5.should == 5
        }
        @reporter.should_receive(:example_finished) do |example, error, location|
          example.description.should == "NO NAME (Because of --dry-run)"
        end
        example.run(@reporter, lambda{}, lambda{}, true, Object.new)
      end

      it "should report NO NAME when told to use generated description with no expectations" do
        example = Example.new(:__generate_description) {}
        @reporter.should_receive(:example_finished) do |example, error, location|
          example.description.should == "NO NAME (Because there were no expectations)"
        end
        example.run(@reporter, lambda{}, lambda{}, false, Object.new)
      end

      it "should report NO NAME when told to use generated description and matcher fails" do
        example = Example.new(:__generate_description) do
          5.should "" # Has no matches? method..
        end
        @reporter.should_receive(:example_finished) do |example, error, location|
          example.description.should == "NO NAME (Because of Error raised in matcher)"
        end
        example.run(@reporter, nil, nil, nil, Object.new)
      end

      it "should report generated description when told to and it is available" do
        example = Example.new(:__generate_description) {
          5.should == 5
        }
        @reporter.should_receive(:example_finished) do |example, error, location|
          example.description.should == "should == 5"
        end
        example.run(@reporter, nil, nil, nil, Object.new)
      end

      it "should unregister description_generated callback (lest a memory leak should build up)" do
        example = Example.new("something")
        Spec::Matchers.should_receive(:unregister_description_generated).with(is_a(Proc))
        example.run(@reporter, nil, nil, nil, Object.new)
      end
    end
  end
end
