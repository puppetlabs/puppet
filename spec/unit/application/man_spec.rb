require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:man, :current] do
  let(:pager) { '/path/to/our/pager' }

  around do |example|
    Puppet::Util.withenv('MANPAGER' => pager) do
      example.run
    end
  end

  it 'is deprecated' do
    expect(subject).to be_deprecated
  end

  it 'has a man action' do
    expect(subject).to be_action(:man)
  end

  it 'accepts a call with no arguments' do
    expect { subject.man }.to output(/USAGE: puppet man <action>/).to_stdout
  end

  it 'raises an ArgumentError when given too many arguments' do
    expect {
      subject.man(:man, 'agent', 'extra')
    }.to raise_error(ArgumentError)
     .and output(/USAGE: puppet man <action>/).to_stdout
  end

  it "exits with 0 when generating man documentation for each available application" do
    # turn off deprecation warning
    Puppet[:disable_warnings] = ['deprecations']

    allow(Puppet::Util).to receive(:which).with('ronn').and_return(nil)
    allow(Puppet::Util).to receive(:which).with(pager).and_return(pager)

    Puppet::Application.available_application_names.each do |name|
      next if %w{man face_base indirection_base}.include? name

      app = Puppet::Application[:man]
      app.command_line.args << 'man' << name

      expect {
        allow(IO).to receive(:popen).with(pager, 'w:UTF-8').and_yield($stdout)
        app.run
      }.to exit_with(0)
       .and output(/puppet-#{name}/m).to_stdout
    end
  end
end
