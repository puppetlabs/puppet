#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

augeas = Puppet::Type.type(:augeas)

describe augeas do
    describe "when augeas is present" do
        confine "Augeas is unavailable" => Puppet.features.augeas?

        it "should have a default provider inheriting from Puppet::Provider" do
            augeas.defaultprovider.ancestors.should be_include(Puppet::Provider)
        end
        
        it "should have a valid provider" do
            augeas.create(:name => "foo").provider.class.ancestors.should be_include(Puppet::Provider)
        end        
    end

    describe "basic structure" do
        it "should be able to create a instance" do
            provider_class = Puppet::Type::Augeas.provider(Puppet::Type::Augeas.providers[0])
            Puppet::Type::Augeas.expects(:defaultprovider).returns provider_class
            augeas.create(:name => "bar").should_not be_nil
        end

        it "should have an parse_commands feature" do
            augeas.provider_feature(:parse_commands).should_not be_nil
        end
        
        it "should have an need_to_run? feature" do
            augeas.provider_feature(:need_to_run?).should_not be_nil
        end    
        
        it "should have an execute_changes feature" do
            augeas.provider_feature(:execute_changes).should_not be_nil
        end           

        properties = [:returns]
        params = [:name, :context, :onlyif, :changes, :root, :load_path, :type_check]

        properties.each do |property|
            it "should have a %s property" % property do
                augeas.attrclass(property).ancestors.should be_include(Puppet::Property)
            end

            it "should have documentation for its %s property" % property do
                augeas.attrclass(property).doc.should be_instance_of(String)
            end
        end        
        
        params.each do |param|
            it "should have a %s parameter" % param do
                augeas.attrclass(param).ancestors.should be_include(Puppet::Parameter)
            end

            it "should have documentation for its %s parameter" % param do
                augeas.attrclass(param).doc.should be_instance_of(String)
            end
        end                
    end
    
    describe "default values" do
        before do
            provider_class = augeas.provider(augeas.providers[0])
            augeas.expects(:defaultprovider).returns provider_class
        end

        it "should be blank for context" do
            augeas.create(:name => :context)[:context].should == ""
        end
        
        it "should be blank for onlyif" do
            augeas.create(:name => :onlyif)[:onlyif].should == ""
        end        
        
        it "should be blank for load_path" do
            augeas.create(:name => :load_path)[:load_path].should == ""
        end        
        
        it "should be / for root" do
            augeas.create(:name => :root)[:root].should == "/"
        end        
        
        it "should be false for type_check" do
            augeas.create(:name => :type_check)[:type_check].should == :false
        end                
    end
    
    describe "provider interaction" do
        it "should munge the changes" do
            provider = stub("provider", :parse_commands => "Jar Jar Binks")
            resource = stub('resource', :resource => nil, :provider => provider, :line => nil, :file => nil)
            changes = augeas.attrclass(:changes).new(:resource => resource)
            changes.value= "Testing 123"
            changes.value.should == "Jar Jar Binks"
        end
        
        it "should return 0 if it does not need to run" do
            provider = stub("provider", :need_to_run? => false)
            resource = stub('resource', :resource => nil, :provider => provider, :line => nil, :file => nil)
            changes = augeas.attrclass(:returns).new(:resource => resource)
            changes.retrieve.should == 0
        end        
        
        it "should return :need_to_run if it needs to run" do
            provider = stub("provider", :need_to_run? => true)
            resource = stub('resource', :resource => nil, :provider => provider, :line => nil, :file => nil)
            changes = augeas.attrclass(:returns).new(:resource => resource)
            changes.retrieve.should == :need_to_run
        end                
    end
end
