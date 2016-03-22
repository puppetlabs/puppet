#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:help, '0.0.1'] do
  it "has a help action" do
    expect(subject).to be_action :help
  end

  it "has a default action of help" do
    expect(subject.get_action('help')).to be_default
  end

  it "accepts a call with no arguments" do
    expect {
      subject.help()
    }.to_not raise_error
  end

  it "accepts a face name" do
    expect { subject.help(:help) }.to_not raise_error
  end

  it "accepts a face and action name" do
    expect { subject.help(:help, :help) }.to_not raise_error
  end

  it "fails if more than a face and action are given" do
    expect { subject.help(:help, :help, :for_the_love_of_god) }.
      to raise_error ArgumentError
  end

  it "treats :current and 'current' identically" do
    expect(subject.help(:help, :version => :current)).to eq(
      subject.help(:help, :version => 'current')
    )
  end

  it "raises an error when the face is unavailable" do
    expect {
      subject.help(:huzzah, :bar, :version => '17.0.0')
    }.to raise_error(ArgumentError, /Could not find version 17\.0\.0/)
  end

  it "finds a face by version" do
    face = Puppet::Face[:huzzah, :current]
    expect(subject.help(:huzzah, :version => face.version)).
      to eq(subject.help(:huzzah, :version => :current))
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
    it "has at least one face with a summary" do
      expect(Puppet::Face.faces).to be_any do |name|
        Puppet::Face[name, :current].summary
      end
    end

    it "lists all faces which are runnable from the command line" do
      help_face = Puppet::Face[:help, :current]
      # The main purpose of the help face is to provide documentation for
      #  command line users.  It shouldn't show documentation for faces
      #  that can't be run from the command line, so, rather than iterating
      #  over all available faces, we need to iterate over the subcommands
      #  that are available from the command line.
      Puppet::Application.available_application_names.each do |name|
        next unless help_face.is_face_app?(name)
        next if help_face.exclude_from_docs?(name)
        face = Puppet::Face[name, :current]
        summary = face.summary

        expect(subject).to match(%r{ #{name} })
        summary and expect(subject).to match(%r{ #{name} +#{summary}})
      end
    end

    context "face summaries" do
      it "can generate face summaries" do
        faces = Puppet::Face.faces
        expect(faces.length).to be > 0
        faces.each do |name|
          expect(Puppet::Face[name, :current]).to have_a_summary
        end
      end
    end

    it "lists all legacy applications" do
      Puppet::Face[:help, :current].legacy_applications.each do |appname|
        expect(subject).to match(%r{ #{appname} })

        summary = Puppet::Face[:help, :current].horribly_extract_summary_from(appname)
        summary and expect(subject).to match(%r{ #{summary}\b})
      end
    end
  end

  context "#legacy_applications" do
    subject { Puppet::Face[:help, :current].legacy_applications }

    # If we don't, these tests are ... less than useful, because they assume
    # it.  When this breaks you should consider ditching the entire feature
    # and tests, but if not work out how to fake one. --daniel 2011-04-11
    it { is_expected.to have_at_least(1).item }

    # Meh.  This is nasty, but we can't control the other list; the specific
    # bug that caused these to be listed is annoyingly subtle and has a nasty
    # fix, so better to have a "fail if you do something daft" trigger in
    # place here, I think. --daniel 2011-04-11
    %w{face_base indirection_base}.each do |name|
      it { is_expected.not_to include name }
    end
  end

  context "help for legacy applications" do
    subject { Puppet::Face[:help, :current] }
    let :appname do subject.legacy_applications.first end

    # This test is purposely generic, so that as we eliminate legacy commands
    # we don't get into a loop where we either test a face-based replacement
    # and fail to notice breakage, or where we have to constantly rewrite this
    # test and all. --daniel 2011-04-11
    it "returns the legacy help when given the subcommand" do
      help = subject.help(appname)
      expect(help).to match(/puppet-#{appname}/)
      %w{SYNOPSIS USAGE DESCRIPTION OPTIONS COPYRIGHT}.each do |heading|
        expect(help).to match(/^#{heading}$/)
      end
    end

    it "fails when asked for an action on a legacy command" do
      expect { subject.help(appname, :whatever) }.
        to raise_error ArgumentError, /Legacy subcommands don't take actions/
    end
  end
end
