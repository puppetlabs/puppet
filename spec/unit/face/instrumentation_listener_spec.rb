#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:instrumentation_listener, '0.0.1'] do
  it_should_behave_like "an indirector face"

  [:enable, :disable].each do |m|
    describe "when running ##{m}" do
      before(:each) do
        @listener = stub_everything 'listener'
        Puppet::Face[:instrumentation_listener, '0.0.1'].stubs(:find).returns(@listener)
        Puppet::Face[:instrumentation_listener, '0.0.1'].stubs(:save)
        Puppet::Util::Instrumentation::Listener.indirection.stubs(:terminus_class=)
      end

      it "should force the REST terminus" do
        Puppet::Util::Instrumentation::Listener.indirection.expects(:terminus_class=).with(:rest)
        subject.send(m, "dummy")
      end

      it "should find the named listener" do
        Puppet::Face[:instrumentation_listener, '0.0.1'].expects(:find).with("dummy").returns(@listener)
        subject.send(m, "dummy")
      end

      it "should #{m} the named listener" do
        @listener.expects(:enabled=).with( m == :enable )
        subject.send(m, "dummy")
      end

      it "should save finally the listener" do
        Puppet::Face[:instrumentation_listener, '0.0.1'].expects(:save).with(@listener)
        subject.send(m, "dummy")
      end
    end
  end
end
