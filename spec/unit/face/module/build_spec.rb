require 'spec_helper'
require 'puppet/face'

describe "puppet module build" do
  subject { Puppet::Face[:module, :current] }

  describe "option validation" do
    context "without any options" do
      it "should require a path" do
        pattern = /wrong number of arguments/
        expect { subject.build }.to raise_error ArgumentError, pattern
      end
    end
  end

  describe "inline documentation" do
    subject { Puppet::Face[:module, :current].get_action :build }

    its(:summary)     { should =~ /build.*module/im }
    its(:description) { should =~ /build.*module/im }
    its(:returns)     { should =~ /pathname/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
