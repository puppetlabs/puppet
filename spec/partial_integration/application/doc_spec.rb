#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'
require 'puppet/application/doc'

describe Puppet::Application::Doc do
  include PuppetSpec::Files

  it "should respect the -o option" do
    puppetdoc = Puppet::Application[:doc]
    puppetdoc.command_line.stubs(:args).returns(['foo', '-o', 'bar'])
    puppetdoc.parse_options
    expect(puppetdoc.options[:outputdir]).to eq('bar')
  end
end
