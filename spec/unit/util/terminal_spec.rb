require 'spec_helper'
require 'puppet/util/terminal'

describe Puppet::Util::Terminal do
  describe '.width' do
    before { allow(Puppet.features).to receive(:posix?).and_return(true) }

    it 'should invoke `stty` and return the width' do
      height, width = 100, 200
      expect(subject).to receive(:`).with('stty size 2>/dev/null').and_return("#{height} #{width}\n")
      expect(subject.width).to eq(width)
    end

    it 'should use `tput` if `stty` is unavailable' do
      width = 200
      expect(subject).to receive(:`).with('stty size 2>/dev/null').and_return("\n")
      expect(subject).to receive(:`).with('tput cols 2>/dev/null').and_return("#{width}\n")
      expect(subject.width).to eq(width)
    end

    it 'should default to 80 columns if `tput` and `stty` are unavailable' do
      width = 80
      expect(subject).to receive(:`).with('stty size 2>/dev/null').and_return("\n")
      expect(subject).to receive(:`).with('tput cols 2>/dev/null').and_return("\n")
      expect(subject.width).to eq(width)
    end

    it 'should default to 80 columns if `tput` or `stty` raise exceptions' do
      width = 80
      expect(subject).to receive(:`).with('stty size 2>/dev/null').and_raise()
      allow(subject).to receive(:`).with('tput cols 2>/dev/null').and_return("#{width + 1000}\n")
      expect(subject.width).to eq(width)
    end

    it 'should default to 80 columns if not in a POSIX environment' do
      width = 80
      allow(Puppet.features).to receive(:posix?).and_return(false)
      expect(subject.width).to eq(width)
    end
  end
end
