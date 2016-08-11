require 'spec_helper'
require 'puppet_spec/files'

require 'puppet/face'

describe Puppet::Face[:generate, :current] do
  include PuppetSpec::Files

  let(:genface) { Puppet::Face[:generate, :current] }

  # * Format is 'pcore' by default
  # * Format is accepted as 'pcore'
  # * Any format expect 'pcore' is an error
  # * Produces output to '<envroot>/.resource_types'
  # * Produces all types found on the module path (that are not in puppet core)
  # * Output files match input
  # * Removes files for which there is no input
  # * Updates a pcore file if it is out of date
  # * The --force flag overwrite the output even if it is up to date
  # * Environment is set with --environment (setting) (not tested explicitly)
  # Writes output for:
  #   - isomorphic
  #   - parameters
  #   - properties
  #   - title patterns
  #   - type information is written when the type is X, Y, or Z
  #
  # Additional features
  #   - blacklist? whitelist? types to exclude/include
  #   - generate one resource type (somewhere on modulepath)
  #   - output to directory of choice
  #   - clean, clean the output directory (similar to force)
  #

  [:types].each do |action|
    it { is_expected.to be_action(action) }
    it { is_expected.to respond_to(action) }
  end

  context "when used from an interactive terminal" do
    before :each do
      from_an_interactive_terminal
    end

    context "in an environment with two modules containing resource types" do
      let(:dir) do
        dir_containing('environments', { 'testing_generate' => {
          'environment.conf' => "modulepath = modules",
          'manifests' => { 'site.pp' => "" },
          'modules' => {
            'm1' => {
              'lib' => { 'puppet' => { 'type' => {
                'test1.rb' => <<-EOF
                module Puppet
                Type.newtype(:test1) do
                  @doc = "Docs for resource"
                  newproperty(:message) do
                    desc "Docs for 'message' property"
                  end
                  newparam(:name) do
                    desc "Docs for 'name' parameter"
                    isnamevar
                  end
                end; end
                EOF
               } }
            },
          },
          'm2' => { 
            'lib' => { 'puppet' => { 'type' => {
              'test2.rb' => <<-EOF
              module Puppet
              Type.newtype(:test2) do
                @doc = "Docs for resource"
                newproperty(:message) do
                  desc "Docs for 'message' property"
                end
                newparam(:name) do
                  desc "Docs for 'name' parameter"
                  isnamevar
                end
              end;end
              EOF
             } } },
          }
        }}})
      end

      let(:modulepath) do
        File.join(dir, 'testing_generate', 'modules')
      end

      let(:m1) do
        File.join(modulepath, 'm1')
      end

      let(:m2) do
        File.join(modulepath, 'm2')
      end

      let(:outputdir) do
        File.join(dir, 'testing_generate', '.resource_types')
      end

      around(:each) do |example|
        Puppet.settings.initialize_global_settings
        Puppet[:manifest] = ''
        loader = Puppet::Environments::Directories.new(dir, [])
        Puppet.override(:environments => loader) do
          Puppet.override(:current_environment => loader.get('testing_generate')) do
            example.run
          end
        end
      end

      it 'error if format is given as something other than pcore' do
        expect {
          genface.types(:format => 'json')
        }.to raise_exception(ArgumentError, /'json' is not a supported format for type generation/)
      end

      it 'accepts --format pcore as a format' do
        expect {
          genface.types(:format => 'pcore')
        }.not_to raise_error
      end

      it 'sets pcore as the default format' do
        Puppet::Generate::Type.expects(:find_inputs).with(:pcore).returns([])
        genface.types()
      end

      it 'finds all files to generate types for' do
        # using expects and returning what the side effect should have been
        # (There is no way to call the original when mocking expected parameters).
        input1 = Puppet::Generate::Type::Input.new(m1, File.join(m1, 'lib', 'puppet', 'type', 'test1.rb'), :pcore)
        input2 = Puppet::Generate::Type::Input.new(m1, File.join(m2, 'lib', 'puppet', 'type', 'test2.rb'), :pcore)
        Puppet::Generate::Type::Input.expects(:new).with(m1, File.join(m1, 'lib', 'puppet', 'type', 'test1.rb'), :pcore).returns(input1)
        Puppet::Generate::Type::Input.expects(:new).with(m2, File.join(m2, 'lib', 'puppet', 'type', 'test2.rb'), :pcore).returns(input2)
        genface.types
      end

      it 'creates output directory <env>/.resource_types/ if it does not exist' do
        expect(Puppet::FileSystem.exist?(outputdir)).to be(false)
        genface.types
        expect(Puppet::FileSystem.dir_exist?(outputdir)).to be(true)
      end

      it 'creates output with matching names for each input' do
        expect(Puppet::FileSystem.exist?(outputdir)).to be(false)
        genface.types
        children = Puppet::FileSystem.children(outputdir).map {|p| Puppet::FileSystem.basename_string(p) }
        expect(children.sort).to eql(['test1.pp', 'test2.pp'])
      end

      it 'tolerates that <env>/.resource_types/ directory exists' do
        Puppet::FileSystem.mkpath(outputdir)
        expect(Puppet::FileSystem.exist?(outputdir)).to be(true)
        genface.types
        expect(Puppet::FileSystem.dir_exist?(outputdir)).to be(true)
      end

      it 'errors if <env>/.resource_types exists and is not a directory' do
        expect(Puppet::FileSystem.exist?(outputdir)).to be(false) # assert it is not already there
        Puppet::FileSystem.touch(outputdir)
        expect(Puppet::FileSystem.exist?(outputdir)).to be(true)
        expect(Puppet::FileSystem.directory?(outputdir)).to be(false)
        expect {
          genface.types
        }.to raise_error(ArgumentError, /The output directory '#{outputdir}' exists and is not a directory/)
      end

      it 'does not overwrite if files exists and are up to date' do
        # create them (first run)
        genface.types
        stats_before = [Puppet::FileSystem.stat(File.join(outputdir, 'test1.pp')), Puppet::FileSystem.stat(File.join(outputdir, 'test2.pp'))]
        # generate again
        genface.types
        stats_after = [Puppet::FileSystem.stat(File.join(outputdir, 'test1.pp')), Puppet::FileSystem.stat(File.join(outputdir, 'test2.pp'))]
        expect(stats_before <=> stats_after).to be(0)
      end

      it 'overwrites if files exists that are not up to date while keeping up to date files' do
        # create them (first run)
        genface.types
        stats_before = [Puppet::FileSystem.stat(File.join(outputdir, 'test1.pp')), Puppet::FileSystem.stat(File.join(outputdir, 'test2.pp'))]
        # fake change in input test1 - sorry about the sleep (which there was a better way to change the modtime
        sleep(1)
        Puppet::FileSystem.touch(File.join(m1, 'lib', 'puppet', 'type', 'test1.rb'))
        # generate again
        genface.types
        # assert that test1 was overwritten (later) but not test2 (same time)
        stats_after = [Puppet::FileSystem.stat(File.join(outputdir, 'test1.pp')), Puppet::FileSystem.stat(File.join(outputdir, 'test2.pp'))]
        expect(stats_before[1] <=> stats_after[1]).to be(0)
        expect(stats_before[0] <=> stats_after[0]).to be(-1)
      end

      it 'overwrites all files when called with --force' do
        # create them (first run)
        genface.types
        stats_before = [Puppet::FileSystem.stat(File.join(outputdir, 'test1.pp')), Puppet::FileSystem.stat(File.join(outputdir, 'test2.pp'))]
        # generate again
        sleep(1) # sorry, if there is no delay the stats will be the same
        genface.types(:force => true)
        stats_after = [Puppet::FileSystem.stat(File.join(outputdir, 'test1.pp')), Puppet::FileSystem.stat(File.join(outputdir, 'test2.pp'))]
        expect(stats_before <=> stats_after).to be(-1)
      end

      it 'removes previously generated files from output when there is no input for it' do
        # create them (first run)
        genface.types
        stat_before = Puppet::FileSystem.stat(File.join(outputdir, 'test2.pp'))
        # remove input
        Puppet::FileSystem.unlink(File.join(m1, 'lib', 'puppet', 'type', 'test1.rb'))
        # generate again
        genface.types
        # assert that test1 was deleted but not test2 (same time)
        expect(Puppet::FileSystem.exist?(File.join(outputdir, 'test1.pp'))).to be(false)
        stats_after = Puppet::FileSystem.stat(File.join(outputdir, 'test2.pp'))
        expect(stat_before <=> stats_after).to be(0)
      end

    end
  end

  def from_an_interactive_terminal
    STDIN.stubs(:tty?).returns(true)
  end

end
