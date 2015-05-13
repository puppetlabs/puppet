require "spec_helper"

provider_class = Puppet::Type.type(:package).provider(:pkgin)

describe provider_class do
  let(:resource) { Puppet::Type.type(:package).new(:name => "vim", :provider => :pkgin) }
  subject        { resource.provider }

  describe "Puppet provider interface" do
    it "can return the list of all packages" do
      expect(provider_class).to respond_to(:instances)
    end
  end

  describe "#install" do

   describe "a package not installed" do
    before { resource[:ensure] = :absent }
    it "uses pkgin install to install" do
      subject.expects(:pkgin).with("-y", :install, "vim").once()
      subject.install
    end
   end

   describe "a package with a fixed version" do
    before { resource[:ensure] = '7.2.446' }
    it "uses pkgin install to install a fixed version" do
      subject.expects(:pkgin).with("-y", :install, "vim-7.2.446").once()
      subject.install
    end
   end

  end

  describe "#uninstall" do
    it "uses pkgin remove to uninstall" do
      subject.expects(:pkgin).with("-y", :remove, "vim").once()
      subject.uninstall
    end
  end

  describe "#instances" do
    let(:pkgin_ls_output) do
      "zlib-1.2.3;General purpose data compression library\nzziplib-0.13.59;Library for ZIP archive handling\n"
    end

    before do
      provider_class.stubs(:pkgin).with(:list).returns(pkgin_ls_output)
    end

    it "returns an array of providers for each package" do
      instances = provider_class.instances
      expect(instances).to have(2).items
      instances.each do |instance|
        expect(instance).to be_a(provider_class)
      end
    end

    it "populates each provider with an installed package" do
      zlib_provider, zziplib_provider = provider_class.instances
      expect(zlib_provider.get(:name)).to eq("zlib")
      expect(zlib_provider.get(:ensure)).to eq("1.2.3")
      expect(zziplib_provider.get(:name)).to eq("zziplib")
      expect(zziplib_provider.get(:ensure)).to eq("0.13.59")
    end
  end

  describe "#latest" do
    before do
      provider_class.stubs(:pkgin).with(:search, "vim").returns(pkgin_search_output)
    end

    context "when the package is installed" do
      let(:pkgin_search_output) do
        "vim-7.2.446;=;Vim editor (vi clone) without GUI\nvim-share-7.2.446;=;Data files for the vim editor (vi clone)\n\n=: package is installed and up-to-date\n<: package is installed but newer version is available\n>: installed package has a greater version than available package\n"
      end

      it "returns installed version" do
        subject.expects(:properties).returns( { :ensure => "7.2.446" } )
        expect(subject.latest).to eq("7.2.446")
      end
    end

    context "when the package is out of date" do
      let(:pkgin_search_output) do
        "vim-7.2.447;<;Vim editor (vi clone) without GUI\nvim-share-7.2.447;<;Data files for the vim editor (vi clone)\n\n=: package is installed and up-to-date\n<: package is installed but newer version is available\n>: installed package has a greater version than available package\n"
      end

      it "returns the version to be installed" do
        expect(subject.latest).to eq("7.2.447")
      end
    end

    context "when the package is ahead of date" do
      let(:pkgin_search_output) do
        "vim-7.2.446;>;Vim editor (vi clone) without GUI\nvim-share-7.2.446;>;Data files for the vim editor (vi clone)\n\n=: package is installed and up-to-date\n<: package is installed but newer version is available\n>: installed package has a greater version than available package\n"
      end

      it "returns current version" do
        subject.expects(:properties).returns( { :ensure => "7.2.446" } )
        expect(subject.latest).to eq("7.2.446")
      end
    end

    context "when multiple candidates do exists" do
      let(:pkgin_search_output) do
        <<-SEARCH
vim-7.1;>;Vim editor (vi clone) without GUI
vim-share-7.1;>;Data files for the vim editor (vi clone)
vim-7.2.446;=;Vim editor (vi clone) without GUI
vim-share-7.2.446;=;Data files for the vim editor (vi clone)
vim-7.3;<;Vim editor (vi clone) without GUI
vim-share-7.3;<;Data files for the vim editor (vi clone)

=: package is installed and up-to-date
<: package is installed but newer version is available
>: installed package has a greater version than available package
SEARCH
      end

      it "returns the newest available version" do
        provider_class.stubs(:pkgin).with(:search, "vim").returns(pkgin_search_output)
        expect(subject.latest).to eq("7.3")
      end
    end

    context "when the package cannot be found" do
      let(:pkgin_search_output) do
        "No results found for is-puppet"
      end

      it "returns nil" do
        expect { subject.latest }.to raise_error(Puppet::Error, "No candidate to be installed")
      end
    end
  end

  describe "#parse_pkgin_line" do
    context "with an installed package" do
      let(:package) { "vim-7.2.446;=;Vim editor (vi clone) without GUI" }

      it "extracts the name and status" do
        expect(provider_class.parse_pkgin_line(package)).to eq({ :name => "vim" ,
                                                             :status => "=" ,
                                                             :ensure => "7.2.446" })
      end
    end

    context "with an installed package with a hyphen in the name" do
      let(:package) { "ruby18-puppet-0.25.5nb1;>;Configuration management framework written in Ruby" }

      it "extracts the name and status" do
        expect(provider_class.parse_pkgin_line(package)).to eq({ :name =>  "ruby18-puppet",
                                                             :status => ">" ,
                                                             :ensure => "0.25.5nb1" })
      end
    end

    context "with an installed package with a hyphen in the name and package description" do
      let(:package) { "ruby200-facter-2.4.3nb1;=;Cross-platform Ruby library for retrieving facts from OS" }

      it "extracts the name and status" do
        expect(provider_class.parse_pkgin_line(package)).to eq({ :name =>  "ruby200-facter",
                                                             :status => "=" ,
                                                             :ensure => "2.4.3nb1" })
      end
    end

    context "with a package not yet installed" do
      let(:package) { "vim-7.2.446;Vim editor (vi clone) without GUI" }

      it "extracts the name and status" do
        expect(provider_class.parse_pkgin_line(package)).to eq({ :name => "vim" ,
                                                             :status => nil ,
                                                             :ensure => "7.2.446" })
      end

    end

    context "with an invalid package" do
      let(:package) { "" }

      it "returns nil" do
        expect(provider_class.parse_pkgin_line(package)).to be_nil
      end
    end
  end
end
