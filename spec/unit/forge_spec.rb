require 'spec_helper'
require 'puppet/forge'
require 'net/http'
require 'puppet/module_tool'

describe Puppet::Forge do
  let(:http_response) do
  <<-EOF
    {
      "pagination": {
        "limit": 1,
        "offset": 0,
        "first": "/v3/modules?limit=1&offset=0",
        "previous": null,
        "current": "/v3/modules?limit=1&offset=0",
        "next": null,
        "total": 1832
      },
      "results": [
        {
          "uri": "/v3/modules/puppetlabs-bacula",
          "name": "bacula",
          "downloads": 640274,
          "created_at": "2011-05-24 18:34:58 -0700",
          "updated_at": "2013-12-03 15:24:20 -0800",
          "owner": {
            "uri": "/v3/users/puppetlabs",
            "username": "puppetlabs",
            "gravatar_id": "fdd009b7c1ec96e088b389f773e87aec"
          },
          "current_release": {
            "uri": "/v3/releases/puppetlabs-bacula-0.0.2",
            "module": {
              "uri": "/v3/modules/puppetlabs-bacula",
              "name": "bacula",
              "owner": {
                "uri": "/v3/users/puppetlabs",
                "username": "puppetlabs",
                "gravatar_id": "fdd009b7c1ec96e088b389f773e87aec"
              }
            },
            "version": "0.0.2",
            "metadata": {
              "types": [],
              "license": "Apache 2.0",
              "checksums": { },
              "version": "0.0.2",
              "source": "git://github.com/puppetlabs/puppetlabs-bacula.git",
              "project_page": "https://github.com/puppetlabs/puppetlabs-bacula",
              "summary": "bacula",
              "dependencies": [ ],
              "author": "puppetlabs",
              "name": "puppetlabs-bacula"
            },
            "tags": [
              "backup",
              "bacula"
            ],
            "file_uri": "/v3/files/puppetlabs-bacula-0.0.2.tar.gz",
            "file_size": 67586,
            "file_md5": "bbf919d7ee9d278d2facf39c25578bf8",
            "downloads": 565041,
            "readme": "",
            "changelog": "",
            "license": "",
            "created_at": "2013-05-13 08:31:19 -0700",
            "updated_at": "2013-05-13 08:31:19 -0700",
            "deleted_at": null
          },
          "releases": [
            {
              "uri": "/v3/releases/puppetlabs-bacula-0.0.2",
              "version": "0.0.2"
            },
            {
              "uri": "/v3/releases/puppetlabs-bacula-0.0.1",
              "version": "0.0.1"
            }
          ],
          "homepage_url": "https://github.com/puppetlabs/puppetlabs-bacula",
          "issues_url": "https://projects.puppetlabs.com/projects/bacula/issues"
        }
      ]
    }
  EOF
  end

  let(:search_results) do
    JSON.parse(http_response)['results'].map do |hash|
      hash.merge(
        "author" => "puppetlabs",
        "name" => "bacula",
        "tag_list" => ["backup", "bacula"],
        "full_name" => "puppetlabs/bacula",
        "version" => "0.0.2",
        "project_url" => "https://github.com/puppetlabs/puppetlabs-bacula",
        "desc" => "bacula"
      )
    end
  end

  let(:release_response) do
    releases = JSON.parse(http_response)
    releases['results'] = []
    JSON.dump(releases)
  end

  let(:forge) { Puppet::Forge.new }

  it "returns a list of matches from the forge when there are matches for the search term" do
    stub_request(:get, "https://forgeapi.puppet.com/v3/modules?query=bacula").to_return(status: 200, body: http_response)

    expect(forge.search('bacula')).to eq(search_results)
  end

  context "when module_groups are defined" do
    before :each do
      Puppet[:module_groups] = "foo"
    end

    it "passes module_groups with search" do
      stub_request(:get, "https://forgeapi.puppet.com/v3/modules")
        .with(query: hash_including("module_groups" => "foo"))
        .to_return(status: 200, body: release_response)

      forge.search('bacula')
    end

    it "passes module_groups with fetch" do
      stub_request(:get, "https://forgeapi.puppet.com/v3/releases")
        .with(query: hash_including("module_groups" => "foo"))
        .to_return(status: 200, body: release_response)

      forge.fetch('puppetlabs-bacula')
    end
  end

  # See PUP-8008
  context "when multiple module_groups are defined" do
    context "with space seperator" do
      before :each do
        Puppet[:module_groups] = "foo bar"
      end

      it "passes module_groups with search" do
        stub_request(:get, %r{forgeapi.puppet.com/v3/modules}).with do |req|
          expect(req.uri.query).to match(/module_groups=foo%20bar/)
        end.to_return(status: 200, body: release_response)

        forge.search('bacula')
      end

      it "passes module_groups with fetch" do
        stub_request(:get, %r{forgeapi.puppet.com/v3/releases}).with do |req|
          expect(req.uri.query).to match(/module_groups=foo%20bar/)
        end.to_return(status: 200, body: release_response)

        forge.fetch('puppetlabs-bacula')
      end
    end

    context "with plus seperator" do
      before :each do
        Puppet[:module_groups] = "foo+bar"
      end

      it "passes module_groups with search" do
        stub_request(:get, %r{forgeapi.puppet.com/v3/modules}).with do |req|
          expect(req.uri.query).to match(/module_groups=foo%20bar/)
        end.to_return(status: 200, body: release_response)

        forge.search('bacula')
      end

      it "passes module_groups with fetch" do
        stub_request(:get, %r{forgeapi.puppet.com/v3/releases}).with do |req|
          expect(req.uri.query).to match(/module_groups=foo%20bar/)
        end.to_return(status: 200, body: release_response)

        forge.fetch('puppetlabs-bacula')
      end
    end

    # See PUP-8008
    context "when there are multiple pages of results" do
      before(:each) do
        stub_request(:get, %r{forgeapi.puppet.com}).with do |req|
          expect(req.uri.query).to match(/module_groups=foo%20bar/)
        end.to_return(status: 200, body: first_page)
          .to_return(status: 200, body: last_page)
      end

      context "with space seperator" do
        before(:each) do
          Puppet[:module_groups] = "foo bar"
        end

        let(:first_page) do
          resp = JSON.parse(http_response)
          resp['results'] = []
          resp['pagination']['next'] = "/v3/modules?limit=1&offset=1&module_groups=foo%20bar"
          JSON.dump(resp)
        end

        let(:last_page) do
          resp = JSON.parse(http_response)
          resp['results'] = []
          resp['pagination']['current'] = "/v3/modules?limit=1&offset=1&module_groups=foo%20bar"
          JSON.dump(resp)
        end

        it "traverses pages during search" do
          forge.search('bacula')
        end

        it "traverses pages during fetch" do
          forge.fetch('puppetlabs-bacula')
        end
      end

      context "with plus seperator" do
        before(:each) do
          Puppet[:module_groups] = "foo+bar"
        end

        let(:first_page) do
          resp = JSON.parse(http_response)
          resp['results'] = []
          resp['pagination']['next'] = "/v3/modules?limit=1&offset=1&module_groups=foo+bar"
          JSON.dump(resp)
        end

        let(:last_page) do
          resp = JSON.parse(http_response)
          resp['results'] = []
          resp['pagination']['current'] = "/v3/modules?limit=1&offset=1&module_groups=foo+bar"
          JSON.dump(resp)
        end

        it "traverses pages during search" do
          forge.search('bacula')
        end

        it "traverses pages during fetch" do
          forge.fetch('puppetlabs-bacula')
        end
      end
    end
  end

  context "when the connection to the forge fails" do
    before :each do
      stub_request(:get, /forgeapi.puppet.com/).to_return(status: [404, 'not found'])
    end

    it "raises an error for search" do
      expect { forge.search('bacula') }.to raise_error Puppet::Forge::Errors::ResponseError, "Request to Puppet Forge failed. Detail: 404 not found."
    end

    it "raises an error for fetch" do
      expect { forge.fetch('puppetlabs/bacula') }.to raise_error Puppet::Forge::Errors::ResponseError, "Request to Puppet Forge failed. Detail: 404 not found."
    end
  end

  context "when the API responds with an error" do
    it "raises an error for fetch" do
      stub_request(:get, /forgeapi.puppet.com/).to_return(status: [410, 'Gone'], body: '{"error":"invalid module"}')

      expect { forge.fetch('puppetlabs/bacula') }.to raise_error Puppet::Forge::Errors::ResponseError, "Request to Puppet Forge failed. Detail: 410 Gone."
    end
  end

  context "when the forge returns a module with unparseable dependencies" do
    it "ignores modules with unparseable dependencies" do
      response = JSON.parse(http_response)
      release = response['results'][0]['current_release']
      release['metadata']['dependencies'] = [{'name' => 'broken-garbage >= 1.0.0', 'version_requirement' => 'banana'}]
      response['results'] = [release]

      stub_request(:get, /forgeapi.puppet.com/).to_return(status: 200, body: JSON.dump(response))

      expect(forge.fetch('puppetlabs/bacula')).to be_empty
    end
  end
end
