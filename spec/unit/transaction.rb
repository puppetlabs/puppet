#!/usr/bin/env ruby"

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/transaction'

describe Puppet::Transaction do
    before do
        @generator_class = mkgenerator
        @generator = mkgenerator.create(:name => "foo")

        @catalog = Puppet::Node::Catalog.new
        @catalog.add_resource @generator

        @report = stub_everything 'report'
        Puppet::Transaction::Report.stubs(:new).returns(@report)

        @transaction = Puppet::Transaction.new(@catalog)
    end

    after do
        Puppet::Type.rmtype(:generator)
    end

    describe "when generating resources" do

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

    describe "when generating a report" do

        before :each do
            Puppet.stubs(:[]).with(:report).returns(true)
        end

        it "should create a Puppet::Transaction::Report when the Transaction is created" do
            Puppet::Transaction::Report.expects(:new).returns(@report)

            Puppet::Transaction.new(@catalog)
        end

        it "should return a Puppet::Transaction::Report" do
            @transaction.generate_report.should == @report
        end

        it "should have a metric for resources" do
            @report.expects(:newmetric).with { |metric,hash| metric == :resources }

            @transaction.generate_report
        end

        it "should have a metric for time" do
            @report.expects(:newmetric).with { |metric,hash| metric == :time }

            @transaction.generate_report
        end

        it "should have a metric for changes" do
            @report.expects(:newmetric).with { |metric,hash| metric == :changes }

            @transaction.generate_report
        end

        it "should store the current time" do
            now = stub 'time'
            Time.stubs(:now).returns(now)

            @report.expects(:time=).with(now)

            @transaction.generate_report
        end

    end

    describe "when sending a report" do

        before :each do
            @transaction.stubs(:generate_report).returns(@report)
            Puppet.stubs(:[]).with(:report).returns(true)
            Puppet.stubs(:[]).with(:rrdgraph).returns(false)
            Puppet.stubs(:[]).with(:summarize).returns(false)
        end

        it "should ask the transaction for a report" do
            @transaction.expects(:generate_report)

            @transaction.send_report
        end

        it "should ask the report for a graph if rrdgraph is enable" do
            Puppet.stubs(:[]).with(:rrdgraph).returns(true)

            @report.expects(:graph)

            @transaction.send_report
        end


        it "should call report.save" do
            @report.expects(:save)

            @transaction.send_report
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
