#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/type/exec'

module ExecModuleTesting

    def create_resource(command, output, exitstatus)
        @user_name = 'some_user_name'
        @group_name = 'some_group_name'
        @execer = Puppet::Type.type(:exec).create(:name => command, :user => @user_name, :group => @group_name)

        status = stub "process"
        status.stubs(:exitstatus).returns(exitstatus)

        Puppet::Util::SUIDManager.expects(:run_and_capture).with([command], @user_name, @group_name).returns([output, status])
    end
end

describe Puppet::Type::Exec, " when execing" do
    include ExecModuleTesting

    it "should use the 'run_and_capture' method to exec" do
        command = "/bin/true"
        create_resource(command, "", 0)

        @execer.refresh.should == :executed_command
    end

    it "should report a failure" do
        command = "/bin/false"
        create_resource(command, "", 1)

        # no idea, why should raise_error doesn't work here
        raised = false
        begin
            @execer.refresh.should raise_error(Puppet::Error)
        rescue Puppet::Error
            raised = true
        end
        unless raised 
            raise "didn't receive Puppet::Error"
        end
    end

    it "should log the output on success" do
        #Puppet::Util::Log.newdestination :console
        command = "/bin/false"
        output = "output1\noutput2\n"
        create_resource(command, output, 0)
        @execer[:logoutput] = true
        @execer[:loglevel] = :err
        output.split(/\n/).each do |line|
            @execer.property(:returns).expects(:err).with(line)
        end

        @execer.refresh
    end

    it "should log the output on failure" do
        #Puppet::Util::Log.newdestination :console
        command = "/bin/false"
        output = "output1\noutput2\n"
        create_resource(command, output, 1)
        @execer[:logoutput] = true
        @execer[:loglevel] = :err
        output.split(/\n/).each do |line|
            @execer.property(:returns).expects(:err).with(line)
        end

        # no idea, why should raise_error doesn't work here
        raised = false
        begin
            @execer.refresh.should raise_error(Puppet::Error)
        rescue Puppet::Error
            raised = true
        end
        unless raised 
            raise "didn't receive Puppet::Error"
        end
    end
end

