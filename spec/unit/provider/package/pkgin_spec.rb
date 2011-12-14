require "spec_helper"

provider_class = Puppet::Type.type(:package).provider(:pkgin)

describe provider_class do
  let(:resource) { Puppet::Type.type(:package).new(:name => "vim") }
  subject        { provider_class.new(resource) }

  describe "Puppet provider interface" do
    it "can return the list of all packages" do
      provider_class.should respond_to(:instances)
    end
  end

  describe "#install" do
    before { resource[:ensure] = :absent }

    it "uses pkgin install to install" do
      subject.expects(:pkgin).with("-y", :install, "vim")
      subject.install
    end
  end

  describe "#uninstall" do
    before { resource[:ensure] = :present }

    it "uses pkgin remove to uninstall" do
      subject.expects(:pkgin).with("-y", :remove, "vim")
      subject.uninstall
    end
  end

  describe "#instances" do
    let(:pkgin_ls_output) do
      "zlib-1.2.3           General purpose data compression library\nzziplib-0.13.59      Library for ZIP archive handling\n"
    end

    before do
      provider_class.stubs(:pkgin).with(:list).returns(pkgin_ls_output)
    end

    it "returns an array of providers for each package" do
      instances = provider_class.instances
      instances.should have(2).items
      instances.each do |instance|
        instance.should be_a(provider_class)
      end
    end

    it "populates each provider with an installed package" do
      zlib_provider, zziplib_provider = provider_class.instances
      zlib_provider.get(:name).should == "zlib"
      zlib_provider.get(:ensure).should == :present
      zziplib_provider.get(:name).should == "zziplib"
      zziplib_provider.get(:ensure).should == :present
    end
  end

  describe "#query" do
    before do
      provider_class.stubs(:pkgin).with(:search, "vim").returns(pkgin_search_output)
    end

    context "when the package is installed" do
      let(:pkgin_search_output) do
        "vim-7.2.446 =        Vim editor (vi clone) without GUI\nvim-share-7.2.446 =  Data files for the vim editor (vi clone)\n\n=: package is installed and up-to-date\n<: package is installed but newer version is available\n>: installed package has a greater version than available package\n"
      end

      it "returns a hash stating the package is present" do
        result = subject.query
        result[:ensure].should == :present
        result[:name].should == "vim"
        result[:provider].should == :pkgin
      end
    end

    context "when the package is out of date" do
      let(:pkgin_search_output) do
        "vim-7.2.446 <        Vim editor (vi clone) without GUI\nvim-share-7.2.446 =  Data files for the vim editor (vi clone)\n\n=: package is installed and up-to-date\n<: package is installed but newer version is available\n>: installed package has a greater version than available package\n"
      end

      it "returns a hash stating the package is present" do
        result = subject.query
        result[:ensure].should == :present
        result[:name].should == "vim"
        result[:provider].should == :pkgin
      end
    end

    context "when the package is ahead of date" do
      let(:pkgin_search_output) do
        "vim-7.2.446 >        Vim editor (vi clone) without GUI\nvim-share-7.2.446 =  Data files for the vim editor (vi clone)\n\n=: package is installed and up-to-date\n<: package is installed but newer version is available\n>: installed package has a greater version than available package\n"
      end

      it "returns a hash stating the package is present" do
        result = subject.query
        result[:ensure].should == :present
        result[:name].should == "vim"
        result[:provider].should == :pkgin
      end
    end

    context "when the package is not installed" do
      let(:pkgin_search_output) do
        "vim-7.2.446          Vim editor (vi clone) without GUI\nvim-share-7.2.446 =  Data files for the vim editor (vi clone)\n\n=: package is installed and up-to-date\n<: package is installed but newer version is available\n>: installed package has a greater version than available package\n"
      end

      it "returns a hash stating the package is present" do
        result = subject.query
        result[:ensure].should == :absent
        result[:name].should == "vim"
        result[:provider].should == :pkgin
      end
    end

    context "when the package cannot be found" do
      let(:pkgin_search_output) do
        "\n=: package is installed and up-to-date\n<: package is installed but newer version is available\n>: installed package has a greater version than available package\n"
      end

      it "returns nil" do
        subject.query.should be_nil
      end
    end
  end

  describe "#parse_pkgin_line" do
    context "with an installed package" do
      let(:package) { "vim-7.2.446 =        Vim editor (vi clone) without GUI" }

      it "extracts the name and status" do
        hash = provider_class.parse_pkgin_line(package)
        hash[:name].should == "vim"
        hash[:ensure].should == :present
        hash[:provider].should == :pkgin
      end
    end

    context "with an installed package with a hyphen in the name" do
      let(:package) { "ruby18-puppet-0.25.5nb1 = Configuration management framework written in Ruby" }

      it "extracts the name and status" do
        hash = provider_class.parse_pkgin_line(package)
        hash[:name].should == "ruby18-puppet"
        hash[:ensure].should == :present
        hash[:provider].should == :pkgin
      end
    end

    context "with a package not yet installed" do
      let(:package) { "vim-7.2.446          Vim editor (vi clone) without GUI" }

      it "extracts the name and status" do
        hash = provider_class.parse_pkgin_line(package)
        hash[:name].should == "vim"
        hash[:ensure].should == :absent
        hash[:provider].should == :pkgin
      end

      it "extracts the name and an overridden status" do
        hash = provider_class.parse_pkgin_line(package, :present)
        hash[:name].should == "vim"
        hash[:ensure].should == :present
        hash[:provider].should == :pkgin
      end
    end

    context "with an invalid package" do
      let(:package) { "" }

      it "returns nil" do
        provider_class.parse_pkgin_line(package).should be_nil
      end
    end
  end
end
