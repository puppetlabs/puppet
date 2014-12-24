#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/terminal'

describe Puppet::Util::Terminal do
  describe '.width' do
    before { Puppet.features.stubs(:posix?).returns(true) }

    it 'should invoke `stty` and return the width' do
      height, width = 100, 200
      subject.expects(:`).with('stty size 2>/dev/null').returns("#{height} #{width}\n")
      expect(subject.width).to eq(width)
    end

    it 'should use `tput` if `stty` is unavailable' do
      width = 200
      subject.expects(:`).with('stty size 2>/dev/null').returns("\n")
      subject.expects(:`).with('tput cols 2>/dev/null').returns("#{width}\n")
      expect(subject.width).to eq(width)
    end

    it 'should default to 80 columns if `tput` and `stty` are unavailable' do
      width = 80
      subject.expects(:`).with('stty size 2>/dev/null').returns("\n")
      subject.expects(:`).with('tput cols 2>/dev/null').returns("\n")
      expect(subject.width).to eq(width)
    end

    it 'should default to 80 columns if `tput` or `stty` raise exceptions' do
      width = 80
      subject.expects(:`).with('stty size 2>/dev/null').raises()
      subject.stubs(:`).with('tput cols 2>/dev/null').returns("#{width + 1000}\n")
      expect(subject.width).to eq(width)
    end

    it 'should default to 80 columns if not in a POSIX environment' do
      width = 80
      Puppet.features.stubs(:posix?).returns(false)
      expect(subject.width).to eq(width)
    end
  end
end
