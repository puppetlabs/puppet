require 'spec_helper'

describe 'compiler localization' do
  include_context 'l10n', 'ja'

  let(:envdir) { File.join(my_fixture_dir, '..', 'envs') }
  let(:environments) do
    Puppet::Environments::Cached.new(
      Puppet::Environments::Directories.new(envdir, [])
    )
  end
  let(:env) { Puppet::Node::Environment.create(:prod, [File.join(envdir, 'prod', 'modules')]) }
  let(:node) { Puppet::Node.new('test', :environment => env) }

  around(:each) do |example|
    Puppet.override(current_environment: env,
                    loaders: Puppet::Pops::Loaders.new(env),
                    environments: environments) do
      example.run
    end
  end

  it 'localizes strings in functions' do
    Puppet[:code] = <<~END
      notify { 'demo':
        message => l10n()
      }
    END

    Puppet::Resource::Catalog.indirection.terminus_class = :compiler
    catalog = Puppet::Resource::Catalog.indirection.find(node.name)
    resource = catalog.resource(:notify, 'demo')

    expect(resource).to be
    expect(resource[:message]).to eq("それは楽しい時間です")
  end
end
