require 'spec_helper'

describe Puppet::Type.type(:package) do
  before do
    allow(Process).to receive(:euid).and_return(0)
    allow(Puppet::Util::Storage).to receive(:store)
  end

  it "should have a :reinstallable feature that requires the :reinstall method" do
    expect(Puppet::Type.type(:package).provider_feature(:reinstallable).methods).to eq([:reinstall])
  end

  it "should have an :installable feature that requires the :install method" do
    expect(Puppet::Type.type(:package).provider_feature(:installable).methods).to eq([:install])
  end

  it "should have an :uninstallable feature that requires the :uninstall method" do
    expect(Puppet::Type.type(:package).provider_feature(:uninstallable).methods).to eq([:uninstall])
  end

  it "should have an :upgradeable feature that requires :update and :latest methods" do
    expect(Puppet::Type.type(:package).provider_feature(:upgradeable).methods).to eq([:update, :latest])
  end

  it "should have a :purgeable feature that requires the :purge latest method" do
    expect(Puppet::Type.type(:package).provider_feature(:purgeable).methods).to eq([:purge])
  end

  it "should have a :versionable feature" do
    expect(Puppet::Type.type(:package).provider_feature(:versionable)).not_to be_nil
  end

  it "should have a :supports_flavors feature" do
    expect(Puppet::Type.type(:package).provider_feature(:supports_flavors)).not_to be_nil
  end

  it "should have a :package_settings feature that requires :package_settings_insync?, :package_settings and :package_settings=" do
    expect(Puppet::Type.type(:package).provider_feature(:package_settings).methods).to eq([:package_settings_insync?, :package_settings, :package_settings=])
  end

  it "should default to being installed" do
    pkg = Puppet::Type.type(:package).new(:name => "yay", :provider => :apt)
    expect(pkg.should(:ensure)).to eq(:present)
  end

  describe "when validating attributes" do
    [:name, :source, :instance, :status, :adminfile, :responsefile, :configfiles, :category, :platform, :root, :vendor, :description, :allowcdrom, :allow_virtual, :reinstall_on_refresh].each do |param|
      it "should have a #{param} parameter" do
        expect(Puppet::Type.type(:package).attrtype(param)).to eq(:param)
      end
    end

    it "should have an ensure property" do
      expect(Puppet::Type.type(:package).attrtype(:ensure)).to eq(:property)
    end

    it "should have a package_settings property" do
      expect(Puppet::Type.type(:package).attrtype(:package_settings)).to eq(:property)
    end

    it "should have a flavor property" do
      expect(Puppet::Type.type(:package).attrtype(:flavor)).to eq(:property)
    end
  end

  describe "when validating attribute values" do
    before :each do
      @provider = double(
        'provider',
        :class           => Puppet::Type.type(:package).defaultprovider,
        :clear           => nil,
        :validate_source => nil
      )
      allow(Puppet::Type.type(:package).defaultprovider).to receive(:new).and_return(@provider)
    end

    after :each do
      Puppet::Type.type(:package).defaultprovider = nil
    end

    it "should support :present as a value to :ensure" do
      Puppet::Type.type(:package).new(:name => "yay", :ensure => :present)
    end

    it "should alias :installed to :present as a value to :ensure" do
      pkg = Puppet::Type.type(:package).new(:name => "yay", :ensure => :installed)
      expect(pkg.should(:ensure)).to eq(:present)
    end

    it "should support :absent as a value to :ensure" do
      Puppet::Type.type(:package).new(:name => "yay", :ensure => :absent)
    end

    it "should support :purged as a value to :ensure if the provider has the :purgeable feature" do
      expect(@provider).to receive(:satisfies?).with([:purgeable]).and_return(true)
      Puppet::Type.type(:package).new(:name => "yay", :ensure => :purged)
    end

    it "should not support :purged as a value to :ensure if the provider does not have the :purgeable feature" do
      expect(@provider).to receive(:satisfies?).with([:purgeable]).and_return(false)
      expect { Puppet::Type.type(:package).new(:name => "yay", :ensure => :purged) }.to raise_error(Puppet::Error)
    end

    it "should support :latest as a value to :ensure if the provider has the :upgradeable feature" do
      expect(@provider).to receive(:satisfies?).with([:upgradeable]).and_return(true)
      Puppet::Type.type(:package).new(:name => "yay", :ensure => :latest)
    end

    it "should not support :latest as a value to :ensure if the provider does not have the :upgradeable feature" do
      expect(@provider).to receive(:satisfies?).with([:upgradeable]).and_return(false)
      expect { Puppet::Type.type(:package).new(:name => "yay", :ensure => :latest) }.to raise_error(Puppet::Error)
    end

    it "should support version numbers as a value to :ensure if the provider has the :versionable feature" do
      expect(@provider).to receive(:satisfies?).with([:versionable]).and_return(true)
      Puppet::Type.type(:package).new(:name => "yay", :ensure => "1.0")
    end

    it "should not support version numbers as a value to :ensure if the provider does not have the :versionable feature" do
      expect(@provider).to receive(:satisfies?).with([:versionable]).and_return(false)
      expect { Puppet::Type.type(:package).new(:name => "yay", :ensure => "1.0") }.to raise_error(Puppet::Error)
    end

    it "should accept any string as an argument to :source" do
      expect { Puppet::Type.type(:package).new(:name => "yay", :source => "stuff") }.to_not raise_error
    end

    it "should not accept a non-string name" do
      expect do
        Puppet::Type.type(:package).new(:name => ["error"])
      end.to raise_error(Puppet::ResourceError, /Name must be a String/)
    end
  end

  module PackageEvaluationTesting
    def setprops(properties)
      allow(@provider).to receive(:properties).and_return(properties)
    end
  end

  describe Puppet::Type.type(:package) do
    before :each do
      @provider = double(
        'provider',
        :class           => Puppet::Type.type(:package).defaultprovider,
        :clear           => nil,
        :satisfies?      => true,
        :name            => :mock,
        :validate_source => nil
      )
      allow(Puppet::Type.type(:package).defaultprovider).to receive(:new).and_return(@provider)
      allow(Puppet::Type.type(:package).defaultprovider).to receive(:instances).and_return([])
      @package = Puppet::Type.type(:package).new(:name => "yay")

      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource(@package)
    end

    describe Puppet::Type.type(:package), "when it should be purged" do
      include PackageEvaluationTesting

      before { @package[:ensure] = :purged }

      it "should do nothing if it is :purged" do
        expect(@provider).to receive(:properties).and_return(:ensure => :purged).at_least(:once)
        @catalog.apply
      end

      [:absent, :installed, :present, :latest].each do |state|
        it "should purge if it is #{state.to_s}" do
          allow(@provider).to receive(:properties).and_return(:ensure => state)
          expect(@provider).to receive(:purge)
          @catalog.apply
        end
      end
    end

    describe Puppet::Type.type(:package), "when it should be absent" do
      include PackageEvaluationTesting

      before { @package[:ensure] = :absent }

      [:purged, :absent].each do |state|
        it "should do nothing if it is #{state.to_s}" do
          expect(@provider).to receive(:properties).and_return(:ensure => state).at_least(:once)
          @catalog.apply
        end
      end

      [:installed, :present, :latest].each do |state|
        it "should uninstall if it is #{state.to_s}" do
          allow(@provider).to receive(:properties).and_return(:ensure => state)
          expect(@provider).to receive(:uninstall)
          @catalog.apply
        end
      end
    end

    describe Puppet::Type.type(:package), "when it should be present" do
      include PackageEvaluationTesting

      before { @package[:ensure] = :present }

      [:present, :latest, "1.0"].each do |state|
        it "should do nothing if it is #{state.to_s}" do
          expect(@provider).to receive(:properties).and_return(:ensure => state).at_least(:once)
          @catalog.apply
        end
      end

      [:purged, :absent].each do |state|
        it "should install if it is #{state.to_s}" do
          allow(@provider).to receive(:properties).and_return(:ensure => state)
          expect(@provider).to receive(:install)
          @catalog.apply
        end
      end
    end

    describe Puppet::Type.type(:package), "when it should be latest" do
      include PackageEvaluationTesting

      before { @package[:ensure] = :latest }

      [:purged, :absent].each do |state|
        it "should upgrade if it is #{state.to_s}" do
          allow(@provider).to receive(:properties).and_return(:ensure => state)
          expect(@provider).to receive(:update)
          @catalog.apply
        end
      end

      it "should upgrade if the current version is not equal to the latest version" do
        allow(@provider).to receive(:properties).and_return(:ensure => "1.0")
        allow(@provider).to receive(:latest).and_return("2.0")
        expect(@provider).to receive(:update)
        @catalog.apply
      end

      it "should do nothing if it is equal to the latest version" do
        allow(@provider).to receive(:properties).and_return(:ensure => "1.0")
        allow(@provider).to receive(:latest).and_return("1.0")
        expect(@provider).not_to receive(:update)
        @catalog.apply
      end

      it "should do nothing if the provider returns :present as the latest version" do
        allow(@provider).to receive(:properties).and_return(:ensure => :present)
        allow(@provider).to receive(:latest).and_return("1.0")
        expect(@provider).not_to receive(:update)
        @catalog.apply
      end
    end

    describe Puppet::Type.type(:package), "when it should be a specific version" do
      include PackageEvaluationTesting

      before { @package[:ensure] = "1.0" }

      [:purged, :absent].each do |state|
        it "should install if it is #{state.to_s}" do
          allow(@provider).to receive(:properties).and_return(:ensure => state)
          expect(@package.property(:ensure).insync?(state)).to be_falsey
          expect(@provider).to receive(:install)
          @catalog.apply
        end
      end

      it "should do nothing if the current version is equal to the desired version" do
        allow(@provider).to receive(:properties).and_return(:ensure => "1.0")
        expect(@package.property(:ensure).insync?('1.0')).to be_truthy
        expect(@provider).not_to receive(:install)
        @catalog.apply
      end

      it "should install if the current version is not equal to the specified version" do
        allow(@provider).to receive(:properties).and_return(:ensure => "2.0")
        expect(@package.property(:ensure).insync?('2.0')).to be_falsey
        expect(@provider).to receive(:install)
        @catalog.apply
      end

      describe "when current value is an array" do
        let(:installed_versions) { ["1.0", "2.0", "3.0"] }

        before (:each) do
          allow(@provider).to receive(:properties).and_return(:ensure => installed_versions)
        end

        it "should install if value not in the array" do
          @package[:ensure] = "1.5"
          expect(@package.property(:ensure).insync?(installed_versions)).to be_falsey
          expect(@provider).to receive(:install)
          @catalog.apply
        end

        it "should not install if value is in the array" do
          @package[:ensure] = "2.0"
          expect(@package.property(:ensure).insync?(installed_versions)).to be_truthy
          expect(@provider).not_to receive(:install)
          @catalog.apply
        end

        describe "when ensure is set to 'latest'" do
          it "should not install if the value is in the array" do
            expect(@provider).to receive(:latest).and_return("3.0")
            @package[:ensure] = "latest"
            expect(@package.property(:ensure).insync?(installed_versions)).to be_truthy
            expect(@provider).not_to receive(:install)
            @catalog.apply
          end
        end
      end
    end

    describe Puppet::Type.type(:package), "when responding to refresh" do
      include PackageEvaluationTesting

      it "should support :true as a value to :reinstall_on_refresh" do
        srv = Puppet::Type.type(:package).new(:name => "yay", :reinstall_on_refresh => :true)
        expect(srv[:reinstall_on_refresh]).to eq(:true)
      end

      it "should support :false as a value to :reinstall_on_refresh" do
        srv = Puppet::Type.type(:package).new(:name => "yay", :reinstall_on_refresh => :false)
        expect(srv[:reinstall_on_refresh]).to eq(:false)
      end

      it "should specify :false as the default value of :reinstall_on_refresh" do
        srv = Puppet::Type.type(:package).new(:name => "yay")
        expect(srv[:reinstall_on_refresh]).to eq(:false)
      end

      [:latest, :present, :installed].each do |state|
        it "should reinstall if it should be #{state.to_s} and reinstall_on_refresh is true" do
          @package[:ensure] = state
          @package[:reinstall_on_refresh] = :true
          allow(@provider).to receive(:reinstallable?).and_return(true)
          expect(@provider).to receive(:reinstall).once
          @package.refresh
        end

        it "should reinstall if it should be #{state.to_s} and reinstall_on_refresh is false" do
          @package[:ensure] = state
          @package[:reinstall_on_refresh] = :false
          allow(@provider).to receive(:reinstallable?).and_return(true)
          expect(@provider).not_to receive(:reinstall)
          @package.refresh
        end
      end

      [:purged, :absent, :held].each do |state|
        it "should not reinstall if it should be #{state.to_s} and reinstall_on_refresh is true" do
          @package[:ensure] = state
          allow(@provider).to receive(:reinstallable?).and_return(true)
          expect(@provider).not_to receive(:reinstall)
          @package.refresh
        end

        it "should not reinstall if it should be #{state.to_s} and reinstall_on_refresh is false" do
          @package[:ensure] = state
          allow(@provider).to receive(:reinstallable?).and_return(true)
          expect(@provider).not_to receive(:reinstall)
          @package.refresh
        end
      end
    end
  end

  it "should select dnf over yum for dnf supported fedora versions" do
    dnf = Puppet::Type.type(:package).provider(:dnf)
    yum = Puppet::Type.type(:package).provider(:yum)
    allow(Facter).to receive(:value).with(:osfamily).and_return(:redhat)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:fedora)
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("22")

    expect(dnf.specificity).to be > yum.specificity
  end

  describe "allow_virtual" do
    it "defaults to true on platforms that support virtual packages" do
      pkg = Puppet::Type.type(:package).new(:name => 'yay', :provider => :yum)
      expect(pkg[:allow_virtual]).to eq true
    end

    it "defaults to false on dpkg provider" do
      pkg = Puppet::Type.type(:package).new(:name => 'yay', :provider => :dpkg)
      expect(pkg[:allow_virtual]).to be_nil
    end

    it "defaults to false on platforms that do not support virtual packages" do
      pkg = Puppet::Type.type(:package).new(:name => 'yay', :provider => :apple)
      expect(pkg[:allow_virtual]).to be_nil
    end
  end
end
