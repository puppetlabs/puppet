#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:help, '0.0.1'] do
  it "should have a help action" do
    subject.should be_action :help
  end

  it "should have a default action of help" do
    subject.get_action('help').should be_default
  end

  it "should accept a call with no arguments" do
    expect { subject.help() }.should_not raise_error
  end

  it "should accept a face name" do
    expect { subject.help(:help) }.should_not raise_error
  end

  it "should accept a face and action name" do
    expect { subject.help(:help, :help) }.should_not raise_error
  end

  it "should fail if more than a face and action are given" do
    expect { subject.help(:help, :help, :for_the_love_of_god) }.
      should raise_error ArgumentError
  end

  it "should treat :current and 'current' identically" do
    subject.help(:help, :version => :current).should ==
      subject.help(:help, :version => 'current')
  end

  it "should complain when the request version of a face is missing" do
    expect { subject.help(:huzzah, :bar, :version => '17.0.0') }.
      should raise_error Puppet::Error
  end

  it "should find a face by version" do
    face = Puppet::Face[:huzzah, :current]
    subject.help(:huzzah, :version => face.version).
      should == subject.help(:huzzah, :version => :current)
  end

  context "when listing subcommands" do
    subject { Puppet::Face[:help, :current].help }

    RSpec::Matchers.define :have_a_summary do
      match do |instance|
        instance.summary.is_a?(String)
      end
    end

    # Check a precondition for the next block; if this fails you have
    # something odd in your set of face, and we skip testing things that
    # matter. --daniel 2011-04-10
    it "should have at least one face with a summary" do
      Puppet::Face.faces.should be_any do |name|
        Puppet::Face[name, :current].summary
      end
    end

    it "should list all faces" do
      Puppet::Face.faces.each do |name|
        face = Puppet::Face[name, :current]
        summary = face.summary

        subject.should =~ %r{ #{name} }
        summary and subject.should =~ %r{ #{name} +#{summary}}
      end
    end

    Puppet::Face.faces.each do |name|
      it "should have a summary for #{name}" do
        Puppet::Face[name, :current].should have_a_summary
      end
    end

    it "should list all legacy applications" do
      Puppet::Face[:help, :current].legacy_applications.each do |appname|
        subject.should =~ %r{ #{appname} }

        summary = Puppet::Face[:help, :current].horribly_extract_summary_from(appname)
        summary and subject.should =~ %r{ #{summary}\b}
      end
    end
  end

  context "#legacy_applications" do
    subject { Puppet::Face[:help, :current].legacy_applications }

    # If we don't, these tests are ... less than useful, because they assume
    # it.  When this breaks you should consider ditching the entire feature
    # and tests, but if not work out how to fake one. --daniel 2011-04-11
    it { should have_at_least(1).item }

    # Meh.  This is nasty, but we can't control the other list; the specific
    # bug that caused these to be listed is annoyingly subtle and has a nasty
    # fix, so better to have a "fail if you do something daft" trigger in
    # place here, I think. --daniel 2011-04-11
    %w{face_base indirection_base}.each do |name|
      it { should_not include name }
    end
  end

  context "help for legacy applications" do
    subject { Puppet::Face[:help, :current] }
    let :appname do subject.legacy_applications.first end

    # This test is purposely generic, so that as we eliminate legacy commands
    # we don't get into a loop where we either test a face-based replacement
    # and fail to notice breakage, or where we have to constantly rewrite this
    # test and all. --daniel 2011-04-11
    it "should return the legacy help when given the subcommand" do
      help = subject.help(appname)
      help.should =~ /puppet-#{appname}/
      %w{SYNOPSIS USAGE DESCRIPTION OPTIONS COPYRIGHT}.each do |heading|
        help.should =~ /^#{heading}$/
      end
    end

    it "should fail when asked for an action on a legacy command" do
      expect { subject.help(appname, :whatever) }.
        to raise_error ArgumentError, /Legacy subcommands don't take actions/
    end
  end
end
