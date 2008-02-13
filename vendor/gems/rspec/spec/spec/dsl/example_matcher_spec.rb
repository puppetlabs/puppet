require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module DSL
    module ExampleMatcherSpecHelper
      class MatchDescription
        def initialize(description)
          @description = description
        end
        
        def matches?(matcher)
          matcher.matches?(@description)
        end
        
        def failure_message
          "expected matcher.matches?(#{@description.inspect}) to return true, got false"
        end
        
        def negative_failure_message
          "expected matcher.matches?(#{@description.inspect}) to return false, got true"
        end
      end
      def match_description(description)
        MatchDescription.new(description)
      end
    end

    describe ExampleMatcher do
      include ExampleMatcherSpecHelper
      
      it "should match correct behaviour and example" do
        matcher = ExampleMatcher.new("behaviour", "example")
        matcher.should match_description("behaviour example")
      end
      
      it "should not match wrong example" do
        matcher = ExampleMatcher.new("behaviour", "other example")
        matcher.should_not match_description("behaviour example")
      end
      
      it "should not match wrong behaviour" do
        matcher = ExampleMatcher.new("other behaviour", "example")
        matcher.should_not match_description("behaviour example")
      end
      
      it "should match example only" do
        matcher = ExampleMatcher.new("behaviour", "example")
        matcher.should match_description("example")
      end
      
      it "should match behaviour only" do
        matcher = ExampleMatcher.new("behaviour", "example")
        matcher.should match_description("behaviour")
      end
      
      it "should escape regexp chars" do
        matcher = ExampleMatcher.new("(con|text)", "[example]")
        matcher.should_not match_description("con p")
      end
      
      it "should match when behaviour is modularized" do
        matcher = ExampleMatcher.new("MyModule::MyClass", "example")
        matcher.should match_description("MyClass example")
      end      
    end

    describe ExampleMatcher, "normal case" do
      it "matches when passed in example matches" do
        matcher = ExampleMatcher.new("Foo", "bar")
        matcher.matches?(["no match", "Foo bar"]).should == true
      end

      it "does not match when no passed in examples match" do
        matcher = ExampleMatcher.new("Foo", "bar")
        matcher.matches?(["no match1", "no match2"]).should == false
      end
    end

    describe ExampleMatcher, "where description has '::' in it" do
      it "matches when passed in example matches" do
        matcher = ExampleMatcher.new("Foo::Bar", "baz")
        matcher.matches?(["no match", "Foo::Bar baz"]).should == true
      end

      it "does not match when no passed in examples match" do
        matcher = ExampleMatcher.new("Foo::Bar", "baz")
        matcher.matches?(["no match1", "no match2"]).should == false
      end
    end
  end
end
