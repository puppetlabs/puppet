#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

module ExecModuleTesting
    def create_resource(command, output, exitstatus, returns = [0])
        @user_name = 'some_user_name'
        @group_name = 'some_group_name'
        Puppet.features.stubs(:root?).returns(true)
        @execer = Puppet::Type.type(:exec).new(:name => command, :path => %w{/usr/bin /bin}, :user => @user_name, :group => @group_name, :returns => returns)

        status = stub "process"
        status.stubs(:exitstatus).returns(exitstatus)

        Puppet::Util::SUIDManager.expects(:run_and_capture).with([command], @user_name, @group_name).returns([output, status])
    end

    def create_logging_resource(command, output, exitstatus, logoutput, loglevel)
        create_resource(command, output, exitstatus)
        @execer[:logoutput] = logoutput
        @execer[:loglevel] = loglevel
    end

    def expect_output(output, loglevel)
        output.split(/\n/).each do |line|
            @execer.property(:returns).expects(loglevel).with(line)
        end
    end
end

describe Puppet::Type.type(:exec) do
    it "should return :executed_command as its event" do
        resource = Puppet::Type.type(:exec).new :command => "/bin/true"
        resource.parameter(:returns).event.name.should == :executed_command
    end
end

describe Puppet::Type.type(:exec), " when execing" do
    include ExecModuleTesting

    it "should use the 'run_and_capture' method to exec" do
        command = "true"
        create_resource(command, "", 0)

        @execer.refresh.should == :executed_command
    end

    it "should report a failure" do
        command = "false"
        create_resource(command, "", 1)

        proc { @execer.refresh }.should raise_error(Puppet::Error)
    end
    
    it "should not report a failure if the exit status is specified in a returns array" do
        command = "false"
        create_resource(command, "", 1, [0,1])
        proc { @execer.refresh }.should_not raise_error(Puppet::Error)
    end
    
    it "should report a failure if the exit status is not specified in a returns array" do
        command = "false"
        create_resource(command, "", 1, [0,100])
        proc { @execer.refresh }.should raise_error(Puppet::Error)
    end

    it "should log the output on success" do
        #Puppet::Util::Log.newdestination :console
        command = "false"
        output = "output1\noutput2\n"
        create_logging_resource(command, output, 0, true, :err)
        expect_output(output, :err)
        @execer.refresh
    end

    it "should log the output on failure" do
        #Puppet::Util::Log.newdestination :console
        command = "false"
        output = "output1\noutput2\n"
        create_logging_resource(command, output, 1, true, :err)
        expect_output(output, :err)

        proc { @execer.refresh }.should raise_error(Puppet::Error)
    end

end


describe Puppet::Type.type(:exec), " when logoutput=>on_failure is set," do
    include ExecModuleTesting

    it "should log the output on failure" do
        #Puppet::Util::Log.newdestination :console
        command = "false"
        output = "output1\noutput2\n"
        create_logging_resource(command, output, 1, :on_failure, :err)
        expect_output(output, :err)

        proc { @execer.refresh }.should raise_error(Puppet::Error)
    end

    it "shouldn't log the output on success" do
        #Puppet::Util::Log.newdestination :console
        command = "true"
        output = "output1\noutput2\n"
        create_logging_resource(command, output, 0, :on_failure, :err)
        @execer.property(:returns).expects(:err).never
        @execer.refresh
    end
end

describe Puppet::Type.type(:exec) do
    it "should be able to autorequire files mentioned in the command" do
        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource Puppet::Type.type(:file).new(:name => "/bin/true")
        @execer = Puppet::Type.type(:exec).new(:name => "/bin/true")
        catalog.add_resource @execer

        rels = @execer.autorequire
        rels[0].should be_instance_of(Puppet::Relationship)
        rels[0].target.should equal(@execer)
    end
end
