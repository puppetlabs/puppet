require 'spec_helper'
require 'puppet/face'

describe "puppet module clean" do
  subject { Puppet::Face[:module, :current] }

  describe "option validation" do
    context "without any options" do
      it "should not require any arguments" do
        Puppet::Module::Tool::Applications::Cleaner.expects(:run).once
        subject.clean
      end
    end
  end

  describe "inline documentation" do
    subject { Puppet::Face[:module, :current].get_action :clean }

    its(:summary)     { should =~ /clean.*module/im }
    its(:description) { should =~ /clean.*module/im }
    its(:returns)     { should =~ /hash/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
