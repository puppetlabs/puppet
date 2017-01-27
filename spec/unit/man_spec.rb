#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:man, :current] do
  let(:pager) { '/path/to/our/pager' }

  around do |example|
    oldpager = ENV['MANPAGER']
    ENV['MANPAGER'] = pager
    example.run
    ENV['MANPAGER'] = oldpager
  end

  it "exits with 0 when generating man documentation for each available application" do
    Puppet::Util.stubs(:which).with('ronn').returns(nil)
    Puppet::Util.stubs(:which).with(pager).returns(pager)

    Puppet::Application.available_application_names.each do |name|
      next if %w{man face_base indirection_base}.include? name

      klass = Puppet::Application.find('man')
      app = klass.new(Puppet::Util::CommandLine.new('puppet', ['man', name]))

      expect do
        IO.stubs(:popen).with(pager, 'w:UTF-8').yields($stdout)

        expect { app.run }.to exit_with(0)
      end.to_not have_printed(/undefined method `gsub'/)
    end
  end
end
