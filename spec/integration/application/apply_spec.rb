require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/compiler'
require 'puppet_spec/https'

describe "apply", unless: Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files

  let(:apply) { Puppet::Application[:apply] }

  before :each do
    Puppet[:reports] = "none"
    # Let exceptions be raised instead of exiting
    allow_any_instance_of(Puppet::Application).to receive(:exit_on_fail).and_yield
  end

  describe "when applying provided catalogs" do
    it "can apply catalogs provided in a file in json" do
      file_to_create = tmpfile("json_catalog")
      catalog = Puppet::Resource::Catalog.new('mine', Puppet.lookup(:environments).get(Puppet[:environment]))
      resource = Puppet::Resource.new(:file, file_to_create, :parameters => {:content => "my stuff"})
      catalog.add_resource resource

      apply.command_line.args = ['--catalog', file_containing("manifest", catalog.to_json)]
      expect {
        apply.run
      }.to output(/ensure: defined content as/).to_stdout

      expect(Puppet::FileSystem.exist?(file_to_create)).to be_truthy
      expect(File.read(file_to_create)).to eq("my stuff")
    end

    context 'and pcore types are available' do
      let(:envdir) { my_fixture('environments') }
      let(:env_name) { 'spec' }

      before(:each) do
        Puppet[:environmentpath] = envdir
        Puppet[:environment] = env_name
      end

      it 'does not load the pcore type' do
        apply = Puppet::Application[:apply]
        apply.command_line.args = [ '-e', "Applytest { message => 'the default'} applytest { 'applytest was here': }" ]

        expect {
          apply.run
        }.to exit_with(0)
         .and output(a_string_matching(
           /the Puppet::Type says hello/
         ).and matching(
           /applytest was here/
         )).to_stdout
      end
    end

    context 'from environment with a pcore defined resource type' do
      include PuppetSpec::Compiler

      let(:envdir) { my_fixture('environments') }
      let(:env_name) { 'spec' }
      let(:environments) { Puppet::Environments::Directories.new(envdir, []) }
      let(:env) { Puppet::Node::Environment.create(:'spec', [File.join(envdir, 'spec', 'modules')]) }
      let(:node) { Puppet::Node.new('test', :environment => env) }

      around(:each) do |example|
        Puppet::Type.rmtype(:applytest)
        Puppet[:environment] = env_name
        Puppet.override(:environments => environments, :current_environment => env) do
          example.run
        end
      end

      it 'does not load the pcore type' do
        catalog = compile_to_catalog('applytest { "applytest was here":}', node)
        apply.command_line.args = ['--catalog', file_containing('manifest', catalog.to_json)]

        Puppet[:environmentpath] = envdir
        expect_any_instance_of(Puppet::Pops::Loader::Runtime3TypeLoader).not_to receive(:find)
        expect {
          apply.run
        }.to output(/the Puppet::Type says hello.*applytest was here/m).to_stdout
      end

      # Test just to verify that the Pcore Resource Type and not the Ruby one is produced when the catalog is produced
      it 'loads pcore resource type instead of ruby resource type during compile' do
        Puppet[:code] = 'applytest { "applytest was here": }'
        compiler = Puppet::Parser::Compiler.new(node)
        tn = Puppet::Pops::Loader::TypedName.new(:resource_type_pp, 'applytest')
        rt = Puppet::Pops::Resource::ResourceTypeImpl.new('applytest', [Puppet::Pops::Resource::Param.new(String, 'message')], [Puppet::Pops::Resource::Param.new(String, 'name', true)])

        expect(compiler.loaders.runtime3_type_loader.instance_variable_get(:@resource_3x_loader)).to receive(:set_entry).once.with(tn, rt, instance_of(String))
          .and_return(Puppet::Pops::Loader::Loader::NamedEntry.new(tn, rt, nil))
        expect {
          compiler.compile
        }.not_to output(/the Puppet::Type says hello/).to_stdout
      end

      it "does not fail when pcore type is loaded twice" do
        Puppet[:code] = 'applytest { xyz: alias => aptest }; Resource[applytest]'
        compiler = Puppet::Parser::Compiler.new(node)
        expect { compiler.compile }.not_to raise_error
      end

      it "does not load the ruby type when using function 'defined()' on a loaded resource that is missing from the catalog" do
        # Ensure that the Resource[applytest,foo] is loaded'
        eval_and_collect_notices('applytest { xyz: }', node)

        # Ensure that:
        # a) The catalog contains aliases (using a name for the abc resource ensures this)
        # b) That Resource[applytest,xyz] is not defined in the catalog (although it's loaded)
        # c) That this doesn't trigger a load of the Puppet::Type
        notices = eval_and_collect_notices('applytest { abc: name => some_alias }; notice(defined(Resource[applytest,xyz]))', node)
        expect(notices).to include('false')
        expect(notices).not_to include('the Puppet::Type says hello')
      end

      it 'does not load the ruby type when when referenced from collector during compile' do
        notices = eval_and_collect_notices("@applytest { 'applytest was here': }\nApplytest<| title == 'applytest was here' |>", node)
        expect(notices).not_to include('the Puppet::Type says hello')
      end

      it 'does not load the ruby type when when referenced from exported collector during compile' do
        notices = eval_and_collect_notices("@@applytest { 'applytest was here': }\nApplytest<<| |>>", node)
        expect(notices).not_to include('the Puppet::Type says hello')
      end
    end
  end

  context 'from environment with pcore object types' do
    include PuppetSpec::Compiler

    let!(:envdir) { Puppet[:environmentpath] }
    let(:env_name) { 'spec' }
    let(:dir_structure) {
      {
        'environment.conf' => <<-CONF,
          rich_data = true
        CONF
        'modules' => {
          'mod' => {
            'types' => {
              'streetaddress.pp' => <<-PUPPET,
                type Mod::StreetAddress = Object[{
                  attributes => {
                    'street' => String,
                    'zipcode' => String,
                    'city' => String,
                  }
                }]
              PUPPET
              'address.pp' => <<-PUPPET,
                type Mod::Address = Object[{
                  parent => Mod::StreetAddress,
                  attributes => {
                    'state' => String
                  }
                }]
              PUPPET
              'contact.pp' => <<-PUPPET,
                type Mod::Contact = Object[{
                  attributes => {
                    'address' => Mod::Address,
                    'email' => String
                  }
                }]
              PUPPET
            },
            'manifests' => {
              'init.pp' => <<-PUPPET,
                define mod::person(Mod::Contact $contact) {
                  notify { $title: }
                  notify { $contact.address.street: }
                  notify { $contact.address.zipcode: }
                  notify { $contact.address.city: }
                  notify { $contact.address.state: }
                }

                class mod {
                  mod::person { 'Test Person':
                    contact => Mod::Contact(
                      Mod::Address('The Street 23', '12345', 'Some City', 'A State'),
                      'test@example.com')
                  }
                }
              PUPPET
            }
          }
        }
      }
    }

    let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(envdir, env_name, 'modules')]) }
    let(:node) { Puppet::Node.new('test', :environment => env) }

    before(:each) do
      dir_contained_in(envdir, env_name => dir_structure)
      PuppetSpec::Files.record_tmp(File.join(envdir, env_name))
    end

    it 'can compile the catalog' do
      compile_to_catalog('include mod', node)
    end

    it 'can apply the catalog with no warning' do
      logs = []
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        catalog = compile_to_catalog('include mod', node)
        Puppet[:environment] = env_name
        handler = Puppet::Network::FormatHandler.format(:rich_data_json)
        apply.command_line.args = ['--catalog', file_containing('manifest', handler.render(catalog))]
        expect {
          apply.run
        }.to output(%r{Notify\[The Street 23\]/message: defined 'message' as 'The Street 23'}).to_stdout
      end
      # expected to have no warnings
      expect(logs.select { |log| log.level == :warning }.map { |log| log.message }).to be_empty
    end
  end

  it "raises if the environment directory does not exist" do
    manifest = file_containing("manifest.pp", "notice('it was applied')")
    apply.command_line.args = [manifest]

    special = Puppet::Node::Environment.create(:special, [])
    Puppet.override(:current_environment => special) do
      Puppet[:environment] = 'special'
      expect {
        apply.run
      }.to raise_error(Puppet::Environments::EnvironmentNotFound,
                       /Could not find a directory environment named 'special' anywhere in the path/)
    end
  end

  it "adds environment to the $server_facts variable" do
    manifest = file_containing("manifest.pp", "notice(\"$server_facts\")")
    apply.command_line.args = [manifest]

    expect {
      apply.run
    }.to exit_with(0)
     .and output(/{environment => production}/).to_stdout
  end

  it "applies a given file even when an ENC is configured", :unless => Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
    manifest = file_containing("manifest.pp", "notice('specific manifest applied')")
    enc = script_containing('enc_script',
      :windows => '@echo classes: []' + "\n" + '@echo environment: special',
      :posix   => '#!/bin/sh' + "\n" + 'echo "classes: []"' + "\n" + 'echo "environment: special"')

    Dir.mkdir(File.join(Puppet[:environmentpath], "special"), 0755)

    special = Puppet::Node::Environment.create(:special, [])
    Puppet.override(:current_environment => special) do
      Puppet[:environment] = 'special'
      Puppet[:node_terminus] = 'exec'
      Puppet[:external_nodes] = enc
      apply.command_line.args = [manifest]
      expect {
        apply.run
      }.to exit_with(0)
       .and output(/Notice: Scope\(Class\[main\]\): specific manifest applied/).to_stdout
    end
  end

  context "handles errors" do
    it "logs compile errors once" do
      apply.command_line.args = ['-e', '08']
      expect {
        apply.run
      }.to exit_with(1)
       .and output(/Not a valid octal number/).to_stderr
    end

    it "logs compile post processing errors once" do
      path = File.expand_path('/tmp/content_file_test.Q634Dlmtime')
      apply.command_line.args = ['-e', "file { '#{path}':
        content => 'This is the test file content',
        ensure => present,
        checksum => mtime
      }"]

      expect {
        apply.run
      }.to exit_with(1)
       .and output(/Compiled catalog/).to_stdout
       .and output(/You cannot specify content when using checksum/).to_stderr
    end
  end

  context "with a module in an environment" do
    let(:envdir) { tmpdir('environments') }
    let(:modulepath) { File.join(envdir, 'spec', 'modules') }
    let(:execute) { 'include amod' }

    before(:each) do
      dir_contained_in(envdir, {
        "spec" => {
          "modules" => {
            "amod" => {
              "manifests" => {
                "init.pp" => "class amod{ notice('amod class included') }"
              }
            }
          }
        }
      })

      Puppet[:environmentpath] = envdir
    end

    context "given a modulepath" do
      let(:args) { ['-e', execute] }

      before :each do
        Puppet[:modulepath] = modulepath

        apply.command_line.args = args
      end

      it "looks in modulepath even when the default directory environment exists" do
        expect {
          apply.run
        }.to exit_with(0)
         .and output(/amod class included/).to_stdout
      end

      it "looks in modulepath even when given a specific directory --environment" do
        apply.command_line.args = args << '--environment' << 'production'

        expect {
          apply.run
        }.to exit_with(0)
         .and output(/amod class included/).to_stdout
      end

      it "looks in modulepath when given multiple paths in modulepath" do
        Puppet[:modulepath] = [tmpdir('notmodulepath'), modulepath].join(File::PATH_SEPARATOR)

        expect {
          apply.run
        }.to exit_with(0)
         .and output(/amod class included/).to_stdout
      end
    end

    context "with an ENC" do
      let(:enc) do
        script_containing('enc_script',
          :windows => '@echo environment: spec',
          :posix   => '#!/bin/sh' + "\n" + 'echo "environment: spec"')
      end

      before :each do
        Puppet[:node_terminus] = 'exec'
        Puppet[:external_nodes] = enc
      end

      it "should use the environment that the ENC mandates" do
        apply.command_line.args = ['-e', execute]

        expect {
          apply.run
       }.to exit_with(0)
        .and output(a_string_matching(/amod class included/)
        .and matching(/Compiled catalog for .* in environment spec/)).to_stdout
      end

      it "should prefer the ENC environment over the configured one and emit a warning" do
        apply.command_line.args = ['-e', execute, '--environment', 'production']

        expect {
          apply.run
        }.to exit_with(0)
         .and output(a_string_matching('amod class included')
         .and matching(/doesn't match server specified environment/)).to_stdout
      end
    end
  end

  context 'when applying from file' do
    include PuppetSpec::Compiler

    let(:env_dir) { tmpdir('environments') }
    let(:execute) { 'include amod' }
    let(:rich_data) { false }
    let(:env_name) { 'spec' }
    let(:populated_env_dir) do
      dir_contained_in(env_dir, {
        env_name => {
          'modules' => {
            'amod' => {
              'manifests' => {
                'init.pp' => <<-EOF
class amod {
  notify { rx: message => /[Rr]eg[Ee]xp/ }
  notify { bin: message => Binary('w5ZzdGVuIG1lZCByw7ZzdGVuCg==') }
  notify { ver: message  => SemVer('2.3.1') }
  notify { vrange: message => SemVerRange('>=2.3.0') }
  notify { tspan: message => Timespan(3600) }
  notify { tstamp: message => Timestamp('2012-03-04T18:15:11.001') }
}

class amod::bad_type {
  notify { bogus: message => amod::bogus() }
}
              EOF
              },
              'lib' => {
                'puppet' => {
                  'functions' => {
                    'amod' => {
                      'bogus.rb' => <<-RUBY
                        # Function that leaks an object that is not recognized in the catalog
                        Puppet::Functions.create_function(:'amod::bogus') do
                          def bogus()
                            Time.new(2016, 10, 6, 23, 51, 14, '+02:00')
                          end
                        end
                      RUBY
                    }
                  }
                }
              }
            }
          }
        }
      })
      env_dir
    end

    let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, 'spec', 'modules')]) }
    let(:node) { Puppet::Node.new('test', :environment => env) }

    before(:each) do
      Puppet[:rich_data] = rich_data
      Puppet.push_context(:loaders => Puppet::Pops::Loaders.new(env))
    end

    after(:each) do
      Puppet.pop_context()
    end

    context 'and the file is not serialized with rich_data' do
      # do not want to stub out behavior in tests
      before :each do
        Puppet[:strict] = :warning
      end

      it 'will notify a string that is the result of Regexp#inspect (from Runtime3xConverter)' do
        catalog = compile_to_catalog(execute, node)
        apply.command_line.args = ['--catalog', file_containing('manifest', catalog.to_json)]
        expect(apply).to receive(:apply_catalog) do |cat|
          expect(cat.resource(:notify, 'rx')['message']).to be_a(String)
          expect(cat.resource(:notify, 'bin')['message']).to be_a(String)
          expect(cat.resource(:notify, 'ver')['message']).to be_a(String)
          expect(cat.resource(:notify, 'vrange')['message']).to be_a(String)
          expect(cat.resource(:notify, 'tspan')['message']).to be_a(String)
          expect(cat.resource(:notify, 'tstamp')['message']).to be_a(String)
        end

        apply.run
      end

      it 'will notify a string that is the result of to_s on uknown data types' do
        json = compile_to_catalog('include amod::bad_type', node).to_json
        apply.command_line.args = ['--catalog', file_containing('manifest', json)]
        expect(apply).to receive(:apply_catalog) do |catalog|
          expect(catalog.resource(:notify, 'bogus')['message']).to be_a(String)
        end

        apply.run
      end

      it 'will log a warning that a value of unknown type is converted into a string' do
        logs = []
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          compile_to_catalog('include amod::bad_type', node).to_json
        end
        logs = logs.select { |log| log.level == :warning }.map { |log| log.message }
        expect(logs.empty?).to be_falsey
        expect(logs[0]).to eql("Notify[bogus]['message'] contains a Time value. It will be converted to the String '2016-10-06 23:51:14 +0200'")
      end
    end

    context 'and the file is serialized with rich_data' do
      it 'will notify a regexp using Regexp#to_s' do
        catalog = compile_to_catalog(execute, node)
        serialized_catalog = Puppet.override(rich_data: true) do
          catalog.to_json
        end
        apply.command_line.args = ['--catalog', file_containing('manifest', serialized_catalog)]
        expect(apply).to receive(:apply_catalog) do |cat|
          expect(cat.resource(:notify, 'rx')['message']).to be_a(Regexp)
          # The resource return in this expect is a String, but since it was a Binary type that
          # was converted with `resolve_and_replace`, we want to make sure that the encoding
          # of that string is the expected ASCII-8BIT.
          expect(cat.resource(:notify, 'bin')['message'].encoding.inspect).to include('ASCII-8BIT')
          expect(cat.resource(:notify, 'ver')['message']).to be_a(SemanticPuppet::Version)
          expect(cat.resource(:notify, 'vrange')['message']).to be_a(SemanticPuppet::VersionRange)
          expect(cat.resource(:notify, 'tspan')['message']).to be_a(Puppet::Pops::Time::Timespan)
          expect(cat.resource(:notify, 'tstamp')['message']).to be_a(Puppet::Pops::Time::Timestamp)
        end

        apply.run
      end
    end
  end

  context 'puppet file sources' do
    let(:env_name) { 'dev' }
    let(:env_dir) { File.join(Puppet[:environmentpath], env_name) }
    let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(env_dir, 'modules')]) }
    let(:node) { Puppet::Node.new(Puppet[:certname], environment: environment) }

    before :each do
      Puppet[:environment] = env_name
      Puppet::FileSystem.mkpath(env_dir)
    end

    it "recursively copies a directory from a module" do
      dir = File.join(env.full_modulepath, 'amod', 'files', 'dir1', 'dir2')
      Puppet::FileSystem.mkpath(dir)
      File.write(File.join(dir, 'file'), 'content from the module')

      base_dir = tmpdir('apply_spec_base')
      manifest = file_containing("manifest.pp", <<-MANIFEST)
        file { "#{base_dir}/dir1":
          ensure  => file,
          source  => "puppet:///modules/amod/dir1",
          recurse => true,
        }
      MANIFEST

      expect {
        apply.command_line.args << manifest
        apply.run
      }.to exit_with(0)
       .and output(a_string_matching(
         /dir1\]\/ensure: created/
      ).and matching(
         /dir1\/dir2\]\/ensure: created/
      ).and matching(
         /dir1\/dir2\/file\]\/ensure: defined content as '{sha256}b37c1d77e09471b3139b2cdfee449fd8ba72ebf7634d52023aff0c0cd088cf1b'/
      )).to_stdout

      dest_file = File.join(base_dir, 'dir1', 'dir2', 'file')
      expect(File.read(dest_file)).to eq("content from the module")
    end
  end

  context 'http file sources' do
    include_context 'https client'

    it "requires the caller to URL encode special characters in the request path and query" do
      Puppet[:server] = '127.0.0.1'
      request = nil

      response_proc = -> (req, res) {
        request = req

        res['Content-Type'] = 'text/plain'
        res.body = "from the server"
      }

      https = PuppetSpec::HTTPSServer.new
      https.start_server(response_proc: response_proc) do |https_port|
        dest = tmpfile('http_file_source')

        # spaces in path are encoded as %20 and '[' in query is encoded as %5B,
        # but ':', '=', '-' are not encoded
        manifest = file_containing("manifest.pp", <<~MANIFEST)
          file { "#{dest}":
            ensure  => file,
            source  => "https://#{Puppet[:server]}:#{https_port}/path%20to%20file?x=b%5Bc&sv=2019-02-02&st=2020-07-28T20:18:53Z&se=2020-07-28T21:03:00Z&sr=b&sp=r&sig=JaZhcqxT4akJcOwUdUGrQB2m1geUoh89iL8WMag8a8c=",
          }
        MANIFEST

        expect {
          apply.command_line.args << manifest
          apply.run
        }.to exit_with(0)
         .and output(%r{Main/File\[#{dest}\]/ensure: defined content as}).to_stdout

        expect(request.path).to eq('/path to file')
        expect(request.query).to include('x' => 'b[c')
        expect(request.query).to include('sig' => 'JaZhcqxT4akJcOwUdUGrQB2m1geUoh89iL8WMag8a8c=')
      end
    end
  end

  context 'http report processor' do
    include_context 'https client'

    before :each do
      Puppet[:reports] = 'http'
    end

    let(:unknown_server) do
      unknown_ca_cert = cert_fixture('unknown-ca.pem')
      PuppetSpec::HTTPSServer.new(
        ca_cert: unknown_ca_cert,
        server_cert: cert_fixture('unknown-127.0.0.1.pem'),
        server_key: key_fixture('unknown-127.0.0.1-key.pem')
      )
    end

    it 'submits a report via reporturl' do
      report = nil

      response_proc = -> (req, res) {
        report = Puppet::Transaction::Report.convert_from(:yaml, req.body)
      }

      https = PuppetSpec::HTTPSServer.new
      https.start_server(response_proc: response_proc) do |https_port|
        Puppet[:reporturl] = "https://127.0.0.1:#{https_port}/reports/upload"

        expect {
          apply.command_line.args = ['-e', 'notify { "hi": }']
          apply.run
        }.to exit_with(0)
         .and output(/Applied catalog/).to_stdout

        expect(report).to be_a(Puppet::Transaction::Report)
        expect(report.resource_statuses['Notify[hi]']).to be_a(Puppet::Resource::Status)
      end
    end

    it 'rejects an HTTPS report server whose root cert is not the puppet CA' do
      unknown_server.start_server do |https_port|
        Puppet[:reporturl] = "https://127.0.0.1:#{https_port}/reports/upload"

        # processing the report happens after the transaction is finished,
        # so we expect exit code 0, with a later failure on stderr
        expect {
          apply.command_line.args = ['-e', 'notify { "hi": }']
          apply.run
        }.to exit_with(0)
         .and output(/Applied catalog/).to_stdout
         .and output(/Report processor failed: certificate verify failed \[self.signed certificate in certificate chain for CN=Unknown CA\]/).to_stderr
      end
    end

    it 'accepts an HTTPS report servers whose cert is in the system CA store' do
      Puppet[:report_include_system_store] = true
      report = nil

      response_proc = -> (req, res) {
        report = Puppet::Transaction::Report.convert_from(:yaml, req.body)
      }

      # create a temp cacert bundle
      ssl_file = tmpfile('systemstore')
      File.write(ssl_file, unknown_server.ca_cert.to_pem)

      unknown_server.start_server(response_proc: response_proc) do |https_port|
        Puppet[:reporturl] = "https://127.0.0.1:#{https_port}/reports/upload"

        # override path to system cacert bundle, this must be done before
        # the SSLContext is created and the call to X509::Store.set_default_paths
        Puppet::Util.withenv("SSL_CERT_FILE" => ssl_file) do
          expect {
            apply.command_line.args = ['-e', 'notify { "hi": }']
            apply.run
          }.to exit_with(0)
           .and output(/Applied catalog/).to_stdout
        end

        expect(report).to be_a(Puppet::Transaction::Report)
        expect(report.resource_statuses['Notify[hi]']).to be_a(Puppet::Resource::Status)
      end
    end
  end

  context 'rich data' do
    let(:deferred_file) { tmpfile('deferred') }
    let(:deferred_manifest) do <<~END
      file { '#{deferred_file}':
        ensure => file,
        content => '123',
      } ->
      notify { 'deferred':
        message => Deferred('binary_file', ['#{deferred_file}'])
      }
      END
    end

    it "calls a deferred 4x function" do
      apply.command_line.args = ['-e', 'notify { "deferred3x": message => Deferred("join", [[1,2,3], ":"]) }']

      expect {
        apply.run
      }.to exit_with(0) # for some reason apply returns 0 instead of 2
       .and output(%r{Notice: /Stage\[main\]/Main/Notify\[deferred3x\]/message: defined 'message' as '1:2:3'}).to_stdout
    end

    it "calls a deferred 3x function" do
      apply.command_line.args = ['-e', 'notify { "deferred4x": message => Deferred("sprintf", ["%s", "I am deferred"]) }']
      expect {
        apply.run
      }.to exit_with(0) # for some reason apply returns 0 instead of 2
       .and output(%r{Notice: /Stage\[main\]/Main/Notify\[deferred4x\]/message: defined 'message' as 'I am deferred'}).to_stdout
    end

    it "fails to apply a deferred function with an unsatisfied prerequisite" do
      Puppet[:preprocess_deferred] = true

      apply.command_line.args = ['-e', deferred_manifest]
      expect {
        apply.run
      }.to exit_with(1) # for some reason apply returns 0 instead of 2
       .and output(/Compiled catalog/).to_stdout
       .and output(%r{The given file '#{deferred_file}' does not exist}).to_stderr
    end

    it "applies a deferred function and its prerequisite in the same run" do
      apply.command_line.args = ['-e', deferred_manifest]
      expect {
        apply.run
      }.to exit_with(0) # for some reason apply returns 0 instead of 2
        .and output(%r{defined 'message' as Binary\("MTIz"\)}).to_stdout
    end

    it "validates the deferred resource before applying any resources" do
      Puppet[:preprocess_deferred] = true
      undeferred_file = tmpfile('undeferred')

      manifest = <<~END
      file { '#{undeferred_file}':
        ensure => file,
      }
      file { '#{deferred_file}':
          ensure => file,
          content => Deferred('inline_epp', ['<%= 42 %>']),
          source => 'http://example.com/content',
      }
      END
      apply.command_line.args = ['-e', manifest]
      expect {
        apply.run
      }.to exit_with(1)
        .and output(/Compiled catalog/).to_stdout
        .and output(/Validation of File.* failed: You cannot specify more than one of content, source, target/).to_stderr

      # validation happens before all resources are applied, so this shouldn't exist
      expect(File).to_not be_exist(undeferred_file)
    end

    it "evaluates resources before validating the deferred resource" do
      manifest = <<~END
        notify { 'runs before file': } ->
        file { '#{deferred_file}':
          ensure => file,
          content => Deferred('inline_epp', ['<%= 42 %>']),
          source => 'http://example.com/content',
      }
      END
      apply.command_line.args = ['-e', manifest]
      expect {
        apply.run
      }.to exit_with(1)
        .and output(/Notify\[runs before file\]/).to_stdout
        .and output(/Validation of File.* failed: You cannot specify more than one of content, source, target/).to_stderr
    end

    it "applies deferred sensitive file content" do
      manifest = <<~END
      file { '#{deferred_file}':
        ensure => file,
        content => Deferred('new', [Sensitive, "hello\n"])
      }
      END
      apply.command_line.args = ['-e', manifest]
      expect {
        apply.run
      }.to exit_with(0)
        .and output(/ensure: changed \[redacted\] to \[redacted\]/).to_stdout
    end

    it "applies nested deferred sensitive file content" do
      manifest = <<~END
      $vars = {'token' => Deferred('new', [Sensitive, "hello"])}
      file { '#{deferred_file}':
        ensure => file,
        content => Deferred('inline_epp', ['<%= $token %>', $vars])
      }
      END
      apply.command_line.args = ['-e', manifest]
      expect {
        apply.run
      }.to exit_with(0)
        .and output(/ensure: changed \[redacted\] to \[redacted\]/).to_stdout
    end
  end
end
