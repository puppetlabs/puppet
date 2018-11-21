require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/compiler'

describe "apply with deferred values" do
  include PuppetSpec::Files
  include PuppetSpec::Compiler

  before :each do
    Puppet[:reports] = "none"
    # Let exceptions be raised instead of exiting
    Puppet::Application.any_instance.stubs(:exit_on_fail).yields
  end

  let(:env_name) { 'spec' }
  let(:libdir_puppet) {{
    'functions' => {
      'counter.rb' => <<-PP
        Puppet::Functions.create_function(:counter) do
          # returns +1 each call starting with 1
          def counter()
            @value ||= 0
            @value = @value + 1
          end
        end
      PP
    }
  }}

  let(:env) { Puppet::Node::Environment.create(:'spec', []) }
  let(:node) { Puppet::Node.new('test', :environment => env) }

  context 'in a configured environment' do
    before(:each) do
      # Test harness does not create the leaf libdir, but the rest of the path is a tmp directory
      # The below simulates a pluginsync to libdir - which is needed to make apply (using an "for agent" loader)
      # find the counter() function.
      #
      unless Dir.exist?(Puppet[:libdir])
        Dir.mkdir(Puppet[:libdir])
        dir_contained_in(Puppet[:libdir], 'puppet' => libdir_puppet)
      end
    end

    it 'apply resolves deferred values in dependency order' do
      # 1. Compile
      catalog = compile_to_catalog(<<-PP, node)
        notify { 'b': message => Deferred('sprintf', ['b=%d', Deferred('counter')]) }
        notify { 'a': message => Deferred('sprintf', ['a=%d', Deferred('counter')]) }
        Notify[a] -> Notify[b]
      PP

      # 2. Serialize
      serialized_catalog = Puppet.override(rich_data: true) do
        catalog.to_json
      end

      # 3. Apply
      Puppet[:environment] = 'spec' 
      apply = Puppet::Application[:apply]
      # needed as apply otherwise finds a mismatch catalog.environment vs. actual and tries to get a new catalog
      apply.options[:catalog] = file_containing('catalog.json', serialized_catalog)
      expect { apply.run_command; exit(0) }.to exit_with(0)

      # 4. Assert count()  was called in expected order
      expect(@logs.map(&:to_s)).to include('a=1')
      expect(@logs.map(&:to_s)).to include('b=2')
    end

  end
end
