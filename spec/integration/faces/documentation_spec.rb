#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/face'

describe "documentation of faces" do
  it "should generate global help" do
    help = nil
    expect { help = Puppet::Face[:help, :current].help }.not_to raise_error
    help.should be_an_instance_of String
    help.length.should be > 200
  end

  ########################################################################
  # Can we actually generate documentation for the face, and the actions it
  # has?  This avoids situations where the ERB template turns out to have a
  # bug in it, triggered in something the user might do.
  Puppet::Face.faces.sort.each do |face_name|
    # REVISIT: We should walk all versions of the face here...
    let :help do Puppet::Face[:help, :current] end

    context "generating help" do
      it "for #{face_name}" do
        expect {
          text = help.help(face_name)
          text.should be_an_instance_of String
          text.length.should be > 100
        }.not_to raise_error
      end

      Puppet::Face[face_name, :current].actions.sort.each do |action_name|
        it "for #{face_name}.#{action_name}" do
          expect {
            text = help.help(face_name, action_name)
            text.should be_an_instance_of String
            text.length.should be > 100
          }.not_to raise_error
        end
      end
    end

    ########################################################################
    # Ensure that we have authorship and copyright information in *our* faces;
    # if you apply this to third party faces you might well be disappointed.
    context "licensing of Puppet Labs face '#{face_name}'" do
      subject { Puppet::Face[face_name, :current] }
      its :license   do should =~ /Apache\s*2/ end
      its :copyright do should =~ /Puppet Labs/ end

      # REVISIT: This is less that ideal, I think, but right now I am more
      # comfortable watching us ship with some copyright than without any; we
      # can redress that when it becomes appropriate. --daniel 2011-04-27
      its :copyright do should =~ /2011/ end
    end
  end
end
