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
      before :each do
        subject.stubs(:console_has_color?).returns(true)
      end

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

    context "ansicolor not supported" do
      before :each do
        subject.stubs(:console_has_color?).returns(false)
      end

      it "should not colorize console output" do
        Puppet[:color] = true

        subject.expects(:console_color).never
        expect(subject.colorize(:black, message)).to eq(message)
      end

      it "should colorize html output" do
        Puppet[:color] = :html

        subject.expects(:html_color).with(color, message)
        subject.colorize(color, message)
      end
    end
  end

  context "on Windows in Ruby 1.x", :if => Puppet.features.microsoft_windows? && RUBY_VERSION =~ /^1./ do
    it "should define WideConsole" do
      expect(defined?(Puppet::Util::Colors::WideConsole)).to be_truthy
    end

    it "should define WideIO" do
      expect(defined?(Puppet::Util::Colors::WideIO)).to be_truthy
    end
  end

  context "on Windows in Ruby 2.x", :if => Puppet.features.microsoft_windows? && RUBY_VERSION =~ /^2./ do
    it "should not define WideConsole" do
      expect(defined?(Puppet::Util::Colors::WideConsole)).to be_falsey
    end

    it "should not define WideIO" do
      expect(defined?(Puppet::Util::Colors::WideIO)).to be_falsey
    end
  end
end
