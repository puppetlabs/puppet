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
end
