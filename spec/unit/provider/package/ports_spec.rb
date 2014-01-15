#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/package/ports/port_record'
require 'puppet/util/package/ports/pkg_record'
require 'puppet/util/package/ports/options'

provider_class = Puppet::Type.type(:package).provider(:ports)

describe provider_class do

  pkgrecord_class = Puppet::Util::Package::Ports::PkgRecord
  portrecord_class = Puppet::Util::Package::Ports::PortRecord
  options_class = Puppet::Util::Package::Ports::Options

  before :each do
    # Create a mock resource
    @resource = stub 'resource'

    # A catch all; no parameters set
    @resource.stubs(:[]).returns(nil)

    # But set name and source
    @resource.stubs(:[]).with(:name).returns   "mypackage"
    @resource.stubs(:[]).with(:ensure).returns :installed

    @provider = provider_class.new
    @provider.resource = @resource
    @provider.class.stubs(:portorigin).with('mypackage').returns('origin/mypackage')
  end

  it "should have an install method" do
    @provider = provider_class.new
    @provider.should respond_to(:install)
  end

  it "should have a reinstall method" do
    @provider = provider_class.new
    @provider.should respond_to(:reinstall)
  end

  it "should have an update method" do
    @provider = provider_class.new
    @provider.should respond_to(:update)
  end

  it "should have an uninstall method" do
    @provider = provider_class.new
    @provider.should respond_to(:uninstall)
  end

  it "should have a package_settings_validate method" do
    @provider = provider_class.new
    @provider.should respond_to(:package_settings_validate)
  end

  it "should have a package_settings_munge method" do
    @provider = provider_class.new
    @provider.should respond_to(:package_settings_munge)
  end

  it "should have a package_settings_insync? method" do
    @provider = provider_class.new
    @provider.should respond_to(:package_settings_insync?)
  end

  it "should have a package_settings_should_to_s method" do
    @provider = provider_class.new
    @provider.should respond_to(:package_settings_should_to_s)
  end

  it "should have a package_settings_is_to_s method" do
    @provider = provider_class.new
    @provider.should respond_to(:package_settings_is_to_s)
  end

  it "should have a package_settings method" do
    @provider = provider_class.new
    @provider.should respond_to(:package_settings)
  end

  it "should have a package_settings= method" do
    @provider = provider_class.new
    @provider.should respond_to(:package_settings=)
  end

  it "should have an install_options method" do
    @provider = provider_class.new
    @provider.should respond_to(:install_options)
  end

  it "should have a reinstall_options method" do
    @provider = provider_class.new
    @provider.should respond_to(:reinstall_options)
  end

  it "should have an upgrade_options method" do
    @provider = provider_class.new
    @provider.should respond_to(:upgrade_options)
  end

  it "should have an uninstall_options method" do
    @provider = provider_class.new
    @provider.should respond_to(:uninstall_options)
  end

  it "should have a latest method" do
    @provider = provider_class.new
    @provider.should respond_to(:latest)
  end

  describe "::instances" do
    [
      # 1.
      [
        [
          [ portrecord_class[{
            :pkgname => 'apache22-2.2.26',
            :portname => 'apache22',
            :portorigin => 'www/apache22',
            :pkgversion => '2.2.26',
            :portstatus => '=',
            :portinfo => 'up-to-date with port',
            :options => options_class[ { :SUEXEC => true } ],
            :options_file => '/var/db/ports/www_apache22/options.local',
            :options_files => [
              '/var/db/ports/apache22/options',
              '/var/db/ports/apache22/options.local',
              '/var/db/ports/www_apache22/options',
              '/var/db/ports/www_apache22/options.local'
            ]
          }]],
          [portrecord_class[{
            :pkgname => 'ruby-1.9.3.484,1',
            :portname => 'ruby',
            :portorigin => 'lang/ruby19',
            :pkgversion => '1.9.3.484,1',
            :portstatus => '=',
            :portinfo => 'up-to-date with port',
            :options => options_class[ ],
            :options_file => '/var/db/ports/lang_ruby19/options.local',
            :options_files => [
              '/var/db/ports/ruby/options',
              '/var/db/ports/ruby/options.local',
              '/var/db/ports/lang_ruby19/options',
              '/var/db/ports/lang_ruby19/options.local'
            ]
          }]]
        ],
        [
          [
            {
              :name => 'www/apache22',
              :ensure => '2.2.26',
              :package_settings => options_class[ { :SUEXEC => true } ],
              :provider => :ports
            },
            {
              :pkgname => 'apache22-2.2.26',
              :portorigin => 'www/apache22',
              :portname => 'apache22',
              :portstatus => '=',
              :portinfo => 'up-to-date with port',
              :options_file =>  '/var/db/ports/www_apache22/options.local',
              :options_files => [
                '/var/db/ports/apache22/options',
                '/var/db/ports/apache22/options.local',
                '/var/db/ports/www_apache22/options',
                '/var/db/ports/www_apache22/options.local'
              ]
            }
          ],
          [
            {
              :name => 'lang/ruby19',
              :ensure => '1.9.3.484,1',
              :package_settings => options_class[ {} ],
              :provider => :ports
            },
            {
              :pkgname => 'ruby-1.9.3.484,1',
              :portorigin => 'lang/ruby19',
              :portname => 'ruby',
              :portstatus => '=',
              :portinfo => 'up-to-date with port',
              :options_file =>  '/var/db/ports/lang_ruby19/options.local',
              :options_files => [
                '/var/db/ports/ruby/options',
                '/var/db/ports/ruby/options.local',
                '/var/db/ports/lang_ruby19/options',
                '/var/db/ports/lang_ruby19/options.local'
              ]
            }
          ]
        ]
      ]
    ].each do |records,output|
      context "with installed packages=#{records.collect{|r| r.first[:pkgname]}.inspect}" do
        let(:records) { records }
        let(:output) { output }
        let(:fields) { pkgrecord_class.default_fields }
        before(:each) do
          described_class.stubs(:search_packages).once.with(nil,fields).multiple_yields(*records)
          described_class.stubs(:pkgng_active?).returns(false)
        end
        (1..records.length-1).each do |i|
          record = records[i][0]
          props, attribs = output[i]
          context "for #{record[:portorigin]}" do
            let(:props) { props }
            let(:attribs) { attribs }
            it "should find provider by pkgorigin" do
              described_class.instances.find{|inst| inst.name == record[:portorigin]}.should_not be_nil
            end
            it "provider should have correct properties" do
              prov = described_class.instances.find{|inst| inst.name == record[:portorigin]}
              prov.properties.should == props
            end
            it "provider should have correct attributes" do
              prov = described_class.instances.find{|inst| inst.name == record[:portorigin]}
              attribs.each do |key,attr|
                prov.method(key).call.should == attr
              end
            end
          end
        end
      end
    end

    # Multiple portorigins for single pkgname, in shouldn't happen but I have
    # seen such situation once.
    context "when an installed package has multiple origins" do
      let(:records) {[
        [pkgrecord_class[{
          :pkgname => 'ruby-1.9.3.484,1',
          :portname => 'ruby',
          :portorigin => 'lang/ruby19',
          :pkgversion => '1.9.3.484,1',
          :portstatus => '=',
          :portinfo => 'up-to-date with port',
          :options => options_class[ ],
          :options_file => '/var/db/ports/lang_ruby19/options.local',
          :options_files => [
            '/var/db/ports/ruby/options',
            '/var/db/ports/ruby/options.local',
            '/var/db/ports/lang_ruby19/options',
            '/var/db/ports/lang_ruby19/options.local'
          ]
        }]],
        [ pkgrecord_class[{
          :pkgname => 'ruby-1.9.3.484,1',
          :portname => 'ruby',
          :portorigin => 'lang/ruby20',
          :pkgversion => '1.9.3.484,1',
          :portstatus => '=',
          :portinfo => 'up-to-date with port',
          :options => options_class[ ],
          :options_file => '/var/db/ports/lang_ruby20/options.local',
          :options_files => [
            '/var/db/ports/ruby/options',
            '/var/db/ports/ruby/options.local',
            '/var/db/ports/lang_ruby20/options',
            '/var/db/ports/lang_ruby20/options.local'
          ]
        }]]
      ] }
      let(:fields) { pkgrecord_class.default_fields }
      it "prints warning but does not raises an error" do
        described_class.stubs(:search_packages).once.with(nil,fields).multiple_yields(*records)
        described_class.stubs(:pkgng_active?).returns(false)
        described_class.expects(:warning).once.with(
          "Found 2 installed ports named 'ruby-1.9.3.484,1': 'lang/ruby19', " +
          "'lang/ruby20'. Only 'lang/ruby20' will be ensured."
        )
        described_class.instances
      end
    end

    context "::instances(['ruby'])" do
      let(:records) {[
        [['ruby',pkgrecord_class[{
          :pkgname => 'ruby-1.8.7.123,1',
          :portname => 'ruby',
          :pkgversion => '1.8.7.123,1',
          :portstatus => '=',
          :portinfo => 'up-to-date-with-port',
          :options => options_class[ ],
          :portorigin => 'lang/ruby19'
        }]]]
      ] }
      let(:fields) { pkgrecord_class.default_fields }
      it do
        described_class.stubs(:search_packages).once.with(['ruby'],fields).multiple_yields(*records)
        described_class.stubs(:pkgng_active?).returns(false)
        expect { described_class.instances(['ruby']) }.to_not raise_error
      end
    end

    # No ports for an installed package.
    context "when an installed package has no corresponding port" do
      let(:records) {[
        [pkgrecord_class[{
          :pkgname => 'ruby-1.8.7.123,1',
          :portname => 'ruby',
          :pkgversion => '1.8.7.123,1',
          :portstatus => '?',
          :portinfo => 'anything',
          :options => options_class[ ]
        }]],
      ] }
      let(:fields) { pkgrecord_class.default_fields }
      it "prints warning but does not raise an error" do
        described_class.stubs(:search_packages).once.with(nil,fields).multiple_yields(*records)
        described_class.stubs(:pkgng_active?).returns(false)
        described_class.expects(:warning).once.with(
          "Could not find port for installed package 'ruby-1.8.7.123,1'." +
          "Build options and upgrades will not work for this package."
        )
        described_class.instances
      end
    end

    context "when pkgng is active" do
      let(:records) {[
        [pkgrecord_class[{
          :pkgname => 'ruby-1.8.7.123,1',
          :portname => 'ruby',
          :pkgversion => '1.8.7.123,1',
          :portstatus => '=',
          :portinfo => 'up-to-date-with-port',
          :options => options_class[ ],
          :portorigin => 'lang/ruby19'
        }]]
      ] }
      let(:fields) { pkgrecord_class.default_fields - [:options] }
      it do
        described_class.stubs(:search_packages).once.with(nil,fields).multiple_yields(*records)
        described_class.stubs(:pkgng_active?).returns(true)
        described_class.stubs(:command).once.with(:pkg).returns('/a/path/to/pkg')
        options_class.stubs(:query_pkgng).once.with('%o',nil,{:pkg => '/a/path/to/pkg'}).returns({'lang/ruby19' => options_class[:FOO => true]})
        expect { described_class.instances }.to_not raise_error
      end
    end
  end

  describe "::prefetch(packages)" do
    [
      # 1.
      [
        [ # instances
          [
            {:name => 'www/apache22', :ensure => :present},
            {
              :pkgname => 'apache22-2.2.26', :portorigin => 'www/apache22',
              :portname => 'apache22', :portstatus => '=',
              :portinfo => 'up-to-date with port',
              :options_file => '/var/db/ports/www_apache22/options.local',
              :options_files => [
                '/var/db/ports/apache22/options',
                '/var/db/ports/apache22/options.local',
                '/var/db/ports/www_apache22/options',
                '/var/db/ports/www_apache22/options.local'
              ]
            }
          ],
          [
            {:name => 'lang/ruby19', :ensure => :present},
            {
              :pkgname => 'ruby-1.9.3', :portorigin => 'lang/ruby19',
              :portname => 'ruby', :portstatus => '=',
              :portinfo => 'up-to-date with port',
              :options_file => '/var/db/ports/lang_ruby19/options.local',
              :options_files => [
                '/var/db/ports/ruby/options',
                '/var/db/ports/ruby/options.local',
                '/var/db/ports/lang_ruby19/options',
                '/var/db/ports/lang_ruby19/options.local'
              ]
            }
          ]
        ],
        { # packages
          'ruby' => Puppet::Type.type(:package).new({
            :name => 'ruby',:ensure=>'present'
          }),
          'mysql55-client' => Puppet::Type.type(:package).new({
            :name => 'mysql55-client',:ensure=>'present'
          })
        },
        [ # ports
          [
            'mysql55-client',
            portrecord_class[{
              :pkgname => 'mysql55-client-5.5.3',
              :portname => 'mysql55-client',
              :portorigin => 'databases/mysql55-client',
              :options_file => '/var/db/ports/databases_mysql55-client/options.local',
              :options_files => [
                '/var/db/ports/mysql-client/options',
                '/var/db/ports/mysql-client/options.local',
                '/var/db/ports/databases_mysql55-client/options',
                '/var/db/ports/databases_mysql55-client/options.local'
              ]
            }]
          ]
        ]
      ],
    ].each do |instances,packages,ports|
      inst_names = instances.map{|data| data.first[:name]}.join(", ")
      pkg_names = packages.map{|key,pkg| key}.join(", ")
      newpkgs = packages.keys
      providers = []
      instances.each do |props, attribs|
        prov = described_class.new(props)
        prov.assign_port_attributes(attribs)
        if pkg = (packages[prov.name] || packages[prov.portorigin] ||
                   packages[prov.pkgname] || packages[prov.portname])
          newpkgs -= [prov.name,prov.portorigin, prov.pkgname, prov.portname]
          pkg.provider = prov
        end
        providers << prov
      end
      newpkgs.each do |key|
        pkg = packages[key]
        pkg.provider = described_class.new(:name => name, :ensure => :absent)
      end
      context "with installed: #{inst_names}, manifested: #{pkg_names}" do
        let(:packages) { packages }
        let(:providers) { providers }
        let(:newpkgs) { newpkgs }
        before(:each) do
          described_class.stubs(:instances).once.returns(providers)
          described_class.stubs(:search_ports).once.with(newpkgs).multiple_yields(*ports)
        end
        it do
          expect { described_class.prefetch(packages) }.to_not raise_error
        end
      end
    end
    context "when an ambiguous port name is used in manifest for uninstalled port" do 
      ports = [
        [
          'mysql-client',
          portrecord_class[{
            :pkgname => 'mysql-client-5.1.71',
            :portname => 'mysql-client',
            :portorigin => 'databases/mysql51-client',
            :options_file => '/var/db/ports/databases_mysql51-client/options.local',
            :options_files => [
              '/var/db/ports/mysql-client/options',
              '/var/db/ports/mysql-client/options.local',
              '/var/db/ports/databases_mysql51-client/options',
              '/var/db/ports/databases_mysql51-client/options.local'
            ]
          }],
        ],
        [
          'mysql-client',
          portrecord_class[{
            :pkgname => 'mysql-client-5.5.33',
            :portname => 'mysql-client',
            :portorigin => 'databases/mysql55-client',
            :options_file => '/var/db/ports/databases_mysql55-client/options.local',
            :options_files => [
              '/var/db/ports/mysql-client/options',
              '/var/db/ports/mysql-client/options.local',
              '/var/db/ports/databases_mysql55-client/options',
              '/var/db/ports/databases_mysql55-client/options.local'
            ]
          }],
        ],
        [
          'mysql-client',
          portrecord_class[{
            :pkgname => 'mysql-client-5.6.13',
            :portname => 'mysql-client',
            :portorigin => 'databases/mysql56-client',
            :options_file => '/var/db/ports/databases_mysql56-client/options.local',
            :options_files => [
              '/var/db/ports/mysql-client/options',
              '/var/db/ports/mysql-client/options.local',
              '/var/db/ports/databases_mysql56-client/options',
              '/var/db/ports/databases_mysql56-client/options.local'
            ]
          }]
        ]
      ]
      resources = {
        'mysql-client' => Puppet::Type.type(:package).new({
          :name => 'mysql-client', :ensure=>'present'
        })
      }
      before(:each) do
        described_class.stubs(:instances).returns([])
        described_class.stubs(:search_ports).with(['mysql-client']).multiple_yields(*ports)
      end
      let(:ports) { ports }
      let(:resources) { resources }
      it do
        described_class.expects(:warning).once.with(
          "Found 3 ports named 'mysql-client': 'databases/mysql51-client', " +
          "'databases/mysql55-client', 'databases/mysql56-client'. Only " +
          "'databases/mysql56-client' will be ensured."
        )
        described_class.prefetch(resources)
      end
    end
  end

  describe "uninitialized attributes" do
    [
      :pkgname,
      :portorigin,
      :portname,
      :portstatus,
      :portinfo,
      :options_file,
      :options_files
    ].each do |attr|
      context "#{attr}" do
        let(:attr) { attr }
        before(:each) { subject.stubs(:name).returns 'bar/foo' }
        it do
          expect { subject.method(attr).call }.to raise_error Puppet::Error,
            "Attribute '#{attr}' not assigned for package 'bar/foo'."
        end
      end
    end
  end

  describe "#package_settings_validate(opts)" do
    [
      [ 123, ArgumentError, "123 of type Fixnum is not an options Hash (for $package_settings)"],
      [ { :FOO => true }, nil, nil ],
      [ { 76 => false }, ArgumentError, "76 is not a valid option name (for $package_settings)" ],
      [ { :FOO => 123}, ArgumentError, "123 is not a valid option value (for $package_settings)" ],
    ].each do |opts,err,msg|
      context "#package_settings_validate(#{opts.inspect})" do
        let(:opts) { opts }
        let(:err) { err }
        let(:msg) { msg }
        it do
          if err
            expect { subject.package_settings_validate(opts) }.to raise_error err, msg
          else
            expect { subject.package_settings_validate(opts) }.to_not raise_error
          end
        end
      end
    end
  end

  describe "#package_settings_munge(opts)" do
    [
      { :FOO => true },
      options_class[{ :FOO => true }],
    ].each do |opts|
      context "#package_settings_munge(#{opts.inspect})" do
        let(:opts) { opts }
        it do
          subject.package_settings_munge(opts).should == options_class[opts]
        end
      end
    end
  end

  describe "#package_settings_insync?(should,is)" do
    [
      [
        options_class[{:FOO => true}],
        options_class[{:FOO => true}],
        true
      ],
      [
        options_class[{:FOO => true}],
        options_class[{:FOO => false}],
        false
      ],
      [
        options_class[{}],
        options_class[{:FOO => false}],
        true
      ],
      [
        options_class[{:FOO => true}],
        options_class[{:BAR => false}],
        false
      ],
      [
        options_class[{:FOO => true}],
        options_class[{:BAR => false, :FOO => true}],
        true
      ],
      [
        Hash[{:FOO => true}],
        options_class[{:FOO => true}],
        false
      ],
      [
        options_class[{:FOO => true}],
        Hash[{:FOO => true}],
        false
      ]
    ].each do |should,is,result|
      let(:should) { should }
      let(:is) { is }
      let(:result) { result }
      context "#package_settings_insync?(#{should.inspect}, #{is.inspect})" do
        it { subject.package_settings_insync?(should,is).should == result}
      end
    end
  end

  describe "#package_settings_should_to_s(should, newvalue)" do
    [
      [{},options_class[{:FOO => true}]],
      [{},{:FOO => true}]
    ].each do |should,newvalue|
      let(:should) { should }
      let(:newvalue) { newvalue }
      let(:result) { newvalue.is_a?(options_class) ? options_class[newvalue.sort].inspect : newvalue.inspect }
      context "#package_settings_should_to_s(#{should.inspect}, #{newvalue.inspect})" do
        it { subject.package_settings_should_to_s(should,newvalue).should == result}
      end
    end
  end

  describe "#package_settings_is_to_s(should, currvalue)" do
    [
      [{},{},"{}"],
      [options_class[{}],options_class[{:FOO => true}], "{}"],
      [options_class[{:FOO => true}],options_class[{}], "{}"],
      [options_class[{:FOO => true,:BAR => false}],options_class[{:BAR => true}],
       options_class[{:BAR=>true}].inspect],
    ].each do |should,currvalue,result|
      let(:should) { should }
      let(:currvalue) { currvalue }
      let(:result) { result }
      context "#package_settings_is_to_s(#{should.inspect}, #{currvalue.inspect})" do
        it { subject.package_settings_is_to_s(should,currvalue).should == result}
      end
    end
  end

  describe "#package_settings" do
    it do
      subject.stubs(:properties).once.returns({:package_settings => options_class[{}]})
      subject.package_settings.should == options_class[{}]
    end
  end

  describe "#package_settings=(opts)" do
    it do
      subject.stubs(:reinstall).once.with(options_class[{:FOO => true}])
      expect { subject.package_settings=options_class[{:FOO => true}] }.to_not raise_error
    end
  end

  describe "#install_options" do
    it do
      subject.stubs(:resource).once.returns({:install_options => %w{-x}})
      subject.install_options.should == %w{-N -x}
    end
  end

  describe "#reinstall_options" do
    it do
      subject.stubs(:resource).once.returns({:install_options => %w{-x}})
      subject.reinstall_options.should == %w{-f -x}
    end
  end

  describe "#upgrade_options" do
    it do
      subject.stubs(:resource).once.returns({:install_options => ['-x','-M',{:BATCH=>'yes'}]})
      subject.upgrade_options.should == %w{-x -M BATCH=yes}
    end
  end

  describe "#uninstall_options" do
    context "when pkgng_active? is true" do
      it do
        subject.stubs(:pkgng_active?).returns(true)
        subject.stubs(:resource).once.returns({:uninstall_options => %w{-x}})
        subject.uninstall_options.should == %w{delete -x}
      end
    end
    context "when pkgng_active? is false" do
      it do
        subject.stubs(:pkgng_active?).returns(false)
        subject.stubs(:resource).once.returns({:uninstall_options => %w{-x}})
        subject.uninstall_options.should == %w{-x}
      end
    end
  end

  describe "when installing" do
    context "and portupgrade is supposed to succeed" do
      before :each do
        ops =  options_class[{:FOO => true}]
        ops.stubs(:save).once.with('/var/db/ports/bar_foo/options.local', {:pkgname => 'foo-1.2.3'})
        subject.stubs(:properties).returns({:package_settings => options_class[{:FOO => false}]})
        subject.stubs(:resource).returns({:name => 'bar/foo', :package_settings => ops})
        subject.stubs(:options_file).returns('/var/db/ports/bar_foo/options.local')
        subject.stubs(:pkgname).returns('foo-1.2.3')
        subject.stubs(:portupgrade).once.with(*%w{-N -M BATCH=yes bar/foo})
      end

      it "should use 'portupgrade -N -M BATCH=yes bar/foo'" do
        expect { subject.install }.to_not raise_error
      end
    end

    context "and portupgrade fails" do
      it "should revert options and reraise" do
        opts1 = options_class[{:FOO=>true}]
        opts2 = options_class[{:FOO=>false}]
        opts1.stubs(:save).once.with('/var/db/ports/bar_foo/options.local', {:pkgname => 'foo-2.4.5'})
        opts2.stubs(:save).once.with('/var/db/ports/bar_foo/options.local', {:pkgname => 'foo-2.4.5'})
        subject.stubs(:pkgname).returns('foo-2.4.5')
        subject.stubs(:properties).returns({:package_settings => opts1})
        subject.stubs(:resource).returns({:package_settings => opts2})
        subject.stubs(:options_file).returns('/var/db/ports/bar_foo/options.local')
        subject.stubs(:portupgrade).raises RuntimeError, "go and revert options!"
        expect { subject.install }.to raise_error RuntimeError, "go and revert options!"
      end
    end
    context "and there is no such package" do
      it "should revert options and raise exception" do
        opts1 = options_class[{:FOO=>true}]
        opts2 = options_class[{:FOO=>false}]
        opts1.stubs(:save).once.with('/var/db/ports/bar_foo/options.local', {:pkgname => 'foo-2.4.5'})
        opts2.stubs(:save).once.with('/var/db/ports/bar_foo/options.local', {:pkgname => 'foo-2.4.5'})
        subject.stubs(:pkgname).returns('foo-2.4.5')
        subject.stubs(:properties).returns({:package_settings => opts1})
        subject.stubs(:resource).returns({:name=>'bar/foo', :package_settings => opts2})
        subject.stubs(:options_file).returns('/var/db/ports/bar_foo/options.local')
        subject.stubs(:portupgrade).returns("** No such package: bar/foo")
        expect { subject.install }.to raise_error Puppet::ExecutionFailure, "Could not find package bar/foo"
      end
    end
  end

  describe "when reinstalling" do
    context "a package that has port origin" do
      before(:each) do
        subject.instance_variable_set(:@portorigin, 'port/origin')
        subject.stubs(:reinstall_options).returns %w{-r -o}
        subject.stubs(:resource).returns({:package_settings=>{}})
        subject.stubs(:name).returns('bar/foo')
      end
      it "should call do_potupgrade(portorigin, reinstall_options, options)" do
        subject.stubs(:do_portupgrade).once.with('port/origin', %w{-r -o}, {})
        expect { subject.reinstall({}) }.to_not raise_error
      end
    end
    context "a package that has no port origin" do
      before(:each) do
        subject.stubs(:reinstall_options).returns %w{-r -o}
        subject.stubs(:resource).returns({:package_settings=>{}})
        subject.stubs(:name).returns('foo-1.2.3')
      end
      it "should not call do_potupgrade" do
        subject.stubs(:do_portupgrade).never
        expect { subject.reinstall({}) }.to_not raise_error
      end
      it "should issue a warning" do
        subject.stubs(:warning).once.with("Could not reinstall package 'foo-1.2.3' which has no port origin.")
        expect { subject.reinstall({}) }.to_not raise_error
      end
    end
  end

  describe "when upgrading" do
    context "a package that is not currently installed" do
      it "should call install" do
        subject.stubs(:properties).returns({:ensure => :absent})
        subject.stubs(:do_portupgrade).never
        subject.stubs(:install).once
        expect { subject.update }.to_not raise_error
      end
    end
    context "an installed package" do
      it "should call do_potupgrade portorigin, reinstall_options, options" do
        subject.stubs(:properties).returns({:ensure => :present})
        subject.stubs(:resource).returns({:package_settings=>{}})
        subject.instance_variable_set(:@portorigin,'bar/foo')
        subject.stubs(:name).returns('bar/foo')
        subject.stubs(:upgrade_options).returns(%w{-R -M BATCH=yes})
        subject.stubs(:do_portupgrade).once.with('bar/foo', %w{-R -M BATCH=yes},{})
        subject.stubs(:install).never
        expect { subject.update }.to_not raise_error
      end
    end
    context "an installed package that has no port"  do
      before(:each) do
        subject.stubs(:properties).returns({:ensure => :present, :name=>'foo'})
        subject.stubs(:name).returns('foo-1.2.3')
        subject.stubs(:resource).returns({:package_settings=>{}})
        subject.stubs(:upgrade_options).returns(%w{-R -M BATCH=yes})
        subject.stubs(:do_portupgrade)
        subject.stubs(:install)
      end
      it "should never call do_portupgrade" do
        subject.stubs(:do_portupgrade).never
        expect { subject.update }.to_not raise_error
      end
      it "should never call install" do
        subject.stubs(:install).never
        expect { subject.update }.to_not raise_error
      end
      it "should issue a warning" do
        subject.stubs(:warning).once.with("Could not upgrade package 'foo-1.2.3' which has no port origin.")
        expect { subject.update }.to_not raise_error
      end
    end
  end

  describe "when uninstalling" do
    context "package foo-1.2.3 with uninstall_options=['-x']" do
      before(:each) do
        subject.stubs(:pkgname).returns('foo-1.2.3')
        subject.stubs(:resource).returns({:uninstall_options => %w{-x}})
      end
      context "and pkgng is inactive" do
        it "should call #portuninstall('-x','foo-1.2.3') once" do
          subject.stubs(:pkgng_active?).returns(false)
          subject.expects(:portuninstall).once.with(*%w{-x foo-1.2.3})
          subject.uninstall
        end
      end
      context "and pkgng is active" do
        it "should call #portuninstall('delete','-x','foo-1.2.3') once" do
          subject.stubs(:pkgng_active?).returns(true)
          subject.expects(:portuninstall).once.with(*%w{delete -x foo-1.2.3})
          subject.uninstall
        end
      end
    end
  end


  describe "#latest" do
    [
      ['1.2.3', '=', 'up-to-date-with-port', '1.2.3', nil],
      ['1.2.3', '>', 'up-to-date-with-port', '1.2.3', nil],
      ['1.2.3', '<', 'needs updating (port has 2.4.5)', '2.4.5', nil],
      ['1.2.3', '?', '', :latest, "The installed package 'foo-1.2.3' does not appear in the ports database nor does its port directory exist."],
      ['1.2.3', '!', '', :latest, "The installed package 'foo-1.2.3' does not appear in the ports database, the port directory actually exists, but the latest version number cannot be obtained."],
      ['1.2.3', '#', '', :latest, "The installed package 'foo-1.2.3' does not have an origin recorded."],
      ['1.2.3', '&', '', :latest, "Invalid status flag #{'&'.inspect} for package 'foo-1.2.3' (returned by portversion command)."],
    ].each do |oldver,status,info,result,warn|
      context "{:ensure => #{oldver.inspect}, :portstatus => #{status.inspect}, :portinfo => #{info.inspect}" do
        let(:oldver) { oldver }
        let(:status) { status }
        let(:info) { info }
        let(:warn) { warn }
        it do
          subject.stubs(:pkgname).returns 'foo-1.2.3'
          subject.stubs(:portstatus).returns status
          subject.stubs(:properties).returns({:ensure => oldver})
          subject.stubs(:portinfo).returns info
          if warn
            subject.stubs(:warning).once.with(warn)
          end
          subject.latest.should == result
        end
      end
      context "{:ensure=>'1.2.3', :portstatus=>'<', :portinfo=>'xyz'}" do
        it do
          subject.stubs(:portstatus).returns('<')
          subject.stubs(:portinfo).returns('xyz')
          subject.stubs(:properties).returns({:ensure => '1.2.3'})
          expect { subject.latest }.to raise_error Puppet::Error, 'Could not match version info "xyz".'
        end
      end
    end
  end

  describe "#query" do
    [
      # 1.
      [
        { :name => 'bar/foo', :ensure=>:absent },
        [
        ],
        nil
      ],
      # 2.
      [
        { :name => 'bar/foo', :ensure=>:absent },
        [
          {
            :name => 'gadong',
            :ensure=>'4.5.6',
            :portorigin => 'bar/foo',
            :pkgname => 'foo-4.5.6',
            :portname => 'foo'
          },
        ],
        0
      ],
      # 3.
      [
        { :name => 'ruby', :ensure=>:absent },
        [
          {
            :name => 'lang/ruby18',
            :ensure=>'1.8.7',
            :portorigin => 'lang/ruby18',
            :pkgname => 'ruby-1.8.7',
            :portname => 'ruby'
          },
          {
            :name => 'lang/ruby19',
            :ensure=>'1.9.3',
            :portorigin => 'lang/ruby19',
            :pkgname => 'ruby-1.9.3',
            :portname => 'ruby'
          },
        ],
        1
      ],
    ].each do |me,others,result|
      context "#{me.inspect}.query" do
        subject { described_class.new(me) }
        let(:me) { me }
        let(:others) { others }
        let(:result) { result }
        it do
          instances = []
          others.each do |o|
            inst = described_class.new({:name => o[:name], :ensure => o[:ensure]})
            o.delete(:name)
            o.delete(:ensure)
            inst.assign_port_attributes(o)
            instances << inst
          end
          result = instances[result].properties if result
          described_class.stubs(:instances).once.with([me[:name]]).returns instances
          subject.query.should == result
        end
      end
    end
  end

end
