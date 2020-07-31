require 'spec_helper'
require 'puppet/application/doc'

describe Puppet::Application::Doc do
  include PuppetSpec::Files

  let(:app) { Puppet::Application[:doc] }

  it 'lists references' do
    app.command_line.args = ['-l']
    expect {
      app.run
    }.to exit_with(0)
     .and output(/configuration - A reference for all settings/).to_stdout
  end

  it 'generates markdown' do
    app.command_line.args = ['-r', 'report']
    expect {
      app.run
    }.to exit_with(0)
     .and output(/# Report Reference/).to_stdout
  end
end
