#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:instrumentation_probe, '0.0.1'] do
  it_should_behave_like "an indirector face"

  describe 'when running #enable' do
    it 'should invoke #save' do
      subject.expects(:save).with(nil)
      subject.enable('hostname')
    end
  end

  describe 'when running #disable' do
    it 'should invoke #destroy' do
      subject.expects(:destroy).with(nil)
      subject.disable('hostname')
    end
  end
end
