#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/package/ports/record'
require 'puppet/util/package/ports/options'

describe Puppet::Util::Package::Ports::Record do
  it { described_class.should be_a Puppet::Util::Package::Ports::Functions }

  describe "::std_fields" do
    it do
      expect { described_class.std_fields }.to raise_error NotImplementedError,
        "this method must be implemented in a subclass"
    end
  end

  describe "::default_fields" do
    it do
      expect { described_class.default_fields }.to raise_error NotImplementedError,
        "this method must be implemented in a subclass"
    end
  end

  describe "::deps_for_amend" do
    it do
      expect { described_class.deps_for_amend }.to raise_error NotImplementedError,
        "this method must be implemented in a subclass"
    end
  end

  describe "#amend(fields)" do
    [{}, {:name=>'bar-0.1.2', :path =>'/usr/ports/foo/bar'} ].each do |hash|
      context "on #{described_class}[#{hash.inspect}]" do
        subject {described_class[hash] }
        context "#amend([:pkgname, :portname, :portorigin])" do
          let(:fields) { [:pkgname, :portname, :portorigin] }
          it "calls #amend!([:pkgname, :portname, :portorigin]) once" do
            described_class.any_instance.expects(:amend!).once.with(fields)
            expect { subject.amend(fields)}.to_not raise_error
          end
          it "returns an instance of #{described_class.to_s}" do
            subject.amend(fields).should be_instance_of described_class
          end
          it "returns duplicate, not self" do
            s1 = subject
            s1.amend(fields).should_not equal s1
          end
        end
      end
    end
  end

  describe "#amend!(fields)" do
    hash = Hash[{:portname=>'bar', :portorigin => 'foo/bar22'}]
    context "on #{described_class}[#{hash.inspect}]" do
      subject { described_class[hash] }
      [
        # 1
        [
          [:options_files],
          {
            :options_files => [
              '/var/db/ports/bar/options',
              '/var/db/ports/bar/options.local',
              '/var/db/ports/foo_bar22/options',
              '/var/db/ports/foo_bar22/options.local',
            ]
          }
        ],
        # 1
        [
          [:options_file],
          { :options_file => '/var/db/ports/foo_bar22/options.local' }
        ],
        # 2
        [
          [:options_files, :options_file, :portname, :portorigin],
          {
            :options_files => [
              '/var/db/ports/bar/options',
              '/var/db/ports/bar/options.local',
              '/var/db/ports/foo_bar22/options',
              '/var/db/ports/foo_bar22/options.local',
            ],
            :options_file => '/var/db/ports/foo_bar22/options.local',
            :portname => 'bar',
            :portorigin => 'foo/bar22'
          }
        ],
        # 3.
        [
          [:options],
          { :options => 'loaded from /var/db/ports/foo_bar22/options.local' }
        ],
        # 4
        [
          [],
          { }
        ],
      ].each do |fields, result|
        context "#amend!(#{fields.inspect})" do
          let(:fields) { fields }
          let(:result) { result }
          it "changes self to #{result.inspect}" do
            if fields.include?(:options)
              Puppet::Util::Package::Ports::Options.stubs(:load).
                once.with([
                  '/var/db/ports/bar/options',
                  '/var/db/ports/bar/options.local',
                  '/var/db/ports/foo_bar22/options',
                  '/var/db/ports/foo_bar22/options.local'
                ]).returns('loaded from /var/db/ports/foo_bar22/options.local')
            end
            s = subject
            s.amend!(fields)
            s.should == result
          end
        end
      end
    end
  end
end

