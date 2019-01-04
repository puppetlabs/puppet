require 'spec_helper'

context Puppet::Type.type(:package).provider(:gem) do

  it { is_expected.to be_installable }
  it { is_expected.to be_uninstallable }
  it { is_expected.to be_upgradeable }
  it { is_expected.to be_versionable }
  it { is_expected.to be_install_options }
  it { is_expected.to be_targetable }

  context 'installing myresource' do
    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => "myresource",
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
    end

    context "when installing" do
      before :each do
        described_class.stubs(:command).with(:gemcmd).returns "/my/gem"
        described_class.stubs(:which).with("gem").returns("/my/gem")
        described_class.stubs(:validate_package_command).with("/my/gem").returns "/my/gem"
        provider.stubs(:rubygem_version).with(:gemcmd).returns "1.9.9"
      end

      it "should use the path to the gem" do
        described_class.expects(:execute_gem_command).with(:gemcmd, any_parameters).returns ""
        provider.install
      end

      it "should specify that the gem is being installed" do
        described_class.expects(:execute_gem_command).with(:gemcmd, includes("install")).returns ""
        provider.install
      end

      it "should specify that --rdoc should be negated when gem version is < 2.0.0" do
        described_class.expects(:execute_gem_command).with(:gemcmd, includes("--no-rdoc")).returns ""
        provider.install
      end

      it "should specify that --ri should be negated when gem version is < 2.0.0" do
        described_class.expects(:execute_gem_command).with(:gemcmd, includes("--no-ri")).returns ""
        provider.install
      end

      it "should specify that --document should be negated when gem version is >= 2.0.0" do
        provider.stubs(:rubygem_version).with(:gemcmd).returns "2.0.0"
        described_class.expects(:execute_gem_command).with(:gemcmd, includes("--no-document")).returns ""
        provider.install
      end

      it "should specify the package name" do
        described_class.expects(:execute_gem_command).with(:gemcmd, includes("myresource")).returns ""
        provider.install
      end

      it "should not append install_options by default" do
        described_class.expects(:execute_gem_command).with(:gemcmd, ["install", "--no-rdoc", "--no-ri", "myresource"]).returns ""
        provider.install
      end

      it "should allow setting an install_options parameter" do
        resource[:install_options] = [ "--force", {"--bindir" => "/usr/bin" } ]
        described_class.expects(:execute_gem_command).with(:gemcmd, ["install", "--force", "--bindir=/usr/bin", "--no-rdoc", "--no-ri", "myresource"]).returns ""
        provider.install
      end

      context "when a source is specified" do
        context "as a normal file" do
          it "should use the file name instead of the gem name" do
            resource[:source] = "/my/file"
            described_class.expects(:execute_gem_command).with(:gemcmd, includes("/my/file")).returns ""
            provider.install
          end
        end

        context "as a file url" do
          it "should use the file name instead of the gem name" do
            resource[:source] = "file:///my/file"
            described_class.expects(:execute_gem_command).with(:gemcmd, includes("/my/file")).returns ""
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
            described_class.expects(:execute_gem_command).with(:gemcmd, ["install", "--no-rdoc", "--no-ri", "--source", "http://host/my/file", "myresource"]).returns ""
            provider.install
          end
        end

        context "as a windows path on windows", :if => Puppet.features.microsoft_windows? do
          it "should treat the source as a local path" do
            resource[:source] = "c:/this/is/a/path/to/a/gem.gem"
            described_class.expects(:execute_gem_command).with(:gemcmd, includes("c:/this/is/a/path/to/a/gem.gem")).returns ""
            provider.install
          end
        end

        context "with an invalid uri" do
          it "should fail" do
            URI.expects(:parse).raises(ArgumentError)
            resource[:source] = "http:::::uppet:/:/my/file"
            expect { provider.install }.to raise_error(Puppet::Error)
          end
        end
      end
    end

    context "#latest" do
      it "should return a single value for 'latest'" do
        described_class.stubs(:command).with(:gemcmd).returns "/my/gem"
        described_class.stubs(:validate_package_command).with("/my/gem").returns "/my/gem"
        # gemlist is used for retrieving both local and remote version numbers, and there are cases
        # (particularly local) where it makes sense for it to return an array.  That doesn't make
        # sense for '#latest', though.
        provider.class.expects(:gemlist).with({:command => :gemcmd, :justme => "myresource"}).
          returns({
            :name     => "myresource",
            :ensure   => ["3.0"],
            :provider => :gem,
        })
        expect(provider.latest).to eq("3.0")
      end

      it "should list from the specified source repository" do
        described_class.stubs(:command).with(:gemcmd).returns "/my/gem"
        described_class.stubs(:validate_package_command).with("/my/gem").returns "/my/gem"
        resource[:source] = "http://foo.bar.baz/gems"
        provider.class.expects(:gemlist).with({:command => :gemcmd, :justme => "myresource", :source => "http://foo.bar.baz/gems"}).
          returns({
            :name     => "myresource",
            :ensure   => ["3.0"],
            :provider => :gem,
          })
        expect(provider.latest).to eq("3.0")
      end
    end

    context "#instances" do
      before do
        described_class.stubs(:command).with(:gemcmd).returns "/my/gem"
        described_class.stubs(:validate_package_command).with("/my/gem").returns "/my/gem"
      end

      it "should return an empty array when no gems installed" do
        described_class.expects(:execute_gem_command).with(:gemcmd, ["list", "--local"]).returns "\n"
        expect(described_class.instances).to eq([])
      end

      it "should return ensure values as an array of installed versions" do
        described_class.expects(:execute_gem_command).with(:gemcmd, ["list", "--local"]).returns <<-HEREDOC.gsub(/        /, '')
        systemu (1.2.0)
        vagrant (0.8.7, 0.6.9)
        HEREDOC

        expect(described_class.instances.map {|p| p.properties}).to eq([
          {:name => "systemu", :provider => :gem, :command => "/my/gem", :ensure => ["1.2.0"]},
          {:name => "vagrant", :provider => :gem, :command => "/my/gem", :ensure => ["0.8.7", "0.6.9"]}
        ])
      end

      it "should ignore platform specifications" do
        described_class.expects(:execute_gem_command).with(:gemcmd, ["list", "--local"]).returns <<-HEREDOC.gsub(/        /, '')
        systemu (1.2.0)
        nokogiri (1.6.1 ruby java x86-mingw32 x86-mswin32-60, 1.4.4.1 x86-mswin32)
        HEREDOC

        expect(described_class.instances.map {|p| p.properties}).to eq([
          {:name => "systemu",  :provider => :gem, :command => "/my/gem", :ensure => ["1.2.0"]},
          {:name => "nokogiri", :provider => :gem, :command => "/my/gem", :ensure => ["1.6.1", "1.4.4.1"]}
        ])
      end

      it "should not list 'default: ' text from rubygems''" do
        described_class.expects(:execute_gem_command).with(:gemcmd, ["list", "--local"]).returns <<-HEREDOC.gsub(/        /, '')
        bundler (1.16.1, default: 1.16.0, 1.15.1)
        HEREDOC

        expect(described_class.instances.map {|p| p.properties}).to eq([
          {:name => "bundler", :provider => :gem, :command => "/my/gem", :ensure => ["1.16.1", "1.16.0", "1.15.1"]}
        ])
      end

      it "should not fail when an unmatched line is returned" do
        described_class.expects(:execute_gem_command).with(:gemcmd, ["list", "--local"]).returns(File.read(my_fixture('line-with-1.8.5-warning')))

        expect(described_class.instances.map {|p| p.properties}).
          to eq([{:name=>"columnize",          :provider=>:gem, :command => "/my/gem", :ensure=>["0.3.2"]},
                 {:name=>"diff-lcs",           :provider=>:gem, :command => "/my/gem", :ensure=>["1.1.3"]},
                 {:name=>"metaclass",          :provider=>:gem, :command => "/my/gem", :ensure=>["0.0.1"]},
                 {:name=>"mocha",              :provider=>:gem, :command => "/my/gem", :ensure=>["0.10.5"]},
                 {:name=>"rake",               :provider=>:gem, :command => "/my/gem", :ensure=>["0.8.7"]},
                 {:name=>"rspec-core",         :provider=>:gem, :command => "/my/gem", :ensure=>["2.9.0"]},
                 {:name=>"rspec-expectations", :provider=>:gem, :command => "/my/gem", :ensure=>["2.9.1"]},
                 {:name=>"rspec-mocks",        :provider=>:gem, :command => "/my/gem", :ensure=>["2.9.0"]},
                 {:name=>"rubygems-bundler",   :provider=>:gem, :command => "/my/gem", :ensure=>["0.9.0"]},
                 {:name=>"rvm",                :provider=>:gem, :command => "/my/gem", :ensure=>["1.11.3.3"]}])
      end
    end

    context "listing gems" do
      context "searching for a single package" do
        it "searches for an exact match" do
          described_class.stubs(:command).with(:gemcmd).returns "/my/gem"
          described_class.stubs(:validate_package_command).with("/my/gem").returns "/my/gem"
          described_class.expects(:execute_gem_command).with(:gemcmd, ["list", "--local", '\Abundler\z']).
            returns(File.read(my_fixture('gem-list-single-package')))

          expected = {:name => "bundler", :ensure => ["1.6.2"], :provider => :gem}
          expect(described_class.gemlist({:command => :gemcmd, :local => :true, :justme => "bundler"})).to eq(expected)
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
        resource.provider = provider
        described_class.stubs(:which).with("/other/gem").returns("/other/gem")
        described_class.stubs(:validate_package_command).with("/other/gem").returns "/other/gem"
        provider.stubs(:rubygem_version).with(:"/other/gem").returns "1.9.9"
      end

      it "should use the path to the other gem" do
        resource[:command] = "/other/gem"
        described_class.expects(:execute_gem_command).with(:"/other/gem", any_parameters).returns ""
        provider.install
      end
    end
  end

  context 'uninstalling myresource' do
    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => "myresource",
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
    end

    context "when uninstalling" do
      it "should use the path to the gem" do
        described_class.stubs(:command).with(:gemcmd).returns "/my/gem"
        described_class.stubs(:validate_package_command).with("/my/gem").returns "/my/gem"
        described_class.expects(:execute_gem_command).with(:gemcmd, any_parameters).returns ""
        provider.uninstall
      end

      it "should specify that the gem is being uninstalled" do
        described_class.expects(:execute_gem_command).with(:gemcmd, includes("uninstall")).returns ""
        provider.uninstall
      end

      it "should specify that the relevant executables should be removed without confirmation" do
        described_class.expects(:execute_gem_command).with(:gemcmd, includes("--executables")).returns ""
        provider.uninstall
      end

      it "should specify that all the matching versions should be removed" do
        described_class.expects(:execute_gem_command).with(:gemcmd, includes("--all")).returns ""
        provider.uninstall
      end

      it "should specify the package name" do
        described_class.expects(:execute_gem_command).with(:gemcmd, includes("myresource")).returns ""
        provider.uninstall
      end

      it "should not append uninstall_options by default" do
        described_class.expects(:execute_gem_command).with(:gemcmd, ["uninstall", "--executables", "--all", "myresource"]).returns ""
        provider.uninstall
      end

      it "should allow setting an uninstall_options parameter" do
        resource[:uninstall_options] = [ "--ignore-dependencies", {"--version" => "0.1.1" } ]
        described_class.expects(:execute_gem_command).with(:gemcmd, ["uninstall", "--executables", "--all", "myresource", "--ignore-dependencies", "--version=0.1.1"]).returns ""
        provider.uninstall
      end
    end
  end
end
