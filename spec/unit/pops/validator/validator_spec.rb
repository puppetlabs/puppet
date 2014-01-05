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
    pending "validation was too strict, now too relaxed - validation missing"
    expect(validate(fqn('Aaa'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_NAME)
    expect(validate(fqn('AAA'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_NAME)
  end

  it 'should raise error for illegal variable names' do
    pending "validation was too strict, now too relaxed - validation missing"
    expect(validate(fqn('Aaa').var())).to have_issue(Puppet::Pops::Issues::ILLEGAL_NAME)
    expect(validate(fqn('AAA').var())).to have_issue(Puppet::Pops::Issues::ILLEGAL_NAME)
  end

  it 'should raise error for -= assignment' do
    expect(validate(fqn('aaa').minus_set(2))).to have_issue(Puppet::Pops::Issues::UNSUPPORTED_OPERATOR)
  end

end

describe "validating 4x" do
  include ParserRspecHelper
  include PuppetSpec::Pops

  let(:acceptor) { Puppet::Pops::Validation::Acceptor.new() }
  let(:validator) { Puppet::Pops::Validation::ValidatorFactory_4_0.new().validator(acceptor) }

  def validate(model)
    validator.validate(model)
    acceptor
  end

  it 'should raise error for illegal names' do
    pending "validation was too strict, now too relaxed - validation missing"
    expect(validate(fqn('Aaa'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_NAME)
    expect(validate(fqn('AAA'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_NAME)
  end

  it 'should raise error for illegal variable names' do
    expect(validate(fqn('Aaa').var())).to have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
    expect(validate(fqn('AAA').var())).to have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
    expect(validate(fqn('aaa::_aaa').var())).to have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
  end

  it 'should not raise error for variable name with underscore first in first name segment' do
    expect(validate(fqn('_aa').var())).to_not have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
    expect(validate(fqn('::_aa').var())).to_not have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
  end

end
