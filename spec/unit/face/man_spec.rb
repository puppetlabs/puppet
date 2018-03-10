#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:man, '0.0.1'] do
  it 'should be deprecated' do
    expect(subject.deprecated?).to be_truthy
  end

  it 'has a man action' do
    expect(subject).to be_action(:man)
  end

  it 'has a default action of man' do
    expect(subject.get_action('man')).to be_default
  end

  it 'accepts a call with no arguments' do
    expect { subject.man() }.to have_printed(/USAGE: puppet man <action>/)
  end

  it 'raises an ArgumentError when given to many arguments' do
    subject.stubs(:print_man_help)
    expect { subject.man(:man, 'cert', 'extra') }.to raise_error(ArgumentError)
  end
end
