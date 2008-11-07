#!/usr/bin/env ruby"

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/transaction'

describe Puppet::Transaction do
    describe "when generating resources" do
        before do
            @generator_class = mkgenerator
            @generator = mkgenerator.create(:name => "foo")

            @catalog = Puppet::Node::Catalog.new
            @catalog.add_resource @generator

            @transaction = Puppet::Transaction.new(@catalog)
        end

        after do
            Puppet::Type.rmtype(:generator)
        end

        it "should call the generate() method on all resources" do
            @generator.expects(:generate)
            @transaction.generate
        end

        it "should add all generated resources to the catalog" do
            one = @generator_class.create :name => "one"
            two = @generator_class.create :name => "two"
            @generator.expects(:generate).returns [one, two]
            @transaction.generate

            @catalog.resource(:generator, "one").should equal(one)
            @catalog.resource(:generator, "two").should equal(two)
        end

        it "should generate and add resources from the generated resources" do
            one = @generator_class.create :name => "one"
            two = @generator_class.create :name => "two"
            @generator.expects(:generate).returns [one]
            one.expects(:generate).returns [two]
            @transaction.generate

            @catalog.resource(:generator, "two").should equal(two)
        end

        it "should add an edge in the relationship graph between the generating and generated resource" do
            one = @generator_class.create :name => "one"
            two = @generator_class.create :name => "two"
            @generator.expects(:generate).returns [one]
            one.expects(:generate).returns [two]
            @transaction.generate

            @catalog.relationship_graph.should be_edge(@generator, one)
            @catalog.relationship_graph.should be_edge(one, two)
        end

        it "should finish all non-conflicting resources" do
            one = @generator_class.create :name => "one"
            one.expects(:finish)
            @generator.expects(:generate).returns [one]
            @transaction.generate
        end

        describe "mid-transaction" do
            it "should call the eval_generate() method on the resource" do
                @generator.expects(:eval_generate)
                @transaction.eval_generate(@generator)
            end

            it "should add all generated resources to the catalog" do
                one = @generator_class.create :name => "one"
                two = @generator_class.create :name => "two"
                @generator.expects(:eval_generate).returns [one, two]
                @transaction.eval_generate(@generator)

                @catalog.resource(:generator, "one").should equal(one)
                @catalog.resource(:generator, "two").should equal(two)
            end

            it "should add an edge in the relationship graph between the generating and generated resource" do
                one = @generator_class.create :name => "one"
                @generator.expects(:eval_generate).returns [one]
                @transaction.eval_generate(@generator)

                @catalog.relationship_graph.should be_edge(@generator, one)
            end

            it "should not recursively eval_generate resources" do
                one = @generator_class.create :name => "one"
                two = @generator_class.create :name => "two"
                @generator.expects(:eval_generate).returns [one]
                one.expects(:eval_generate).never
                @transaction.eval_generate(@generator)
            end

            it "should finish all non-conflicting resources" do
                one = @generator_class.create :name => "one"
                one.expects(:finish)
                @generator.expects(:eval_generate).returns [one]
                @transaction.eval_generate(@generator)
            end
        end
    end
    
    def mkgenerator
        # Create a bogus type that generates new instances with shorter names
        type = Puppet::Type.newtype(:generator) do
            newparam(:name, :namevar => true)

            # Stub methods.
            def generate
            end

            def eval_generate
            end

            def finished?
                @finished
            end

            def finish
                @finished = true
            end
        end
        
        return type
    end
end
