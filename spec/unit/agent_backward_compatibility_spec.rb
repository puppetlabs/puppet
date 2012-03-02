#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/agent'


############################################################################
#                                  NOTE                                    #
############################################################################
#                                                                          #
# This entire spec is only here for backwards compatibility from 2.7.12+   #
# with 2.7.10 and 2.7.11. The entire file should be able to be removed     #
# for the 3.x series.                                                      #
#                                                                          #
# For more info, see the comments on the #handle_2_7_10_disabled_lockfile  #
# method in pidlock.rb                                                     #
#                                                                          #
# --cprice 2012-03-01                                                      #
############################################################################

class AgentTestClient
  def run
    # no-op
  end
  def stop
    # no-op
  end
end

describe Puppet::Agent do
  include PuppetSpec::Files

  let(:agent) { Puppet::Agent.new(AgentTestClient) }

  describe "in order to be backwards-compatibility with versions 2.7.10 and 2.7.11" do

    describe "when the 2.7.10/2.7.11 'disabled' lockfile exists" do

      # the "normal" lockfile
      let(:lockfile_path) { tmpfile("agent_spec_lockfile") }

      # the 2.7.10/2.7.11 "disabled" lockfile
      # (can't use PuppetSpec::Files.tmpfile here because we need the ".disabled" file to have *exactly* the same
      #   path/name as the original file, plus the ".disabled" suffix.)
      let(:disabled_lockfile_path) { lockfile_path + ".disabled" }

      # some regexes to match log messages
      let(:warning_regex) { /^Found special lockfile '#{disabled_lockfile_path}'.*renaming/ }
      let(:disabled_regex) { /^Skipping run of .*; administratively disabled/ }

      before(:each) do
        # create the 2.7.10 "disable" lockfile.
        FileUtils.touch(disabled_lockfile_path)

        # stub in our temp lockfile path.
        AgentTestClient.expects(:lockfile_path).returns lockfile_path
      end

      after(:each) do
        # manually clean up the files that we didn't create via PuppetSpec::Files.tmpfile
        begin
          File.unlink(disabled_lockfile_path)
        rescue Errno::ENOENT
          # some of the tests expect for the agent code to take care of deleting this file,
          # so it may (validly) not exist.
        end
      end

      describe "when the 'regular' lockfile also exists" do
        # the logic here is that if a 'regular' lockfile already exists, then there is some state that the
        # current version of puppet is responsible for dealing with.  All of the tests in this block are
        # simply here to make sure that our backwards-compatibility hack does *not* interfere with this.
        #
        # Even if the ".disabled" lockfile exists--it can be dealt with at another time, when puppet is
        # in *exactly* the state that we want it to be in (mostly meaning that the 'regular' lockfile
        # does not exist.)

        before(:each) do
          # create the "regular" lockfile
          FileUtils.touch(lockfile_path)
        end

        it "should be recognized as 'disabled'" do
          agent.should be_disabled
        end

        it "should not try to start a new agent run" do
          AgentTestClient.expects(:new).never
          Puppet.expects(:notice).with(regexp_matches(disabled_regex))

          agent.run
        end

        it "should not delete the 2.7.10/2.7.11 lockfile" do
          agent.run

          File.exists?(disabled_lockfile_path).should == true
        end

        it "should not print the warning message" do
          Puppet.expects(:warning).with(regexp_matches(warning_regex)).never

          agent.run
        end
      end

      describe "when the 'regular' lockfile does not exist" do
        # this block of tests is for actually testing the backwards compatibility hack.  This
        # is where we're in a clean state and we know it's safe(r) to muck with the lockfile
        # situation.

        it "should recognize that the agent is disabled" do
          agent.should be_disabled
        end

        describe "when an agent run is requested" do
          it "should not try to start a new agent run" do
            AgentTestClient.expects(:new).never
            Puppet.expects(:notice).with(regexp_matches(disabled_regex))

            agent.run
          end

          it "should warn, remove the 2.7.10/2.7.11 lockfile, and create the 'normal' lockfile" do
            Puppet.expects(:warning).with(regexp_matches(warning_regex))

            agent.run

            File.exists?(disabled_lockfile_path).should == false
            File.exists?(lockfile_path).should == true
          end
        end

        describe "when running --enable" do
          it "should recognize that the agent is disabled" do
            agent.should be_disabled
          end

          it "should warn and clean up the 2.7.10/2.7.11 lockfile" do
            Puppet.expects(:warning).with(regexp_matches(warning_regex))

            agent.enable

            File.exists?(disabled_lockfile_path).should == false
            File.exists?(lockfile_path).should == false
          end
        end
      end
    end
  end


end
