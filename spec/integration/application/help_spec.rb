require 'spec_helper'
require 'puppet/application/help'

describe "puppet help" do
  let(:app) { Puppet::Application[:help] }

  it "generates global help" do
    expect {
      app.run
    }.to exit_with(0)
     .and output(Regexp.new(Regexp.escape(<<~END), Regexp::MULTILINE)).to_stdout

       Usage: puppet <subcommand> [options] <action> [options]

       Available subcommands:
     END
  end

  Puppet::Face.faces.sort.each do |face_name|
    context "for #{face_name}" do
      it "generates help" do
        app.command_line.args = ['help', face_name]

        expect {
          app.run
        }.to exit_with(0)
         .and output(/USAGE: puppet #{face_name} <action>/).to_stdout
      end

      Puppet::Face[face_name, :current].actions.sort.each do |action_name|
        it "for action #{action_name}" do
          app.command_line.args = ['help', face_name, action_name]

          expect {
            app.run
          }.to exit_with(0)
           .and output(/USAGE: puppet #{face_name}/).to_stdout
        end
      end
    end
  end
end
