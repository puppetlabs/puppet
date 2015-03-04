#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/interface'

class Puppet::Interface::TinyDocs::Test
  include Puppet::Interface::TinyDocs
  attr_accessor :name, :options, :display_global_options
  def initialize
    self.name    = "tinydoc-test"
    self.options = []
    self.display_global_options = []
  end

  def get_option(name)
    Puppet::Interface::Option.new(nil, "--#{name}")
  end
end

describe Puppet::Interface::TinyDocs do
  subject { Puppet::Interface::TinyDocs::Test.new }

  context "#build_synopsis" do
    before :each do
      subject.options = [:foo, :bar]
    end

    it { is_expected.to respond_to :build_synopsis }

    it "should put a space between options (#7828)" do
      expect(subject.build_synopsis('baz')).to match(/#{Regexp.quote('[--foo] [--bar]')}/)
    end
  end
end
