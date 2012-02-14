require 'spec_helper'
require 'puppet/forge'
require 'net/http'
require 'puppet/module_tool'

describe Puppet::Forge::Forge do
  include PuppetSpec::Files

  let(:response_body) do
  <<-EOF
    [
      {
        "author": "puppetlabs",
        "name": "bacula",
        "tag_list": ["backup", "bacula"],
        "releases": [{"version": "0.0.1"}, {"version": "0.0.2"}],
        "full_name": "puppetlabs/bacula",
        "version": "0.0.2",
        "project_url": "http://github.com/puppetlabs/puppetlabs-bacula",
        "desc": "bacula"
      }
    ]
  EOF
  end
  let(:response) { stub(:body => response_body, :code => '200') }

  before do
    Puppet::Forge::Repository.any_instance.stubs(:make_http_request).returns(response)
    Puppet::Forge::Repository.any_instance.stubs(:retrieve).returns("/tmp/foo")
  end

  describe "the behavior of the search method" do
    context "when there are matches for the search term" do
      before do
        Puppet::Forge::Repository.any_instance.stubs(:make_http_request).returns(response)
      end

      it "should return a list of matches from the forge" do
        Puppet::Forge::Forge.search('bacula').should == PSON.load(response_body)
      end
    end

    context "when the connection to the forge fails" do
      let(:response)  { stub(:body => '[]', :code => '404') }

      it "should raise an error" do
        lambda { Puppet::Forge::Forge.search('bacula') }.should raise_error RuntimeError
      end
    end
  end

end
