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

  {
    'configuration' => /# Configuration Reference/,
    'function'      => /# Function Reference/,
    'indirection'   => /# Indirection Reference/,
    'metaparameter' => /# Metaparameter Reference/,
    'providers'     => /# Provider Suitability Report/,
    'report'        => /# Report Reference/,
    'type'          => /# Type Reference/
  }.each_pair do |type, expected|
    it "generates #{type} reference" do
      app.command_line.args = ['-r', type]
      expect {
        app.run
      }.to exit_with(0)
       .and output(expected).to_stdout
    end
  end
end
