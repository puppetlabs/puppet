require 'spec_helper'
require 'puppet/forge'
require 'net/http'

describe Puppet::Forge::Forge do
  before do
    Puppet::Forge::Repository.any_instance.stubs(:make_http_request).returns(response)
    Puppet::Forge::Repository.any_instance.stubs(:retrieve).returns("/tmp/foo")
  end

  let(:forge) { forge = Puppet::Forge::Forge.new('http://forge.puppetlabs.com') }

  describe "the behavior of the search method" do
    context "when there are matches for the search term" do
      before do
        Puppet::Forge::Repository.any_instance.stubs(:make_http_request).returns(response)
      end

      let(:response) { stub(:body => response_body, :code => '200') }
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

      it "should return a list of matches from the forge" do
        forge.search('bacula').should == PSON.load(response_body)
      end
    end

    context "when the connection to the forge fails" do
      let(:response)  { stub(:body => '[]', :code => '404') }

      it "should raise an error" do
        lambda { forge.search('bacula') }.should raise_error RuntimeError
      end
    end
  end

  describe "the behavior of the get_release_package method" do

    let(:response) do
      response = mock()
      response.stubs(:body).returns('{"file": "/system/releases/p/puppetlabs/puppetlabs-apache-0.0.3.tar.gz", "version": "0.0.3"}')
      response
    end

    context "when source is not filesystem or repository" do
      it "should raise an error" do
        params = { :source => 'foo' }
        lambda { forge.get_release_package(params) }.should
          raise_error(ArgumentError, "Could not determine installation source")
      end
    end

    context "when the source is a repository" do
      let(:params) do
        {
          :source  => :repository,
          :author  => 'fakeauthor',
          :modname => 'fakemodule',
          :version => '0.0.1'
        }
      end

      it "should require author" do
        params.delete(:author)
        lambda { forge.get_release_package(params) }.should
          raise_error(ArgumentError, ":author and :modename required")
      end

      it "should require modname" do
        params.delete(:modname)
        lambda { forge.get_release_package(params) }.should
          raise_error(ArgumentError, ":author and :modename required")
      end

      it "should download the release package" do
        forge.get_release_package(params).should == "/tmp/foo"
      end
    end

    context "when the source is a filesystem" do
      it "should require filename" do
        params = { :source => :filesystem }
        lambda { forge.get_release_package(params) }.should
          raise_error(ArgumentError, ":filename required")
      end
    end
  end

  describe "the behavior of the get_releases method" do
    let(:response) do
      response = mock()
      response.stubs(:body).returns('{"releases": [{"version": "0.0.1"}, {"version": "0.0.2"}, {"version": "0.0.3"}]}')
      response
    end

    it "should return a list of module releases" do
      forge.get_releases('fakeauthor', 'fakemodule').should == ["0.0.1", "0.0.2", "0.0.3"]
    end
  end
end
