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
            def generate
                ret = []
                if title.length > 1
                    ret << self.class.create(:title => title[0..-2])
                else
                    return nil
                end
                ret
            end

            def eval_generate
                generate
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
    
    # Test pre-evaluation generation
    def test_generate
        mkgenerator() do
            def generate
                ret = []
                if title.length > 1
                    ret << self.class.create(:title => title[0..-2])
                else
                    return nil
                end
                ret
            end
        end
        
        yay = Puppet::Type.newgenerator :title => "yay"
        rah = Puppet::Type.newgenerator :title => "rah"
        catalog = mk_catalog(yay, rah)
        trans = Puppet::Transaction.new(catalog)
        
        assert_nothing_raised do
            trans.generate
        end
        
        %w{ya ra y r}.each do |name|
            assert(catalog.resource(:generator, name),
                "Generated %s was not a vertex" % name)
            assert($finished.include?(name), "%s was not finished" % name)
        end
        
        # Now make sure that cleanup gets rid of those generated types.
        assert_nothing_raised do
            trans.cleanup
        end
        
        %w{ya ra y r}.each do |name|
            assert(! catalog.resource(:generator, name),
                "Generated vertex %s was not removed from graph" % name)
        end
    end
    
    # Test mid-evaluation generation.
    def test_eval_generate
        $evaluated = []
        cleanup { $evaluated = nil }
        type = mkreducer() do
            def evaluate
                $evaluated << self.title
                return []
            end
        end

        yay = Puppet::Type.newgenerator :title => "yay"
        rah = Puppet::Type.newgenerator :title => "rah", :subscribe => yay
        catalog = mk_catalog(yay, rah)
        trans = Puppet::Transaction.new(catalog)
        
        trans.prepare
        
        # Now apply the resources, and make sure they appropriately generate
        # things.
        assert_nothing_raised("failed to apply yay") do
            trans.eval_resource(yay)
        end
        ya = catalog.resource(type.name, "ya")
        assert(ya, "Did not generate ya")
        assert(trans.relationship_graph.vertex?(ya),
            "Did not add ya to rel_graph")
        
        # Now make sure the appropriate relationships were added
        assert(trans.relationship_graph.edge?(yay, ya),
            "parent was not required by child")
        assert(! trans.relationship_graph.edge?(ya, rah),
            "generated child ya inherited depencency on rah")
        
        # Now make sure it in turn eval_generates appropriately
        assert_nothing_raised("failed to apply yay") do
            trans.eval_resource(catalog.resource(type.name, "ya"))
        end

        %w{y}.each do |name|
            res = catalog.resource(type.name, "ya")
            assert(res, "Did not generate %s" % name)
            assert(trans.relationship_graph.vertex?(res),
                "Did not add %s to rel_graph" % name)
            assert($finished.include?("y"), "y was not finished")
        end
        
        assert_nothing_raised("failed to eval_generate with nil response") do
            trans.eval_resource(catalog.resource(type.name, "y"))
        end
        assert(trans.relationship_graph.edge?(yay, ya), "no edge was created for ya => yay")
        
        assert_nothing_raised("failed to apply rah") do
            trans.eval_resource(rah)
        end

        ra = catalog.resource(type.name, "ra")
        assert(ra, "Did not generate ra")
        assert(trans.relationship_graph.vertex?(ra),
            "Did not add ra to rel_graph" % name)
        assert($finished.include?("ra"), "y was not finished")
        
        # Now make sure this generated resource has the same relationships as
        # the generating resource
        assert(! trans.relationship_graph.edge?(yay, ra),
           "rah passed its dependencies on to its children")
        assert(! trans.relationship_graph.edge?(ya, ra),
            "children have a direct relationship")
        
        # Now make sure that cleanup gets rid of those generated types.
        assert_nothing_raised do
            trans.cleanup
        end
        
        %w{ya ra y r}.each do |name|
            assert(!trans.relationship_graph.vertex?(catalog.resource(type.name, name)),
                "Generated vertex %s was not removed from graph" % name)
        end
        
        # Now, start over and make sure that everything gets evaluated.
        trans = Puppet::Transaction.new(catalog)
        $evaluated.clear
        assert_nothing_raised do
            trans.evaluate
        end
        
        assert_equal(%w{yay ya y rah ra r}, $evaluated,
            "Not all resources were evaluated or not in the right order")
    end
end
