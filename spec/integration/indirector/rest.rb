require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/network/server'
require 'puppet/indirector'
require 'puppet/indirector/rest'

# a fake class that will be indirected via REST
class Puppet::TestIndirectedFoo
  extend Puppet::Indirector  
  indirects :test_indirected_foo, :terminus_setting => :test_indirected_foo_terminus
  
  attr_reader :value
  
  def initialize(value = 0)
    @value = value
  end
  
  def self.from_yaml(yaml)
    YAML.load(yaml)
  end
  
  def name
    "bob"
  end
end

# empty Terminus class -- this would normally have to be in a directory findable by the autoloader, but we short-circuit that below
class Puppet::TestIndirectedFoo::Rest < Puppet::Indirector::REST
end


describe Puppet::Indirector::REST do
  describe "when using webrick" do
    before :each do
      Puppet[:servertype] = 'webrick'
      @params = { :address => "127.0.0.1", :port => 34343, :handlers => [ :test_indirected_foo ] }
      @server = Puppet::Network::Server.new(@params)
      @server.listen

      # the autoloader was clearly not written test-first.  We subvert the integration test to get around its bullshit.
      Puppet::Indirector::Terminus.stubs(:terminus_class).returns(Puppet::TestIndirectedFoo::Rest)
      Puppet::TestIndirectedFoo.indirection.stubs(:terminus_class).returns :rest

      # Stub the connection information.
      Puppet::TestIndirectedFoo.indirection.terminus(:rest).stubs(:rest_connection_details).returns(:host => "localhost", :port => 34343)
    end
  
    describe "when finding a model instance over REST" do
      describe "when a matching model instance can be found" do
        before :each do
          @model_instance = Puppet::TestIndirectedFoo.new(23)
          @mock_model = stub('faked model', :find => @model_instance)
          Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:model).returns(@mock_model)        
        end
      
        it "should not fail" do
          Puppet::TestIndirectedFoo.find('bar')
          lambda { Puppet::TestIndirectedFoo.find('bar') }.should_not raise_error
        end
  
        it 'should return an instance of the model class' do
          Puppet::TestIndirectedFoo.find('bar').class.should == Puppet::TestIndirectedFoo
        end
  
        it 'should return the instance of the model class associated with the provided lookup key' do
          Puppet::TestIndirectedFoo.find('bar').value.should == @model_instance.value
        end
  
        it 'should set an expiration on model instance' do
          Puppet::TestIndirectedFoo.find('bar').expiration.should_not be_nil
        end
      end
    
      describe "when no matching model instance can be found" do
        before :each do
          @mock_model = stub('faked model', :find => nil)
          Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:model).returns(@mock_model)
        end
      
        it "should return nil" do
          Puppet::TestIndirectedFoo.find('bar').should be_nil
        end
      end
    
      describe "when an exception is encountered in looking up a model instance" do
        before :each do
          @mock_model = stub('faked model')
          @mock_model.stubs(:find).raises(RuntimeError)
          Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:model).returns(@mock_model)        
        end
      
        it "should raise an exception" do
          lambda { Puppet::TestIndirectedFoo.find('bar') }.should raise_error(RuntimeError) 
        end
      end
    end

    describe "when searching for model instances over REST" do
      describe "when matching model instances can be found" do
        before :each do
          @model_instances = [ Puppet::TestIndirectedFoo.new(23), Puppet::TestIndirectedFoo.new(24) ]
          @mock_model = stub('faked model', :search => @model_instances)
          Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:model).returns(@mock_model)        
        end
      
        it "should not fail" do
          lambda { Puppet::TestIndirectedFoo.search('bar') }.should_not raise_error
        end
  
        it 'should return all matching results' do
          Puppet::TestIndirectedFoo.search('bar').length.should == @model_instances.length
        end
  
        it 'should return model instances' do
          Puppet::TestIndirectedFoo.search('bar').each do |result| 
            result.class.should == Puppet::TestIndirectedFoo
          end
        end
  
        it 'should return the instance of the model class associated with the provided lookup key' do
          Puppet::TestIndirectedFoo.search('bar').collect(&:value).should == @model_instances.collect(&:value)
        end
  
        it 'should set a version timestamp on model instances' do
          pending("Luke looking at why this version magic might not be working") do
            Puppet::TestIndirectedFoo.search('bar').each do |result|
              result.version.should_not be_nil
            end
          end
        end
      end
    
      describe "when no matching model instance can be found" do
        before :each do
          @mock_model = stub('faked model', :find => nil)
          Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:model).returns(@mock_model)
        end
      
        it "should return nil" do
          Puppet::TestIndirectedFoo.find('bar').should be_nil
        end
      end
    
      describe "when an exception is encountered in looking up a model instance" do
        before :each do
          @mock_model = stub('faked model')
          @mock_model.stubs(:find).raises(RuntimeError)
          Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:model).returns(@mock_model)        
        end
      
        it "should raise an exception" do
          lambda { Puppet::TestIndirectedFoo.find('bar') }.should raise_error(RuntimeError) 
        end
      end
    end

    describe "when destroying a model instance over REST" do
      describe "when a matching model instance can be found" do
        before :each do
          @mock_model = stub('faked model', :destroy => true)
          Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:model).returns(@mock_model)        
        end
      
        it "should not fail" do
          lambda { Puppet::TestIndirectedFoo.destroy('bar') }.should_not raise_error
        end
  
        it 'should return success' do
          Puppet::TestIndirectedFoo.destroy('bar').should == true
        end
      end
    
      describe "when no matching model instance can be found" do
        before :each do
          @mock_model = stub('faked model', :destroy => false)
          Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:model).returns(@mock_model)
        end
      
        it "should return failure" do
          Puppet::TestIndirectedFoo.destroy('bar').should == false
        end
      end
    
      describe "when an exception is encountered in destroying a model instance" do
        before :each do
          @mock_model = stub('faked model')
          @mock_model.stubs(:destroy).raises(RuntimeError)
          Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:model).returns(@mock_model)        
        end
      
        it "should raise an exception" do
          lambda { Puppet::TestIndirectedFoo.destroy('bar') }.should raise_error(RuntimeError) 
        end
      end
    end

    describe "when saving a model instance over REST" do
      before :each do
        @instance = Puppet::TestIndirectedFoo.new(42)
        @mock_model = stub('faked model', :from_yaml => @instance)
        Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:model).returns(@mock_model)        
        Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:save_object).returns(@instance)        
      end
      
      describe "when a successful save can be performed" do
        before :each do
        end
      
        it "should not fail" do
          lambda { @instance.save }.should_not raise_error
        end
  
        it 'should return an instance of the model class' do
          @instance.save.class.should == Puppet::TestIndirectedFoo
        end
         
        it 'should return a matching instance of the model class' do
          @instance.save.value.should == @instance.value
        end
      end
          
      describe "when a save cannot be completed" do
        before :each do
          Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:save_object).returns(false)
        end
              
        it "should return failure" do
          @instance.save.should == false
        end
      end
          
      describe "when an exception is encountered in performing a save" do
        before :each do
          Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:save_object).raises(RuntimeError)       
        end
      
        it "should raise an exception" do
          lambda { @instance.save }.should raise_error(RuntimeError) 
        end
      end
    end

    after :each do
      @server.unlisten
    end
  end

  describe "when using mongrel" do
    confine "Mongrel is not available" => Puppet.features.mongrel?
    
    before :each do
      Puppet[:servertype] = 'mongrel'
      @params = { :address => "127.0.0.1", :port => 34343, :handlers => [ :test_indirected_foo ] }
      @server = Puppet::Network::Server.new(@params)
      @server.listen

      # the autoloader was clearly not written test-first.  We subvert the integration test to get around its bullshit.
      Puppet::Indirector::Terminus.stubs(:terminus_class).returns(Puppet::TestIndirectedFoo::Rest)
      Puppet::TestIndirectedFoo.indirection.stubs(:terminus_class).returns :rest

      # Stub the connection information.
      Puppet::TestIndirectedFoo.indirection.terminus(:rest).stubs(:rest_connection_details).returns(:host => "localhost", :port => 34343)
    end
  
    describe "when finding a model instance over REST" do
      describe "when a matching model instance can be found" do
        before :each do
          @model_instance = Puppet::TestIndirectedFoo.new(23)
          @mock_model = stub('faked model', :find => @model_instance)
          Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:model).returns(@mock_model)        
        end
      
        it "should not fail" do
          lambda { Puppet::TestIndirectedFoo.find('bar') }.should_not raise_error
        end
  
        it 'should return an instance of the model class' do
          Puppet::TestIndirectedFoo.find('bar').class.should == Puppet::TestIndirectedFoo
        end
  
        it 'should return the instance of the model class associated with the provided lookup key' do
          Puppet::TestIndirectedFoo.find('bar').value.should == @model_instance.value
        end
  
        it 'should set an expiration on model instance' do
          Puppet::TestIndirectedFoo.find('bar').expiration.should_not be_nil
        end
      end
    
      describe "when no matching model instance can be found" do
        before :each do
          @mock_model = stub('faked model', :find => nil)
          Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:model).returns(@mock_model)
        end
      
        it "should return nil" do
          Puppet::TestIndirectedFoo.find('bar').should be_nil
        end
      end
    
      describe "when an exception is encountered in looking up a model instance" do
        before :each do
          @mock_model = stub('faked model')
          @mock_model.stubs(:find).raises(RuntimeError)
          Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:model).returns(@mock_model)        
        end
      
        it "should raise an exception" do
          lambda { Puppet::TestIndirectedFoo.find('bar') }.should raise_error(RuntimeError) 
        end
      end
    end

    describe "when searching for model instances over REST" do
      describe "when matching model instances can be found" do
        before :each do
          @model_instances = [ Puppet::TestIndirectedFoo.new(23), Puppet::TestIndirectedFoo.new(24) ]
          @mock_model = stub('faked model', :search => @model_instances)
          Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:model).returns(@mock_model)        
        end
      
        it "should not fail" do
          lambda { Puppet::TestIndirectedFoo.search('bar') }.should_not raise_error
        end
  
        it 'should return all matching results' do
          Puppet::TestIndirectedFoo.search('bar').length.should == @model_instances.length
        end
  
        it 'should return model instances' do
          Puppet::TestIndirectedFoo.search('bar').each do |result| 
            result.class.should == Puppet::TestIndirectedFoo
          end
        end
  
        it 'should return the instance of the model class associated with the provided lookup key' do
          Puppet::TestIndirectedFoo.search('bar').collect(&:value).should == @model_instances.collect(&:value)
        end
  
        it 'should set an expiration on model instances' do
          Puppet::TestIndirectedFoo.search('bar').each do |result|
            result.expiration.should_not be_nil
          end
        end
      end
    
      describe "when no matching model instance can be found" do
        before :each do
          @mock_model = stub('faked model', :find => nil)
          Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:model).returns(@mock_model)
        end
      
        it "should return nil" do
          Puppet::TestIndirectedFoo.find('bar').should be_nil
        end
      end
    
      describe "when an exception is encountered in looking up a model instance" do
        before :each do
          @mock_model = stub('faked model')
          @mock_model.stubs(:find).raises(RuntimeError)
          Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:model).returns(@mock_model)        
        end
      
        it "should raise an exception" do
          lambda { Puppet::TestIndirectedFoo.find('bar') }.should raise_error(RuntimeError) 
        end
      end
    end

    describe "when destroying a model instance over REST" do
      describe "when a matching model instance can be found" do
        before :each do
          @mock_model = stub('faked model', :destroy => true)
          Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:model).returns(@mock_model)        
        end
      
        it "should not fail" do
          lambda { Puppet::TestIndirectedFoo.destroy('bar') }.should_not raise_error
        end
  
        it 'should return success' do
          Puppet::TestIndirectedFoo.destroy('bar').should == true
        end
      end
    
      describe "when no matching model instance can be found" do
        before :each do
          @mock_model = stub('faked model', :destroy => false)
          Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:model).returns(@mock_model)
        end
      
        it "should return failure" do
          Puppet::TestIndirectedFoo.destroy('bar').should == false
        end
      end
    
      describe "when an exception is encountered in destroying a model instance" do
        before :each do
          @mock_model = stub('faked model')
          @mock_model.stubs(:destroy).raises(RuntimeError)
          Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:model).returns(@mock_model)        
        end
      
        it "should raise an exception" do
          lambda { Puppet::TestIndirectedFoo.destroy('bar') }.should raise_error(RuntimeError) 
        end
      end
    end

    describe "when saving a model instance over REST" do
      before :each do
        @instance = Puppet::TestIndirectedFoo.new(42)
        @mock_model = stub('faked model', :from_yaml => @instance)
        Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:model).returns(@mock_model)        
        Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:save_object).returns(@instance)        
      end
      
      describe "when a successful save can be performed" do
        before :each do
        end
      
        it "should not fail" do
          lambda { @instance.save }.should_not raise_error
        end
  
        it 'should return an instance of the model class' do
          @instance.save.class.should == Puppet::TestIndirectedFoo
        end
         
        it 'should return a matching instance of the model class' do
          @instance.save.value.should == @instance.value
        end
      end
          
      describe "when a save cannot be completed" do
        before :each do
          Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:save_object).returns(false)
        end
              
        it "should return failure" do
          @instance.save.should == false
        end
      end
          
      describe "when an exception is encountered in performing a save" do
        before :each do
          Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:save_object).raises(RuntimeError)       
        end
      
        it "should raise an exception" do
          lambda { @instance.save }.should raise_error(RuntimeError) 
        end
      end
    end

    after :each do
      @server.unlisten
    end
  end
end
