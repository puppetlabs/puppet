#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

provider_class = Puppet::Type.type(:augeas).provider(:augeas)

describe provider_class do
    describe "command parsing" do
        it "should break apart a single line into three tokens" do
            provider = provider_class.new()
            tokens = provider.parse_commands("set /Jar/Jar Binks")
            tokens.size.should == 1
            tokens[0].size.should == 3      
            tokens[0][0].should == "set"
            tokens[0][1].should == "/Jar/Jar"
            tokens[0][2].should == "Binks"            
        end
        
        it "should break apart a multiple line into six tokens" do
            provider = provider_class.new()
            tokens = provider.parse_commands("set /Jar/Jar Binks\nrm anakin skywalker")
            tokens.size.should == 2
            tokens[0].size.should == 3      
            tokens[1].size.should == 3            
            tokens[0][0].should == "set"
            tokens[0][1].should == "/Jar/Jar"
            tokens[0][2].should == "Binks"            
            tokens[1][0].should == "rm"
            tokens[1][1].should == "anakin"
            tokens[1][2].should == "skywalker"                
        end        
        
        it "should handle arrays" do
            provider = provider_class.new()
            commands = ["set /Jar/Jar Binks", "rm anakin skywalker"]
            tokens = provider.parse_commands(commands)
            tokens.size.should == 2
            tokens[0].size.should == 3      
            tokens[1].size.should == 3            
            tokens[0][0].should == "set"
            tokens[0][1].should == "/Jar/Jar"
            tokens[0][2].should == "Binks"            
            tokens[1][0].should == "rm"
            tokens[1][1].should == "anakin"
            tokens[1][2].should == "skywalker"                
        end                
        
        it "should concat the last values" do
            provider = provider_class.new()
            tokens = provider.parse_commands("set /Jar/Jar Binks is my copilot")
            tokens.size.should == 1
            tokens[0].size.should == 3      
            tokens[0][0].should == "set"
            tokens[0][1].should == "/Jar/Jar"
            tokens[0][2].should == "Binks is my copilot"            
        end
    end
    
    describe "get filters" do
        before do
            augeas_stub = stub("augeas", :get => "value")
            @provider = provider_class.new()        
            @provider.stubs(:open_augeas).returns(augeas_stub)        
        end
        
        it "should return false for a = nonmatch" do
            command = ["get", "fake value", "==", "value"]
            @provider.process_get(command).should == true
        end
        
        it "should return true for a != match" do
            command = ["get", "fake value", "!=", "value"]
            @provider.process_get(command).should == false
        end        
        
        it "should return true for a =~ match" do
            command = ["get", "fake value", "=~", "val*"]
            @provider.process_get(command).should == true
        end           
        
        it "should return false for a == nonmatch" do
            command = ["get", "fake value", "=~", "num*"]
            @provider.process_get(command).should == false
        end 
    end
    
    describe "match filters" do
        before do
            augeas_stub = stub("augeas", :match => ["set", "of", "values"])
            @provider = provider_class.new()        
            @provider.stubs(:open_augeas).returns(augeas_stub)        
        end
        
        it "should return true for size match" do
            command = ["match", "fake value", "size", "==", "3"]
            @provider.process_match(command).should == true
        end
        
        it "should return false for a size non match" do
            command = ["match", "fake value", "size", "<", "3"]
            @provider.process_match(command).should == false
        end    
        
        it "should return true for includes match" do
            command = ["get", "fake value", "include", "values"]
            @provider.process_match(command).should == true
        end           
        
        it "should return false for includes non match" do
            command = ["get", "fake value", "include", "JarJar"]
            @provider.process_match(command).should == false
        end           
        
        it "should return true for an array match" do
            command = ["get", "fake value", "==", "['set', 'of', 'values']"]
            @provider.process_match(command).should == true
        end  
        
        it "should return false for an array non match" do
            command = ["get", "fake value", "==", "['this', 'should', 'not', 'match']"]
            @provider.process_match(command).should == false
        end                 
    end    
    
    describe "need_to_run" do
        it "should handle no filters" do
            resource = stub("resource", :[] => "")
            provider = provider_class.new(resource)
            provider.need_to_run?.should == true        
        end
        
        it "should return true when a get filter matches" do
            resource = stub("resource", :[] => "get path == value")
            provider = provider_class.new(resource)
            augeas_stub = stub("augeas", :get => "value")
            provider.stubs(:open_augeas).returns(augeas_stub)              
            provider.need_to_run?.should == true       
        end       
        
        it "should return false when a get filter does not match" do
            resource = stub("resource", :[] => "get path == another value")
            provider = provider_class.new(resource)
            augeas_stub = stub("augeas", :get => "value")
            provider.stubs(:open_augeas).returns(augeas_stub)              
            provider.need_to_run?.should == false       
        end            
        
        it "should return true when a match filter matches" do
            resource = stub("resource", :[] => "match path size == 3")
            provider = provider_class.new(resource)
            augeas_stub = stub("augeas", :match => ["set", "of", "values"])
            provider.stubs(:open_augeas).returns(augeas_stub)              
            provider.need_to_run?.should == true       
        end       
        
        it "should return false when a match filter does not match" do
            resource = stub("resource", :[] => "match path size == 2")
            provider = provider_class.new(resource)
            augeas_stub = stub("augeas", :match => ["set", "of", "values"])
            provider.stubs(:open_augeas).returns(augeas_stub)              
            provider.need_to_run?.should == false       
        end       
    end
    
    describe "augeas integration" do
        
        before do
            @resource = stub("resource")
            @provider = provider_class.new(@resource)
            @augeas = stub("augeas")
            @provider.stubs(:open_augeas).returns(@augeas)
        end
    
        it "should handle set commands" do
            command = [["set", "/Jar/Jar", "Binks"]]
            context = "/some/path"
            @resource.expects(:[]).times(2).returns(command).then.returns(context)
            @augeas.expects(:set).with("/some/path/Jar/Jar", "Binks")
            @augeas.expects(:save).returns(true)
            @provider.execute_changes.should == :executed
        end
        
        it "should handle rm commands" do
            command = [["rm", "/Jar/Jar"]]
            context = ""
            @resource.expects(:[]).times(2).returns(command).then.returns(context)
            @augeas.expects(:rm).with("/Jar/Jar")
            @augeas.expects(:save).returns(true)
            @provider.execute_changes.should == :executed
        end        
        
        it "should handle remove commands" do
            command = [["remove", "Jar/Jar"]]
            context = ""
            @resource.expects(:[]).times(2).returns(command).then.returns(context)
            @augeas.expects(:rm).with("/Jar/Jar")
            @augeas.expects(:save).returns(true)
            @provider.execute_changes.should == :executed
        end              
        
        it "should handle clear commands" do
            command = [["clear", "/Jar/Jar"]]
            context = "/foo"
            @resource.expects(:[]).times(2).returns(command).then.returns(context)
            @augeas.expects(:clear).with("/foo/Jar/Jar")
            @augeas.expects(:save).returns(true)
            @provider.execute_changes.should == :executed
        end        
    

        it "should handle ins commands with before" do
            command = [["ins", "Binks", "before /Jar/Jar"]]
            context = "/foo"
            @resource.expects(:[]).times(2).returns(command).then.returns(context)
            @augeas.expects(:insert).with("/foo/Jar/Jar", "Binks", true)
            @augeas.expects(:save).returns(true)
            @provider.execute_changes.should == :executed
        end

        it "should handle ins commands with before" do
            command = [["ins", "Binks", "after /Jar/Jar"]]
            context = "/foo"
            @resource.expects(:[]).times(2).returns(command).then.returns(context)
            @augeas.expects(:insert).with("/foo/Jar/Jar", "Binks", false)
            @augeas.expects(:save).returns(true)
            @provider.execute_changes.should == :executed
        end

        it "should handle ins with no context" do
            command = [["ins", "Binks", "after /Jar/Jar"]]
            context = "" # this is the default
            @resource.expects(:[]).times(2).returns(command).then.returns(context)
            @augeas.expects(:insert).with("/Jar/Jar", "Binks", false)
            @augeas.expects(:save).returns(true)
            @provider.execute_changes.should == :executed
        end         
        
        it "should handle multiple commands" do
            command = [["ins", "Binks", "after /Jar/Jar"], ["clear", "/Jar/Jar"]]
            context = "/foo"
            @resource.expects(:[]).times(2).returns(command).then.returns(context)
            @augeas.expects(:insert).with("/foo/Jar/Jar", "Binks", false)
            @augeas.expects(:clear).with("/foo/Jar/Jar")            
            @augeas.expects(:save).returns(true)
            @provider.execute_changes.should == :executed
        end    
    end
end
