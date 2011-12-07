require 'spec_helper'
require 'puppet/face'

describe "puppet module search" do
  subject { Puppet::Face[:module, :current] }

  let(:options) do
    {}
  end

  describe "option validation" do
    context "without any options" do
      it "should require a search term" do
        pattern = /wrong number of arguments/
        expect { subject.search }.to raise_error ArgumentError, pattern
      end
    end

    it "should accept the --module-repository option" do
      options[:module_repository] = "http://forge.example.com"
      Puppet::Module::Tool::Applications::Searcher.expects(:run).with("puppetlabs-apache", options).once
      subject.search("puppetlabs-apache", options)
    end
  end

  describe "inline documentation" do
    subject { Puppet::Face[:module, :current].get_action :search }

    its(:summary)     { should =~ /search.*module/im }
    its(:description) { should =~ /search.*module/im }
    its(:returns)     { should =~ /array/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
