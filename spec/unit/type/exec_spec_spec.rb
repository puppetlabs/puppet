#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Type.type(:exec) do

    def create_resource(command, output, exitstatus, returns = 0)
        @user_name = 'some_user_name'
        @group_name = 'some_group_name'
        Puppet.features.stubs(:root?).returns(true)
        @execer = Puppet::Type.type(:exec).new(:name => command, :path => @example_path, :user => @user_name, :group => @group_name, :returns => returns)

        status = stub "process"
        status.stubs(:exitstatus).returns(exitstatus)

        Puppet::Util::SUIDManager.expects(:run_and_capture).with([command], @user_name, @group_name).returns([output, status])
    end

    def create_logging_resource(command, output, exitstatus, logoutput, loglevel, returns = 0)
        create_resource(command, output, exitstatus, returns)
        @execer[:logoutput] = logoutput
        @execer[:loglevel] = loglevel
    end

    def expect_output(output, loglevel)
        output.split(/\n/).each do |line|
            @execer.property(:returns).expects(loglevel).with(line)
        end
    end

    before do
        @executable = Puppet.features.posix? ? '/bin/true' : 'C:/Program Files/something.exe'
        @command = Puppet.features.posix? ? '/bin/true whatever' : '"C:/Program Files/something.exe" whatever'
        File.stubs(:exists?).returns false
        File.stubs(:exists?).with(@executable).returns true
        @example_path = Puppet.features.posix? ? %w{/usr/bin /bin} : [ "C:/Program Files/something/bin", "C:/Ruby/bin" ]
        File.stubs(:exists?).with(File.join(@example_path[0],"true")).returns true
        File.stubs(:exists?).with(File.join(@example_path[0],"false")).returns true
    end

    it "should return :executed_command as its event" do
        resource = Puppet::Type.type(:exec).new :command => @command
        resource.parameter(:returns).event.name.should == :executed_command
    end

    describe "when execing" do

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

    describe "when logoutput=>on_failure is set" do

        it "should log the output on failure" do
            #Puppet::Util::Log.newdestination :console
            command = "false"
            output = "output1\noutput2\n"
            create_logging_resource(command, output, 1, :on_failure, :err)
            expect_output(output, :err)

            proc { @execer.refresh }.should raise_error(Puppet::Error)
        end

        it "should log the output on failure when returns is specified as an array" do
            #Puppet::Util::Log.newdestination :console
            command = "false"
            output = "output1\noutput2\n"
            create_logging_resource(command, output, 1, :on_failure, :err, [0, 100])
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

    it "shouldn't log the output on success when non-zero exit status is in a returns array" do
        #Puppet::Util::Log.newdestination :console
        command = "true"
        output = "output1\noutput2\n"
        create_logging_resource(command, output, 100, :on_failure, :err, [1,100])
        @execer.property(:returns).expects(:err).never
        @execer.refresh
    end

    describe " when multiple tries are set," do

        it "should repeat the command attempt 'tries' times on failure and produce an error" do
            Puppet.features.stubs(:root?).returns(true)
            command = "false"
            user = "user"
            group = "group"
            tries = 5
            retry_exec = Puppet::Type.type(:exec).new(:name => command, :path => %w{/usr/bin /bin}, :user => user, :group => group, :returns => 0, :tries => tries, :try_sleep => 0)
            status = stub "process"
            status.stubs(:exitstatus).returns(1)
            Puppet::Util::SUIDManager.expects(:run_and_capture).with([command], user, group).times(tries).returns(["", status])
            proc { retry_exec.refresh }.should raise_error(Puppet::Error)
        end
    end

    it "should be able to autorequire files mentioned in the command" do
        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource Puppet::Type.type(:file).new(:name => @executable)
        @execer = Puppet::Type.type(:exec).new(:name => @command)
        catalog.add_resource @execer

        rels = @execer.autorequire
        rels[0].should be_instance_of(Puppet::Relationship)
        rels[0].target.should equal(@execer)
    end
end
