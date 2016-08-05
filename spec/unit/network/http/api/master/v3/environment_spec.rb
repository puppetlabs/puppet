require 'spec_helper'

require 'puppet/network/http'

describe Puppet::Network::HTTP::API::Master::V3::Environment do
  let(:response) { Puppet::Network::HTTP::MemoryResponse.new }

  let(:environment) { Puppet::Node::Environment.create(:production, [], '/manifests') }
  let(:loader) { Puppet::Environments::Static.new(environment) }

  around :each do |example|
    Puppet[:app_management] = true
    Puppet.override(:environments => loader) do
      Puppet::Type.newtype :sql, :is_capability => true do
        newparam :name, :namevar => true
      end
      Puppet::Type.newtype :http, :is_capability => true do
        newparam :name, :namevar => true
      end
      example.run
    end
  end

  it "returns the environment catalog" do
    request = Puppet::Network::HTTP::Request.from_hash(:headers => { 'accept' => 'application/json' }, :routing_path => "environment/production")

    subject.call(request, response)

    expect(response.code).to eq(200)

    catalog = JSON.parse(response.body)
    expect(catalog['environment']).to eq('production')
    expect(catalog['applications']).to eq({})
  end

  describe "processing the environment catalog" do
    def compile_site_to_catalog(site, code_id=nil)
      Puppet[:code] = <<-MANIFEST
      define db() { }
      Db produces Sql { }

      define web() { }
      Web consumes Sql { }
      Web produces Http { }

      application myapp() {
        db { $name:
          export => Sql[$name],
        }
        web { $name:
          consume => Sql[$name],
          export => Http[$name],
        }
      }
      site {
        #{site}
      }
      MANIFEST
      Puppet::Parser::EnvironmentCompiler.compile(environment, code_id).filter { |r| r.virtual? }
    end


    it "includes specified applications" do
      catalog = compile_site_to_catalog <<-MANIFEST
      myapp { 'test':
        nodes => {
          Node['foo.example.com'] => Db['test'],
          Node['bar.example.com'] => Web['test'],
        },
      }
      MANIFEST

      result = subject.build_environment_graph(catalog)

      expect(result[:applications]).to eq({'Myapp[test]' =>
                                            {'Db[test]' => {:produces => ['Sql[test]'], :consumes => [], :node => 'foo.example.com'},
                                             'Web[test]' => {:produces => ['Http[test]'], :consumes => ['Sql[test]'], :node => 'bar.example.com'}}})
    end

    it "fails if a component isn't mapped to a node" do
      catalog = compile_site_to_catalog <<-MANIFEST
      myapp { 'test':
        nodes => {
          Node['foo.example.com'] => Db['test'],
        }
      }
      MANIFEST

      expect { subject.build_environment_graph(catalog) }.to raise_error(Puppet::ParseError, /has components without assigned nodes/)
    end

    it "fails if a non-existent component is mapped to a node" do
      catalog = compile_site_to_catalog <<-MANIFEST
      myapp { 'test':
        nodes => {
          Node['foo.example.com'] => [ Db['test'], Web['test'], Web['foobar'] ],
        }
      }
      MANIFEST

      expect { subject.build_environment_graph(catalog) }.to raise_error(Puppet::ParseError, /assigns nodes to non-existent components/)
    end

    it "fails if a component is mapped twice" do
      catalog = compile_site_to_catalog <<-MANIFEST
      myapp { 'test':
        nodes => {
          Node['foo.example.com'] => [ Db['test'], Web['test'] ],
          Node['bar.example.com'] => [ Web['test'] ],
        }
      }
      MANIFEST

      expect { subject.build_environment_graph(catalog) }.to raise_error(Puppet::ParseError, /assigns multiple nodes to component/)
    end

    it "fails if an application maps components from other applications" do
      catalog = compile_site_to_catalog <<-MANIFEST
      myapp { 'test':
        nodes => {
          Node['foo.example.com'] => [ Db['test'], Web['test'] ],
        }
      }
      myapp { 'other':
        nodes => {
          Node['foo.example.com'] => [ Db['other'], Web['other'], Web['test'] ],
        }
      }
      MANIFEST

      expect { subject.build_environment_graph(catalog) }.to raise_error(Puppet::ParseError, /assigns nodes to non-existent components/)
    end

    it "doesn't fail if the catalog contains a node cycle" do
      catalog = compile_site_to_catalog <<-MANIFEST
      myapp { 'test':
        nodes => {
          Node['foo.example.com'] => [ Db['test'] ],
          Node['bar.example.com'] => [ Web['test'] ],
        }
      }
      myapp { 'other':
        nodes => {
          Node['foo.example.com'] => [ Web['other'] ],
          Node['bar.example.com'] => [ Db['other'] ],
        }
      }
      MANIFEST

      expect { subject.build_environment_graph(catalog) }.not_to raise_error
    end
  end

  it "returns 404 if the environment doesn't exist" do
    request = Puppet::Network::HTTP::Request.from_hash(:routing_path => "environment/development")

    expect { subject.call(request, response) }.to raise_error(Puppet::Network::HTTP::Error::HTTPNotFoundError, /development is not a known environment/)
  end

  it "omits code_id if unspecified" do
    request = Puppet::Network::HTTP::Request.from_hash(:routing_path => "environment/production")

    subject.call(request, response)

    expect(JSON.parse(response.body)['code_id']).to be_nil
  end

  it "includes code_id if specified" do
    request = Puppet::Network::HTTP::Request.from_hash(:params => {:code_id => '12345'}, :routing_path => "environment/production")

    subject.call(request, response)

    expect(JSON.parse(response.body)['code_id']).to eq('12345')
  end

  it "uses code_id from the catalog if it differs from the request" do
    request = Puppet::Network::HTTP::Request.from_hash(:params => {:code_id => '12345'}, :routing_path => "environment/production")

    Puppet::Resource::Catalog.any_instance.stubs(:code_id).returns('67890')

    subject.call(request, response)

    expect(JSON.parse(response.body)['code_id']).to eq('67890')
  end
end

