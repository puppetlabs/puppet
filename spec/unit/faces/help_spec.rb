require 'spec_helper'
require 'puppet/faces/help'

describe Puppet::Faces[:help, '0.0.1'] do
  it "should have a help action" do
    subject.should be_action :help
  end

  it "should have a default action of help" do
    pending "REVISIT: we don't support default actions yet"
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
    subject.help(:help, :current).should ==
      subject.help(:help, 'current')
  end

  it "should complain when the request version of a face is missing" do
    expect { subject.help(:huzzah, :bar, :version => '17.0.0') }.
      should raise_error Puppet::Error
  end

  it "should find a face by version" do
    face = Puppet::Faces[:huzzah, :current]
    subject.help(:huzzah, face.version).should == subject.help(:huzzah, :current)
  end

  context "when listing subcommands" do
    subject { Puppet::Faces[:help, :current].help }

    # Check a precondition for the next block; if this fails you have
    # something odd in your set of faces, and we skip testing things that
    # matter. --daniel 2011-04-10
    it "should have at least one face with a summary" do
      Puppet::Faces.faces.should be_any do |name|
        Puppet::Faces[name, :current].summary
      end
    end

    Puppet::Faces.faces.each do |name|
      face = Puppet::Faces[name, :current]
      summary = face.summary

      it { should have_matching_element %r{ #{name} } }
      it { should have_matching_element %r{ #{name} +#{summary}} } if summary
    end

    Puppet::Util::CommandLine.available_subcommands do |name|
      it { should have_matching_element %r{ #{name} } }
    end
  end

  context "when listing legacy applications" do
    let :help do Puppet::Faces[:help, :current] end

    # If we don't, these tests are ... less than useful, because they assume
    # it.  When this breaks you should consider ditching the entire feature
    # and tests, but if not work out how to fake one. --daniel 2011-04-11
    it "should have at least one legacy application" do
      help.legacy_applications.should have_at_least(1).item
    end

    # Meh.  This is nasty, but we can't control the other list; the specific
    # bug that caused these to be listed is annoyingly subtle and has a nasty
    # fix, so better to have a "fail if you do something daft" trigger in
    # place here, I think. --daniel 2011-04-11
    %w{faces_base indirection_base}.each do |name|
      it "should not list the #{name} application" do
        help.legacy_applications.should_not include name
      end
    end

    Puppet::Faces[:help, :current].legacy_applications.each do |appname|
      it "should list #{appname} in the help output" do
        help.help.should have_matching_element %r{ #{appname} }
      end

      summary = Puppet::Faces[:help, :current].horribly_extract_summary_from(appname)
      if summary then
        it "should display the summary of #{appname}" do
          help.help.should have_matching_element %r{ #{summary}\b}
        end
      end
    end
  end

  
end
