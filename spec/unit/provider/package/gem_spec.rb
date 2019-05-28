require 'spec_helper'

context Puppet::Type.type(:package).provider(:gem) do

  it { is_expected.to be_installable }
  it { is_expected.to be_uninstallable }
  it { is_expected.to be_upgradeable }
  it { is_expected.to be_versionable }
  it { is_expected.to be_install_options }
  it { is_expected.to be_targetable }

  let(:provider_gem_cmd) { '/provider/gem' }
  let(:execute_options) { {:failonfail => true, :combine => true, :custom_environment => {"HOME"=>ENV["HOME"]}} }

  context 'installing myresource' do
    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => 'myresource',
        :ensure   => :installed
      )
    end

    let(:provider) do
      provider = described_class.new
      provider.resource = resource
      provider
    end

    before :each do
      resource.provider = provider
      allow(described_class).to receive(:command).with(:gemcmd).and_return(provider_gem_cmd)
    end

    context "when installing" do
      before :each do
        allow(provider).to receive(:rubygem_version).and_return('1.9.9')
      end

      it "should use the path to the gem command" do
        allow(described_class).to receive(:validate_command).with(provider_gem_cmd)
        expect(described_class).to receive(:execute).with(be_a(Array), execute_options) { |args| expect(args[0]).to eq(provider_gem_cmd) }.and_return("")
        provider.install
      end

      it "should specify that the gem is being installed" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, be_a(Array)) { |cmd, args| expect(args[0]).to eq("install") }.and_return("")
        provider.install
      end

      it "should specify that --rdoc should not be included when gem version is < 2.0.0" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, be_a(Array)) { |cmd, args| expect(args[1]).to eq("--no-rdoc") }.and_return("")
        provider.install
      end

      it "should specify that --ri should not be included when gem version is < 2.0.0" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, be_a(Array)) { |cmd, args| expect(args[2]).to eq("--no-ri") }.and_return("")
        provider.install
      end

      it "should specify that --document should not be included when gem version is >= 2.0.0" do
        allow(provider).to receive(:rubygem_version).and_return('2.0.0')
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, be_a(Array)) { |cmd, args| expect(args[1]).to eq("--no-document") }.and_return("")
        provider.install
      end

      it "should specify the package name" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, be_a(Array)) { |cmd, args| expect(args[3]).to eq("myresource") }.and_return("")
        provider.install
      end

      it "should not append install_options by default" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, be_a(Array)) { |cmd, args| expect(args.length).to eq(4) }.and_return("")
        provider.install
      end

      it "should allow setting an install_options parameter" do
        resource[:install_options] = [ '--force', {'--bindir' => '/usr/bin' } ]
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, be_a(Array)) do |cmd, args|
          expect(args[1]).to eq('--force')
          expect(args[2]).to eq('--bindir=/usr/bin')
        end.and_return("")
        provider.install
      end

      context "when a source is specified" do
        context "as a normal file" do
          it "should use the file name instead of the gem name" do
            resource[:source] = "/my/file"
            expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, array_including("/my/file")).and_return("")
            provider.install
          end
        end

        context "as a file url" do
          it "should use the file name instead of the gem name" do
            resource[:source] = "file:///my/file"
            expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, array_including("/my/file")).and_return("")
            provider.install
          end
        end

        context "as a puppet url" do
          it "should fail" do
            resource[:source] = "puppet://my/file"
            expect { provider.install }.to raise_error(Puppet::Error)
          end
        end

        context "as a non-file and non-puppet url" do
          it "should treat the source as a gem repository" do
            resource[:source] = "http://host/my/file"
            expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, be_a(Array)) { |cmd, args| expect(args[3..5]).to eq(["--source", "http://host/my/file", "myresource"]) }.and_return("")
            provider.install
          end
        end

        context "as a windows path on windows", :if => Puppet::Util::Platform.windows? do
          it "should treat the source as a local path" do
            resource[:source] = "c:/this/is/a/path/to/a/gem.gem"
            expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, array_including("c:/this/is/a/path/to/a/gem.gem")).and_return("")
            provider.install
          end
        end

        context "with an invalid uri" do
          it "should fail" do
            expect(URI).to receive(:parse).and_raise(ArgumentError)
            resource[:source] = "http:::::uppet:/:/my/file"
            expect { provider.install }.to raise_error(Puppet::Error)
          end
        end
      end
    end

    context "#latest" do
      it "should return a single value for 'latest'" do
        #gemlist is used for retrieving both local and remote version numbers, and there are cases
        # (particularly local) where it makes sense for it to return an array.  That doesn't make
        # sense for '#latest', though.
        expect(provider.class).to receive(:gemlist).with({:command => provider_gem_cmd, :justme => 'myresource'}).and_return({
          :name     => 'myresource',
          :ensure   => ["3.0"],
          :provider => :gem,
        })
        expect(provider.latest).to eq("3.0")
      end

      it "should list from the specified source repository" do
        resource[:source] = "http://foo.bar.baz/gems"
        expect(provider.class).to receive(:gemlist).
          with({:command => provider_gem_cmd, :justme => 'myresource', :source => "http://foo.bar.baz/gems"}).
          and_return({
            :name     => 'myresource',
            :ensure   => ["3.0"],
            :provider => :gem,
          })
        expect(provider.latest).to eq("3.0")
      end
    end

    context "#instances" do
      before do
        allow(described_class).to receive(:command).with(:gemcmd).and_return(provider_gem_cmd)
      end

      it "should return an empty array when no gems installed" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, %w{list --local}).and_return("\n")
        expect(described_class.instances).to eq([])
      end

      it "should return ensure values as an array of installed versions" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, %w{list --local}).and_return(<<-HEREDOC.gsub(/        /, ''))
        systemu (1.2.0)
        vagrant (0.8.7, 0.6.9)
        HEREDOC

        expect(described_class.instances.map {|p| p.properties}).to eq([
          {:name => "systemu", :provider => :gem, :command => provider_gem_cmd, :ensure => ["1.2.0"]},
          {:name => "vagrant", :provider => :gem, :command => provider_gem_cmd, :ensure => ["0.8.7", "0.6.9"]}
        ])
      end

      it "should ignore platform specifications" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, %w{list --local}).and_return(<<-HEREDOC.gsub(/        /, ''))
        systemu (1.2.0)
        nokogiri (1.6.1 ruby java x86-mingw32 x86-mswin32-60, 1.4.4.1 x86-mswin32)
        HEREDOC

        expect(described_class.instances.map {|p| p.properties}).to eq([
          {:name => "systemu",  :provider => :gem, :command => provider_gem_cmd, :ensure => ["1.2.0"]},
          {:name => "nokogiri", :provider => :gem, :command => provider_gem_cmd, :ensure => ["1.6.1", "1.4.4.1"]}
        ])
      end

      it "should not list 'default: ' text from rubygems''" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, %w{list --local}).and_return(<<-HEREDOC.gsub(/        /, ''))
        bundler (1.16.1, default: 1.16.0, 1.15.1)
        HEREDOC

        expect(described_class.instances.map {|p| p.properties}).to eq([
          {:name => "bundler", :provider => :gem, :command => provider_gem_cmd, :ensure => ["1.16.1", "1.16.0", "1.15.1"]}
        ])
      end

      it "should not fail when an unmatched line is returned" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, %w{list --local}).and_return(File.read(my_fixture('line-with-1.8.5-warning')))

        expect(described_class.instances.map {|p| p.properties}).
          to eq([{:name=>"columnize",          :provider=>:gem, :command => provider_gem_cmd, :ensure=>["0.3.2"]},
                 {:name=>"diff-lcs",           :provider=>:gem, :command => provider_gem_cmd, :ensure=>["1.1.3"]},
                 {:name=>"metaclass",          :provider=>:gem, :command => provider_gem_cmd, :ensure=>["0.0.1"]},
                 {:name=>"mocha",              :provider=>:gem, :command => provider_gem_cmd, :ensure=>["0.10.5"]},
                 {:name=>"rake",               :provider=>:gem, :command => provider_gem_cmd, :ensure=>["0.8.7"]},
                 {:name=>"rspec-core",         :provider=>:gem, :command => provider_gem_cmd, :ensure=>["2.9.0"]},
                 {:name=>"rspec-expectations", :provider=>:gem, :command => provider_gem_cmd, :ensure=>["2.9.1"]},
                 {:name=>"rspec-mocks",        :provider=>:gem, :command => provider_gem_cmd, :ensure=>["2.9.0"]},
                 {:name=>"rubygems-bundler",   :provider=>:gem, :command => provider_gem_cmd, :ensure=>["0.9.0"]},
                 {:name=>"rvm",                :provider=>:gem, :command => provider_gem_cmd, :ensure=>["1.11.3.3"]}])
      end
    end

    context "listing gems" do
      context "searching for a single package" do
        it "searches for an exact match" do
          expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, array_including('\Abundler\z')).and_return(File.read(my_fixture('gem-list-single-package')))
          expected = {:name=>"bundler", :provider=>:gem, :ensure=>["1.6.2"]}
          expect(described_class.gemlist({:command => provider_gem_cmd, :justme => 'bundler'})).to eq(expected)
        end
      end
    end

    context 'insync?' do
      context 'for array of versions' do
        let(:is) { ['1.3.4', '3.6.1', '5.1.2'] }

        it 'returns true for ~> 1.3' do
          resource[:ensure] = '~> 1.3'
          expect(provider).to be_insync(is)
        end

        it 'returns false for ~> 2' do
          resource[:ensure] = '~> 2'
          expect(provider).to_not be_insync(is)
        end

        it 'returns true for > 4' do
          resource[:ensure] = '> 4'
          expect(provider).to be_insync(is)
        end

        it 'returns true for 3.6.1' do
          resource[:ensure] = '3.6.1'
          expect(provider).to be_insync(is)
        end

        it 'returns false for 3.6.2' do
          resource[:ensure] = '3.6.2'
          expect(provider).to_not be_insync(is)
        end
      end

      context 'for string version' do
        let(:is) { '1.3.4' }

        it 'returns true for ~> 1.3' do
          resource[:ensure] = '~> 1.3'
          expect(provider).to be_insync(is)
        end

        it 'returns false for ~> 2' do
          resource[:ensure] = '~> 2'
          expect(provider).to_not be_insync(is)
        end

        it 'returns false for > 4' do
          resource[:ensure] = '> 4'
          expect(provider).to_not be_insync(is)
        end

        it 'returns true for 1.3.4' do
          resource[:ensure] = '1.3.4'
          expect(provider).to be_insync(is)
        end

        it 'returns false for 3.6.1' do
          resource[:ensure] = '3.6.1'
          expect(provider).to_not be_insync(is)
        end
      end

      it 'should return false for bad version specifiers' do
        resource[:ensure] = 'not a valid gem specifier'
        expect(provider).to_not be_insync('1.0')
      end

      it 'should return false for :absent' do
        resource[:ensure] = '~> 1.0'
        expect(provider).to_not be_insync(:absent)
      end
    end
  end

  context 'installing myresource with a target command' do
    let(:resource_gem_cmd) { '/resource/gem' }

    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => "myresource",
        :ensure   => :installed,
      )
    end

    let(:provider) do
      provider = described_class.new
      provider.resource = resource
      provider
    end

    before :each do
      resource.provider = provider
    end

    context "when installing with a target command" do
      before :each do
        allow(described_class).to receive(:which).with(resource_gem_cmd).and_return(resource_gem_cmd)
      end

      it "should use the path to the other gem" do
        resource::original_parameters[:command] = resource_gem_cmd
        expect(described_class).to receive(:execute_gem_command).with(resource_gem_cmd, be_a(Array)).twice.and_return("")
        provider.install
      end
    end
  end

  context 'uninstalling myresource' do
    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => 'myresource',
        :ensure   => :absent
      )
    end

    let(:provider) do
      provider = described_class.new
      provider.resource = resource
      provider
    end

    before :each do
      resource.provider = provider
      allow(described_class).to receive(:command).with(:gemcmd).and_return(provider_gem_cmd)
    end

    context "when uninstalling" do
      it "should use the path to the gem command" do
        allow(described_class).to receive(:validate_command).with(provider_gem_cmd)
        expect(described_class).to receive(:execute).with(be_a(Array), execute_options) { |args| expect(args[0]).to eq(provider_gem_cmd) }.and_return("")
        provider.uninstall
      end

      it "should specify that the gem is being uninstalled" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, be_a(Array)) { |cmd, args| expect(args[0]).to eq("uninstall") }.and_return("")
        provider.uninstall
      end

      it "should specify that the relevant executables should be removed without confirmation" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, be_a(Array)) { |cmd, args| expect(args[1]).to eq("--executables") }.and_return("")
        provider.uninstall
      end

      it "should specify that all the matching versions should be removed" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, be_a(Array)) { |cmd, args| expect(args[2]).to eq("--all") }.and_return("")
        provider.uninstall
      end

      it "should specify the package name" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, be_a(Array)) { |cmd, args| expect(args[3]).to eq("myresource") }.and_return("")
        provider.uninstall
      end

      it "should not append uninstall_options by default" do
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, be_a(Array)) { |cmd, args| expect(args.length).to eq(4) }.and_return("")
        provider.uninstall
      end

      it "should allow setting an uninstall_options parameter" do
        resource[:uninstall_options] = [ '--ignore-dependencies', {'--version' => '0.1.1' } ]
        expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, be_a(Array)) do |cmd, args|
          expect(args[4]).to eq('--ignore-dependencies')
          expect(args[5]).to eq('--version=0.1.1')
        end.and_return('')
        provider.uninstall
      end
    end
  end
end
