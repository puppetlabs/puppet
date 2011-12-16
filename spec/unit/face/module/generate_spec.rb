require 'spec_helper'
require 'puppet/face'

describe "puppet module generate" do
  subject { Puppet::Face[:module, :current] }

  describe "option validation" do
    context "without any options" do
      it "should require name" do
        pattern = /wrong number of arguments/
        expect { subject.generate }.to raise_error ArgumentError, pattern
      end
    end
  end

  describe "inline documentation" do
    subject { Puppet::Face[:module, :current].get_action :generate }

    its(:summary)     { should =~ /generate.*module/im }
    its(:description) { should =~ /generate.*module/im }
    its(:returns)     { should =~ /array/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
