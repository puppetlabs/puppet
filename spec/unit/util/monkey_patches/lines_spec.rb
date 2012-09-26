#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/monkey_patches/lines'

class Puppet::Util::MonkeyPatches::Lines::TestHelper < String
  include Puppet::Util::MonkeyPatches::Lines
end

describe Puppet::Util::MonkeyPatches::Lines::TestHelper do
  ["\n", "\n\n", "$", "$$", "@", "@@"].each do |sep|
    context "with #{sep.inspect}" do
      it "should delegate to each_line if given a block" do
        subject.expects(:each_line).with(sep)
        subject.lines(sep) do |x| nil end
      end

      it "should delegate to each_line without a block" do
        subject.expects(:enum_for).with(:each_line, sep)
        subject.lines(sep)
      end

      context "with one line" do
        context "with trailing separator" do
          subject { described_class.new("foo" + sep) }

          it "should yield the string" do
            got = []
            subject.lines(sep) do |x| got << x end
            got.should == ["foo#{sep}"]
          end

          it "should return the string" do
            subject.lines(sep).to_a.should == ["foo#{sep}"]
          end
        end

        context "without trailing separator" do
          subject { described_class.new("foo") }

          it "should yield the string" do
            got = []
            subject.lines(sep) do |x| got << x end
            got.should == ["foo"]
          end

          it "should return the string" do
            subject.lines(sep).to_a.should == ["foo"]
          end
        end
      end

      context "with multiple lines" do
        context "with trailing separator" do
          subject { described_class.new("foo#{sep}bar#{sep}baz#{sep}") }

          it "should yield the strings" do
            got = []
            subject.lines(sep) do |x| got << x end
            got.should == ["foo#{sep}", "bar#{sep}", "baz#{sep}"]
          end

          it "should return the strings" do
            subject.lines(sep).to_a.should == ["foo#{sep}", "bar#{sep}", "baz#{sep}"]
          end
        end

        context "without trailing separator" do
          subject { described_class.new("foo#{sep}bar#{sep}baz") }

          it "should yield the strings" do
            got = []
            subject.lines(sep) do |x| got << x end
            got.should == ["foo#{sep}", "bar#{sep}", "baz"]
          end

          it "should return the strings" do
            subject.lines(sep).to_a.should == ["foo#{sep}", "bar#{sep}", "baz"]
          end
        end
      end
    end
  end
end
