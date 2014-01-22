#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/package/ports/options'

describe Puppet::Util::Package::Ports::Options do
  # valid option names and values
  describe "#[]= and #[]" do
    [['FOO',:FOO],[:BAR,:BAR]].each do |key,munged_key|
      let(:key) { key }
      let(:munged_key) { munged_key }
      [ ['on',  true],
        [:on,   true],
        [true,  true],
        ['off', false],
        [:off,  false],
        [false, false]
      ].each do |val,munged_val|
        context "#[#{key.inspect}]=#{val.inspect}" do
          let(:val) { val }
          let(:munged_val) { munged_val }
          it{ expect { subject[key] = val }.to_not raise_error }
          context "the returned value" do
            it{ (subject[key] = val).should == val }
          end
          context "and then #[#{munged_key.inspect}]" do
            it{ subject[key] = val; subject[munged_key].should == munged_val }
          end
        end
      end
    end

    # invalid option names
    ['','0FOO','&^$'].each do |key|
      context "#[#{key.inspect}]=true" do
        let(:key) { key }
        let(:val) { true }
        let(:err) { Puppet::Util::Vash::InvalidKeyError }
        let(:msg) { "invalid option name #{key.inspect}" }
        it { expect { subject[key] = val }.to raise_error err, msg }
      end
    end

    # invalid option values
    ['',nil,[],{},'offline',:offline,'ontime',:ontime].each do |val|
      context "#[#{:FOO}]=#{val.inspect}" do
        let(:key) { :FOO }
        let(:val) { val }
        let(:err) { Puppet::Util::Vash::InvalidValueError }
        let(:msg) { "invalid value #{val.inspect} for option #{key}" }
        it { expect { subject[key] = val }.to raise_error err, msg }
      end
    end
  end

  # parse
  describe "#parse" do
    [
      ["=FOO\n", {}],
      ["FOO=\n", {}],
      ["#FOO=BAR\n", {}],
      ["FOO=BAR\n", {}],
      ["FOO+=BAR\n", {}],
      ["OPTIONS_FILE_SET+=FOO\n", {:FOO=>true}],
      ["OPTIONS_FILE_UNSET+=BAR\n", {:BAR=>false}],
    ].each do |str,hash|
      context "#parse(#{str.inspect})" do
        let(:str)  { str }
        let(:hash) { hash }
        it { expect { described_class.parse(str) }.to_not raise_error }
        it { described_class.parse(str).should == hash }
      end
    end
    ['www_apache22', 'lang_perl5.14'].each do |subdir|
      ['options', 'options.local'].each do |basename|
        file = File.join(my_fixture_dir, "#{subdir}", basename)
        yaml = File.join(my_fixture_dir, "#{subdir}", "#{basename}.yaml")
        next if not File.exists?(file) or not File.exists?(yaml)
        context "#parse(File.read(#{file.inspect}))" do
          let(:options_string) { File.read(file) }
          let(:options_hash)   { YAML.load_file(yaml) }
          it { expect { described_class.parse(options_string) }.to_not raise_error }
          it "should return same options as loaded from #{yaml.inspect}" do
            described_class.parse(options_string).should == options_hash
          end
        end
      end
    end
  end

  # load
  describe "#load" do
    ['www_apache22', 'lang_perl5.14'].each do |subdir|
      ['options', 'options.local'].each do |basename|
        file = File.join(my_fixture_dir, "#{subdir}", basename)
        yaml = File.join(my_fixture_dir, "#{subdir}", "#{basename}.yaml")
        next if not File.exists?(file) or not File.exists?(yaml)
        context "#load(#{file.inspect})" do
          let(:file) { file }
          let(:options_hash) { YAML.load_file(yaml) }
          it { expect { described_class.load(file) }.to_not raise_error }
          it "should return same options as loaded from #{yaml.inspect}" do
            described_class.load(file).should == options_hash
          end
        end
      end
    end
    context "#load('inexistent.file')" do
      it { expect { described_class.load('intexistent.file') }.to_not raise_error}
      it { described_class.load('inexistent.file').should == Hash.new }
    end
    context "#load('inexistent.file', :all => true)" do
      # NOTE: not sure if this doesn't break specs on non-POSIX OSes
      it { expect { described_class.load('intexistent.file', :all => true) }.
           to raise_error Errno::ENOENT, /No such file or directory/i }
    end

  end

  # query_pkgng
  describe "#query_pkgng(key,packages=nil,params={})" do
    context "#query_pkgng('%o',nil)" do
      let(:cmd) { ['pkg', 'query', "'%o %Ok %Ov'"] }
      it do
        Puppet::Util::Execution.stubs(:execpipe).once.with(cmd).yields([
          "origin/foo FOO on",
          "origin/foo BAR off",
          "origin/bar FOO off",
          "origin/bar BAR on"
        ].join("\n"))
        described_class.query_pkgng('%o',nil).should == {
          'origin/foo' => described_class[{ :FOO => true, :BAR => false }],
          'origin/bar' => described_class[{ :FOO => false, :BAR => true }]
        }
      end
    end
    context "#query_pkgng('%o',['foo','bar'])" do
      let(:cmd) { ['pkg', 'query', "'%o %Ok %Ov'", 'foo', 'bar'] }
      it do
        Puppet::Util::Execution.stubs(:execpipe).once.with(cmd).yields([
          "origin/foo FOO on",
          "origin/foo BAR off",
          "origin/bar FOO off",
          "origin/bar BAR on"
        ].join("\n"))
        described_class.query_pkgng('%o',['foo','bar']).should == {
          'origin/foo' => described_class[{ :FOO => true, :BAR => false }],
          'origin/bar' => described_class[{ :FOO => false, :BAR => true }]
        }
      end
    end
  end

  # generate
  describe "#generate(params)" do
    [
      # 1.
      [
        described_class[ {:FOO => true, :BAR =>false} ],
        {},
        [
          "# This file is auto-generated by puppet\n",
          "OPTIONS_FILE_UNSET+=BAR\n",
          "OPTIONS_FILE_SET+=FOO\n"
        ].join("")
      ],
      # 2.
      [
        described_class[ {:FOO => true, :BAR =>false} ],
        {:pkgname => 'foobar-1.2.3'},
        [
          "# This file is auto-generated by puppet\n",
          "# Options for foobar-1.2.3\n",
          "_OPTIONS_READ=foobar-1.2.3\n",
          "OPTIONS_FILE_UNSET+=BAR\n",
          "OPTIONS_FILE_SET+=FOO\n",
        ].join("")
      ]
    ].each do |obj,params, result|
      context "#{obj.inspect}.generate(#{params.inspect}" do
        let(:params) { params }
        let(:result) { result }
        subject { obj }
        it { subject.generate(params).should == result}
      end
    end
  end

  # save
  describe "#save" do
    dir = '/var/db/ports/my_port'
    str = "# This file is auto-generated by puppet\n"
    let(:dir) { dir }
    let(:str) { str }
    context "when #{dir} exists" do
      context "#save('#{dir}/options')" do
        before(:each) do
          File.stubs(:exists?).with(dir).returns true
          Dir.expects(:mkdir).never
          FileUtils.expects(:mkdir_p).never
        end
        it do
          File.stubs(:write)
          expect { subject.save("#{dir}/options") }.to_not raise_error
        end
        it "should call File.write('#{dir}/options',#{str.inspect}) once" do
          File.expects(:write).once.with("#{dir}/options", str).returns 6
          subject.save("#{dir}/options").should == 6
        end
      end
      context "#save('#{dir}/options', :pkgname => 'foo-1.2.3')" do
        str2 = str
        str2 += "# Options for foo-1.2.3\n"
        str2 += "_OPTIONS_READ=foo-1.2.3\n"
        let(:str2) { str2 }
        before(:each) do
          File.stubs(:exists?).with(dir).returns true
          Dir.expects(:mkdir).never
          FileUtils.expects(:mkdir_p).never
        end
        it do
          File.stubs(:write)
          expect { subject.save("#{dir}/options", :pkgname => 'foo-1.2.3') }.to_not raise_error
        end
        it "should call File.write('#{dir}/options',#{str2.inspect}) once" do
          File.expects(:write).once.with("#{dir}/options", str2)
          subject.save("#{dir}/options", :pkgname => 'foo-1.2.3')
        end
      end
    end
    context "when #{dir} does not exist" do
      context "#save('#{dir}/options')" do
        before(:each) do
          File.stubs(:exists?).with(dir).returns false
          FileUtils.expects(:mkdir_p).never
        end
        it do
          Dir.stubs(:mkdir)
          File.stubs(:write)
          expect { subject.save("#{dir}/options") }.to_not raise_error
        end
        it "should call Dir.mkdir('#{dir}') and " +
           "then File.write('#{dir}',#{str.inspect})" do
          save_seq = sequence('save_seq')
          Dir.stubs(:mkdir).once.with(dir).in_sequence(save_seq)
          File.stubs(:write).once.with("#{dir}/options",str).in_sequence(save_seq)
          subject.save("#{dir}/options")
        end
      end
    end
    context "when #{dir} does not exist" do
      context "#save('#{dir}/options', :mkdir_p => true)" do
        before(:each) do
          File.stubs(:exists?).with(dir).returns false
          Dir.expects(:mkdir).never
        end
        it { expect {
          FileUtils.stubs(:mkdir_p)
          File.stubs(:write)
          subject.save("#{dir}/options", :mkdir_p => true)
        }.to_not raise_error }
        it "should call FileUtils.mkdir_p('#{dir}') and " +
           "then File.write('#{dir}',#{str.inspect})" do
          save_seq = sequence('save_seq')
          FileUtils.stubs(:mkdir_p).once.with(dir).in_sequence(save_seq)
          File.stubs(:write).once.with("#{dir}/options",str).in_sequence(save_seq)
          subject.save("#{dir}/options", :mkdir_p => true)
        end
      end
    end
  end
end
