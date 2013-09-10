#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '../parser/parser_rspec_helper')

describe "validating 3x" do
  include ParserRspecHelper
  include PuppetSpec::Pops

  let(:acceptor) { Puppet::Pops::Validation::Acceptor.new() }
  let(:validator) { Puppet::Pops::Validation::ValidatorFactory_3_1.new().validator(acceptor) }

  def validate(model)
    validator.validate(model)
    acceptor
  end

  it 'should raise error for illegal names' do
    expect(validate(fqn('Aaa'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_NAME)
    expect(validate(fqn('AAA'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_NAME)
  end

  it 'should raise error for illegal variable names' do
    expect(validate(fqn('Aaa').var())).to have_issue(Puppet::Pops::Issues::ILLEGAL_NAME)
    expect(validate(fqn('AAA').var())).to have_issue(Puppet::Pops::Issues::ILLEGAL_NAME)
  end

end