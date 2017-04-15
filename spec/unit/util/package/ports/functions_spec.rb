#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/package/ports/functions'

describe Puppet::Util::Package::Ports::Functions do
  let(:test_class) do
    Class.new do
      extend Puppet::Util::Package::Ports::Functions
      def self.to_s; 'Pupept::Util::Package::Ports::FunctionsTest'; end
    end
  end

  version_pattern = '[a-zA-Z0-9][a-zA-Z0-9\\.,_]*'

  describe "#{described_class}::PORTNAME_RE" do
    it { described_class::PORTNAME_RE.should == /[a-zA-Z0-9][\w\.+-]*/ }
  end

  describe "#{described_class}::PORTVERSION_RE" do
    it { described_class::PORTVERSION_RE.should == /[a-zA-Z0-9][\w\.,]*/ }
  end

  describe "#{described_class}::PKGNAME_RE" do
    it do
      portname_re = described_class::PORTNAME_RE
      portversion_re = described_class::PORTVERSION_RE
      described_class::PKGNAME_RE.should == /(#{portname_re})-(#{portversion_re})/
    end
  end

  describe "#{described_class}::PORTORIGIN_RE" do
    it do
      portname_re = described_class::PORTNAME_RE
      described_class::PORTORIGIN_RE.should == /(#{portname_re})\/(#{portname_re})/
    end
  end

  describe "#escape_pattern(pattern)" do
    [
      ['abc()?', 'abc\\(\\)?'],
      ['file.name', 'file\\.name'],
      ['foo[bar]', 'foo\\[bar\\]'],
      ['foo.*', 'foo\\.\\*'],
      ['fo|o', 'fo\\|o'],
    ].each do |pattern, result|
      let(:pattern) { pattern }
      let(:result) { result }
      context "#escape_pattern(#{pattern.inspect})" do
        it { test_class.escape_pattern(pattern).should == result }
      end
    end
  end

  describe "#strings_to_pattern(string)" do
  [
      [ 'abc()?', 'abc\\(\\)?'],
      [ 'foo.bar[geez]', 'foo\\.bar\\[geez\\]' ],
      [ ['foo', 'bar', 'geez'], '(foo|bar|geez)'],
      [ ['foo.*', 'b|ar', 'ge[]ez'], '(foo\\.\\*|b\\|ar|ge\\[\\]ez)']
    ].each do |string, result|
      let(:string) { string }
      let(:result) { result }
      context "#strings_to_pattern(#{string.inspect})" do
        it { test_class.strings_to_pattern(string).should == result }
      end
    end
  end

  describe "#fullname_to_pattern(names)" do
    [
      [ 'apache22-2.2.26', '^apache22-2\\.2\\.26$' ],
      [
        ['php5-5.4.21', 'apache22'],
        '^(php5-5\\.4\\.21|apache22)$'
      ]
    ].each do |names, result|
      let(:names) { names }
      let(:result) { result }
      context "#fullname_to_pattern(#{names.inspect})" do
        it { test_class.fullname_to_pattern(names).should == result }
      end
    end
  end

  describe "#portorigin_to_pattern(names)" do
    [
      [ 'www/apache22', '^/usr/ports/www/apache22$' ],
      [
        ['lang/php5', 'www/apache22'],
        '^/usr/ports/(lang/php5|www/apache22)$'
      ]
    ].each do |names, result|
      let(:names) { names }
      let(:result) { result }
      context "#portorigin_to_pattern(#{names.inspect})" do
        it { test_class.portorigin_to_pattern(names).should == result }
      end
    end
  end

  describe "#pkgname_to_pattern(names)" do
    [
      [ 'apache22-2.2.26', '^apache22-2\\.2\\.26$' ],
      [
        ['php5-5.4.21', 'apache22-2.2.26'],
        '^(php5-5\\.4\\.21|apache22-2\\.2\\.26)$'
      ]
    ].each do |names, result|
      let(:names) { names }
      let(:result) { result }
      context "#pkgname_to_pattern(#{names.inspect})" do
        it { test_class.pkgname_to_pattern(names).should == result }
      end
    end
  end

  describe "#portname_to_pattern(names)" do
    [
      [ 'apache22', "^apache22-#{version_pattern}$" ],
      [ ['php5', 'apache22'], "^(php5|apache22)-#{version_pattern}$" ]
    ].each do |names, result|
      let(:names) { names }
      let(:result) { result }
      context "#portname_to_pattern(#{names.inspect})" do
        it { test_class.portname_to_pattern(names).should == result }
      end
    end
  end

  describe "#mk_search_pattern(key,names)" do
    [
      [:pkgname,  :pkgname_to_pattern ],
      [:portname,   :portname_to_pattern ],
      [:portorigin, :portorigin_to_pattern ],
      [:foobar,     :fullname_to_pattern ]
    ].each do |key, method|
      names = ["name1", "name2"]
      context "#mk_search_pattern(#{key.inspect}, #{names.inspect})" do
        let(:key) { key }
        let(:method) { method }
        let(:names) { names }
        it "calls ##{method}(#{names}) once" do
          test_class.stubs(method).once.with(names)
          expect { test_class.mk_search_pattern(key,names) }.to_not raise_error
        end
      end
    end
  end

  describe "#portsdir" do
    dir = '/some/dir'
    context "with ENV['PORTSDIR'] unset" do
      context "on FreeBSD" do
        before(:each) do
          Facter.stubs(:value).with(:operatingsystem).returns('FreeBSD')
        end
        it { test_class.portsdir.should == '/usr/ports' }
      end
      context "on OpenBSD" do
        before(:each) do
          Facter.stubs(:value).with(:operatingsystem).returns('OpenBSD')
        end
        it { test_class.portsdir.should == '/usr/ports' }
      end
      context "on NetBSD" do
        before(:each) do
          Facter.stubs(:value).with(:operatingsystem).returns('NetBSD')
        end
        it { test_class.portsdir.should == '/usr/pkgsrc' }
      end
    end
    context "with ENV['PORTSDIR'] == #{dir.inspect}" do
      let(:dir) { dir }
      before(:each) { ENV.stubs(:[]).with('PORTSDIR').returns(dir) }
      it { test_class.portsdir.should == dir }
    end
  end

  describe "#port_dbdir" do
    dir = '/some/dir'
    context "with ENV['PORT_DBDIR'] unset" do
      it { test_class.port_dbdir.should == '/var/db/ports' }
    end
    context "with ENV['PORT_DBDIR'] == #{dir.inspect}" do
      before(:each) { ENV.stubs(:[]).with('PORT_DBDIR').returns(dir) }
      let(:dir) { dir }
      it { test_class.port_dbdir.should == dir }
    end
  end

  describe "#portorigin?" do
    [
      'www/apache22',
      'www/apache22-worker-mpm',
      'devel/p5-Locale-gettext',
      'lang/perl5.14',
      'devel/rubygem-json_pure'
    ].each do |str|
      context "#portorigin?(#{str.inspect})" do
        let(:str) { str }
        it { test_class.portorigin?(str).should be_true }
      end
    end
    [
      nil,
      {},
      [],
      '',
      :test,
      'apache22',
      'apache22-2.2.25',
    ].each do |str|
      context "#portorigin?(#{str.inspect})" do
        let(:str) { str }
        it { expect { test_class.portorigin?(str) }.to_not raise_error }
        it { test_class.portorigin?(str).should be_false }
      end
    end
  end

  describe "#pkgname?" do
    [
      '0verkill-0.16_1', # yes, it happens in ports!
      'apache22-2.2.25',
      'apr-1.4.8.1.5.2',
      'autoconf-wrapper-20130530',
      'bison-2.7.1,1',
      'db41-4.1.25_4',
      'f2c-20060810_3',
      'p5-Locale-gettext-1.05_3',
      'p5-Test-Mini-Unit-v1.0.3',
      'bootstrap-openjdk-r316538',
    ].each do |str|
      context "#pkgname?(#{str.inspect})" do
        let(:str) { str }
        it { test_class.pkgname?(str).should be_true }
      end
    end
    [
      nil,
      {},
      [],
      '',
      'www/apache22',
      'apache22',
    ].each do |str|
      context "#pkgname?(#{str.inspect})" do
        let(:str) { str }
        it { expect { test_class.pkgname?(str) }.to_not raise_error }
        it { test_class.pkgname?(str).should be_false }
      end
    end
  end

  describe "#portname?" do
    [
      '0verkill-0.16_1',
      'apache22',
      'autoconf-wrapper',
      'db41-4.1.25_4',
      # they are "well-formed" portnames as well.
      'f2c-20060810_3',
      'p5-Locale-gettext-1.05_3',
      'p5-Test-Mini-Unit-v1.0.3',
      'bootstrap-openjdk-r316538',
      'apache22-2.2.25',
    ].each do |str|
      context "#portname?(#{str.inspect})" do
        let(:str) { str }
        it { test_class.portname?(str).should be_true }
      end
    end
    [
      nil,
      {},
      [],
      '',
      'www/apache22',
      'bison-2.7.1,1',
    ].each do |str|
      context "#portname?(#{str.inspect})" do
        let(:str) { str }
        it { expect { test_class.portname?(str) }.to_not raise_error }
        it { test_class.portname?(str).should be_false }
      end
    end
  end

  describe "#split_pkgname" do
    [
      [ '0verkill-0.16_1', ['0verkill','0.16_1'] ],
      [ 'db41-4.1.25_4', ['db41','4.1.25_4'] ],
      [ 'f2c-20060810_3', ['f2c','20060810_3'] ],
      [ 'p5-Locale-gettext-1.05_3', ['p5-Locale-gettext','1.05_3'] ],
      [ 'p5-Test-Mini-Unit-v1.0.3', ['p5-Test-Mini-Unit','v1.0.3'] ],
      [ 'bootstrap-openjdk-r316538', ['bootstrap-openjdk','r316538'] ],
      [ 'apache22-2.2.25', ['apache22','2.2.25'] ],
      [ 'ruby', ['ruby',nil] ],
    ].each do |pkgname,result|
      context "#split_pkgname(#{pkgname.inspect})" do
        let(:pkgname) { pkgname}
        let(:result) { result}
        it { test_class.split_pkgname(pkgname).should == result}
      end
    end
  end

  describe "#options_files(portname,portorigin)" do
    [
      [
        'ruby', 'lang/ruby19',
        [
          '/var/db/ports/ruby/options',
          '/var/db/ports/ruby/options.local',
          '/var/db/ports/lang_ruby19/options',
          '/var/db/ports/lang_ruby19/options.local'
        ]
      ]
    ].each do |portname,portorigin,result|
      context "#options_files(#{portname.inspect},#{portorigin.inspect})" do
        it do
          test_class.options_files(portname,portorigin).should == result
        end
      end
    end
  end

  describe "#pkgng_active?" do
    pkg = '/a/pkg/path'
    env = { 'TMPDIR' => '/dev/null', 'ASSUME_ALWAYS_YES' => '1',
            'PACKAGESITE' => 'file:///nonexistent' }
    cmd = [pkg,'info','-x',"'pkg(-devel)?$'",'>/dev/null', '2>&1']
    context "when pkg command does not exist" do
      before(:each) do
        FileTest.stubs(:file?).with(pkg).returns(false)
        FileTest.stubs(:executable?).with(pkg).returns(false)
      end
      let(:pkg) { pkg }
      it { test_class.pkgng_active?({:pkg => pkg}).should == false }
      it "should print appropriate debug messages" do
        ::Puppet.expects(:debug).once.with("'pkg' command not found")
        ::Puppet.expects(:debug).once.with("pkgng is inactive on this system")
        test_class.pkgng_active?({:pkg => pkg})
      end
      it "@pkgng_active should be false after pkgng_active?" do
        test_class.pkgng_active?({:pkg => pkg})
        test_class.instance_variable_get(:@pkgng_active).should be_false
      end
    end
    context "when pkg command exists but pkgng database is not initialized" do
      before(:each) do
        FileTest.stubs(:file?).with(pkg).returns(true)
        FileTest.stubs(:executable?).with(pkg).returns(true)
        Puppet::Util.stubs(:withenv).once.with(env).yields
        Puppet::Util::Execution.stubs(:execpipe).once.with(cmd).raises(Puppet::ExecutionFailure,"")
      end
      let(:pkg) { pkg }
      it { expect { test_class.pkgng_active?({:pkg => pkg}) }.to_not raise_error }
      it { test_class.pkgng_active?({:pkg => pkg}).should == false }
      it "should print appropriate debug messages" do
        ::Puppet.expects(:debug).once.with("'#{pkg}' command found, checking whether pkgng is active")
        ::Puppet.expects(:debug).once.with("pkgng is inactive on this system")
        test_class.pkgng_active?({:pkg => pkg})
      end
      it "@pkgng_active should be false after pkgng_active?" do
        test_class.pkgng_active?({:pkg => pkg})
        test_class.instance_variable_get(:@pkgng_active).should be_false
      end
    end
    context "when pkg command exists and pkgng database is initialized" do
      before(:each) do
        FileTest.stubs(:file?).with(pkg).returns(true)
        FileTest.stubs(:executable?).with(pkg).returns(true)
        Puppet::Util.stubs(:withenv).once.with(env).yields
        Puppet::Util::Execution.stubs(:execpipe).once.with(cmd).yields('')
      end
      let(:pkg) { pkg }
      it { expect { test_class.pkgng_active?({:pkg => pkg}) }.to_not raise_error }
      it { test_class.pkgng_active?({:pkg => pkg}).should == true }
      it "should print appropriate debug messages" do
        ::Puppet.expects(:debug).once.with("'#{pkg}' command found, checking whether pkgng is active")
        ::Puppet.expects(:debug).once.with("pkgng is active on this system")
        test_class.pkgng_active?({:pkg => pkg})
      end
      it "@pkgng_active should be true after pkgng_active?" do
        test_class.pkgng_active?({:pkg => pkg})
        test_class.instance_variable_get(:@pkgng_active).should be_true
      end
    end
  end

end
