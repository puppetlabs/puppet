#!/usr/bin/env ruby
require 'spec_helper'

describe Puppet::Util::Colors do
  include Puppet::Util::Colors

  let (:message) { 'a message' }
  let (:color) { :black }
  let (:subject) { self }

  describe ".console_color" do
    it { is_expected.to respond_to :console_color }

    it "should generate ANSI escape sequences" do
      expect(subject.console_color(color, message)).to eq("\e[0;30m#{message}\e[0m")
    end
  end

  describe ".html_color" do
    it { is_expected.to respond_to :html_color }

    it "should generate an HTML span element and style attribute" do
      expect(subject.html_color(color, message)).to match(/<span style=\"color: #FFA0A0\">#{message}<\/span>/)
    end
  end

  describe ".colorize" do
    it { is_expected.to respond_to :colorize }

    context "ansicolor supported" do
      it "should colorize console output" do
        Puppet[:color] = true

        subject.expects(:console_color).with(color, message)
        subject.colorize(:black, message)
      end

      it "should not colorize unknown color schemes" do
        Puppet[:color] = :thisisanunknownscheme

        expect(subject.colorize(:black, message)).to eq(message)
      end
    end
  end
end
