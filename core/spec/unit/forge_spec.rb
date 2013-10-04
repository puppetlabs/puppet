require 'spec_helper'
require 'puppet/forge'
require 'net/http'
require 'puppet/module_tool'

describe Puppet::Forge do
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

  let(:forge) { Puppet::Forge.new("test_agent", SemVer.new("v1.0.0")) }

  def repository_responds_with(response)
    Puppet::Forge::Repository.any_instance.stubs(:make_http_request).returns(response)
  end

  it "returns a list of matches from the forge when there are matches for the search term" do
    response = stub(:body => response_body, :code => '200')
    repository_responds_with(response)

    forge.search('bacula').should == PSON.load(response_body)
  end

  context "when the connection to the forge fails" do
    before :each do
      repository_responds_with(stub(:body => '{}', :code => '404', :message => "not found"))
    end

    it "raises an error for search" do
      expect { forge.search('bacula') }.to raise_error Puppet::Forge::Errors::ResponseError, "Could not execute operation for 'bacula'. Detail: 404 not found."
    end

    it "raises an error for remote_dependency_info" do
      expect { forge.remote_dependency_info('puppetlabs', 'bacula', '0.0.1') }.to raise_error Puppet::Forge::Errors::ResponseError, "Could not execute operation for 'puppetlabs/bacula'. Detail: 404 not found."
    end
  end

  context "when the API responses with an error" do
    before :each do
      repository_responds_with(stub(:body => '{"error":"invalid module"}', :code => '410', :message => "Gone"))
    end

    it "raises an error for remote_dependency_info" do
      expect { forge.remote_dependency_info('puppetlabs', 'bacula', '0.0.1') }.to raise_error Puppet::Forge::Errors::ResponseError, "Could not execute operation for 'puppetlabs/bacula'. Detail: invalid module / 410 Gone."
    end
  end
end
