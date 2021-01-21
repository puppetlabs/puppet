require 'spec_helper'
require 'puppet/indirector/facts/facter'

describe Puppet::Node::Facts::Facter do
  FS = Puppet::FileSystem

  it "should be a subclass of the Code terminus" do
    expect(Puppet::Node::Facts::Facter.superclass).to equal(Puppet::Indirector::Code)
  end

  it "should have documentation" do
    expect(Puppet::Node::Facts::Facter.doc).not_to be_nil
  end

  it "should be registered with the configuration store indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:facts)
    expect(Puppet::Node::Facts::Facter.indirection).to equal(indirection)
  end

  it "should have its name set to :facter" do
    expect(Puppet::Node::Facts::Facter.name).to eq(:facter)
  end

  before :each do
    @facter = Puppet::Node::Facts::Facter.new
    allow(Facter).to receive(:to_hash).and_return({})
    @name = "me"
    @request = double('request', :key => @name)
    @environment = double('environment')
    allow(@request).to receive(:environment).and_return(@environment)
    allow(@request).to receive(:options).and_return({})
    allow(@request.environment).to receive(:modules).and_return([])
    allow(@request.environment).to receive(:modulepath).and_return([])
  end

  describe 'when finding facts' do
    it 'should reset facts' do
      expect(Facter).to receive(:reset).ordered
      expect(Puppet::Node::Facts::Facter).to receive(:setup_search_paths).ordered
      @facter.find(@request)
    end

    it 'should add the puppetversion and agent_specified_environment facts' do
      expect(Facter).to receive(:reset).ordered
      expect(Facter).to receive(:add).with(:puppetversion)
      expect(Facter).to receive(:add).with(:agent_specified_environment)
      @facter.find(@request)
    end

    it 'should include external facts' do
      expect(Facter).to receive(:reset).ordered
      expect(Puppet::Node::Facts::Facter).to receive(:setup_external_search_paths).ordered
      expect(Puppet::Node::Facts::Facter).to receive(:setup_search_paths).ordered
      @facter.find(@request)
    end

    it "should return a Facts instance" do
      expect(@facter.find(@request)).to be_instance_of(Puppet::Node::Facts)
    end

    it "should return a Facts instance with the provided key as the name" do
      expect(@facter.find(@request).name).to eq(@name)
    end

    it "should return the Facter facts as the values in the Facts instance" do
      expect(Facter).to receive(:to_hash).and_return("one" => "two")
      facts = @facter.find(@request)
      expect(facts.values["one"]).to eq("two")
    end

    it "should add local facts" do
      facts = Puppet::Node::Facts.new("foo")
      expect(Puppet::Node::Facts).to receive(:new).and_return(facts)
      expect(facts).to receive(:add_local_facts)

      @facter.find(@request)
    end

    it "should sanitize facts" do
      facts = Puppet::Node::Facts.new("foo")
      expect(Puppet::Node::Facts).to receive(:new).and_return(facts)
      expect(facts).to receive(:sanitize)

      @facter.find(@request)
    end
  end

  it 'should fail when saving facts' do
    expect { @facter.save(@facts) }.to raise_error(Puppet::DevError)
  end

  it 'should fail when destroying facts' do
    expect { @facter.destroy(@facts) }.to raise_error(Puppet::DevError)
  end

  describe 'when setting up search paths' do
    let(:factpath1) { File.expand_path 'one' }
    let(:factpath2) { File.expand_path 'two' }
    let(:factpath) { [factpath1, factpath2].join(File::PATH_SEPARATOR) }
    let(:modulepath) { File.expand_path 'module/foo' }
    let(:modulelibfacter) { File.expand_path 'module/foo/lib/facter' }
    let(:modulepluginsfacter) { File.expand_path 'module/foo/plugins/facter' }

    before :each do
      expect(FileTest).to receive(:directory?).with(factpath1).and_return(true)
      expect(FileTest).to receive(:directory?).with(factpath2).and_return(true)
      allow(@request.environment).to receive(:modulepath).and_return([modulepath])
      allow(@request).to receive(:options).and_return({})
      expect(Dir).to receive(:glob).with("#{modulepath}/*/lib/facter").and_return([modulelibfacter])
      expect(Dir).to receive(:glob).with("#{modulepath}/*/plugins/facter").and_return([modulepluginsfacter])

      Puppet[:factpath] = factpath
    end

    it 'should skip files' do
      expect(FileTest).to receive(:directory?).with(modulelibfacter).and_return(false)
      expect(FileTest).to receive(:directory?).with(modulepluginsfacter).and_return(false)
      expect(Facter).to receive(:search).with(factpath1, factpath2)
      Puppet::Node::Facts::Facter.setup_search_paths @request
    end

    it 'should add directories' do
      expect(FileTest).to receive(:directory?).with(modulelibfacter).and_return(true)
      expect(FileTest).to receive(:directory?).with(modulepluginsfacter).and_return(true)
      expect(Facter).to receive(:search).with(modulelibfacter, modulepluginsfacter, factpath1, factpath2)
      Puppet::Node::Facts::Facter.setup_search_paths @request
    end
  end

  describe 'when setting up external search paths' do
    let(:pluginfactdest) { File.expand_path 'plugin/dest' }
    let(:modulepath) { File.expand_path 'module/foo' }
    let(:modulefactsd) { File.expand_path 'module/foo/facts.d'  }

    before :each do
      expect(FileTest).to receive(:directory?).with(pluginfactdest).and_return(true)
      mod = Puppet::Module.new('foo', modulepath, @request.environment)
      allow(@request.environment).to receive(:modules).and_return([mod])
      Puppet[:pluginfactdest] = pluginfactdest
    end

    it 'should skip files' do
      expect(File).to receive(:directory?).with(modulefactsd).and_return(false)
      expect(Facter).to receive(:search_external).with([pluginfactdest])
      Puppet::Node::Facts::Facter.setup_external_search_paths @request
    end

    it 'should add directories' do
      expect(File).to receive(:directory?).with(modulefactsd).and_return(true)
      expect(Facter).to receive(:search_external).with([modulefactsd, pluginfactdest])
      Puppet::Node::Facts::Facter.setup_external_search_paths @request
    end
  end

  describe 'when :resolve_options is true' do
    let(:options) { { resolve_options: true, user_query: ["os", "timezone"] } }
    let(:facts) { Puppet::Node::Facts.new("foo") }

    before :each do
      allow(@request).to receive(:options).and_return(options)
      allow(Puppet::Node::Facts).to receive(:new).and_return(facts)
      allow(facts).to receive(:add_local_facts)
    end

    it 'should call Facter.resolve method' do
      expect(Facter).to receive(:resolve).with("os timezone")
      @facter.find(@request)
    end

    it 'should NOT add local facts' do
      expect(facts).not_to receive(:add_local_facts)

      @facter.find(@request)
    end

    context 'when --show-legacy flag is present' do
      let(:options) { { resolve_options: true, user_query: ["os", "timezone"], show_legacy: true } }

      it 'should call Facter.resolve method with show-legacy' do
        expect(Facter).to receive(:resolve).with("os timezone --show-legacy")
        @facter.find(@request)
      end
    end

    context 'when --timing flag is present' do
      let(:options) { { resolve_options: true, user_query: ["os", "timezone"], timing: true } }

      it 'calls Facter.resolve with --timing' do
        expect(Facter).to receive(:resolve).with("os timezone --timing")
        @facter.find(@request)
      end
    end

    describe 'when Facter version is lower than 4.0.40' do
      before :each do
        allow(Facter).to receive(:respond_to?).and_return(false)
        allow(Facter).to receive(:respond_to?).with(:resolve).and_return(false)
      end

      it 'raises an error' do
        expect { @facter.find(@request) }.to raise_error(Puppet::Error, "puppet facts show requires version 4.0.40 or greater of Facter.")
      end
    end

    describe 'when setting up external search paths' do
      let(:options) { { resolve_options: true, user_query: ["os", "timezone"], external_dir: 'some/dir' } }
      let(:pluginfactdest) { File.expand_path 'plugin/dest' }
      let(:modulepath) { File.expand_path 'module/foo' }
      let(:modulefactsd) { File.expand_path 'module/foo/facts.d'  }

      before :each do
        expect(FileTest).to receive(:directory?).with(pluginfactdest).and_return(true)
        mod = Puppet::Module.new('foo', modulepath, @request.environment)
        allow(@request.environment).to receive(:modules).and_return([mod])
        Puppet[:pluginfactdest] = pluginfactdest
      end

      it 'should skip files' do
        expect(File).to receive(:directory?).with(modulefactsd).and_return(false)
        expect(Facter).to receive(:search_external).with([pluginfactdest, options[:external_dir]])
        Puppet::Node::Facts::Facter.setup_external_search_paths @request
      end

      it 'should add directories' do
        expect(File).to receive(:directory?).with(modulefactsd).and_return(true)
        expect(Facter).to receive(:search_external).with([modulefactsd, pluginfactdest, options[:external_dir]])
        Puppet::Node::Facts::Facter.setup_external_search_paths @request
      end
    end

    describe 'when setting up search paths' do
      let(:factpath1) { File.expand_path 'one' }
      let(:factpath2) { File.expand_path 'two' }
      let(:factpath) { [factpath1, factpath2].join(File::PATH_SEPARATOR) }
      let(:modulepath) { File.expand_path 'module/foo' }
      let(:modulelibfacter) { File.expand_path 'module/foo/lib/facter' }
      let(:modulepluginsfacter) { File.expand_path 'module/foo/plugins/facter' }
      let(:options) { { resolve_options: true, custom_dir: 'some/dir' } }

      before :each do
        expect(FileTest).to receive(:directory?).with(factpath1).and_return(true)
        expect(FileTest).to receive(:directory?).with(factpath2).and_return(true)
        allow(@request.environment).to receive(:modulepath).and_return([modulepath])
        expect(Dir).to receive(:glob).with("#{modulepath}/*/lib/facter").and_return([modulelibfacter])
        expect(Dir).to receive(:glob).with("#{modulepath}/*/plugins/facter").and_return([modulepluginsfacter])

        Puppet[:factpath] = factpath
      end

      it 'should skip files' do
        expect(FileTest).to receive(:directory?).with(modulelibfacter).and_return(false)
        expect(FileTest).to receive(:directory?).with(modulepluginsfacter).and_return(false)
        expect(Facter).to receive(:search).with(factpath1, factpath2, options[:custom_dir])
        Puppet::Node::Facts::Facter.setup_search_paths @request
      end

      it 'should add directories' do
        expect(FileTest).to receive(:directory?).with(modulelibfacter).and_return(true)
        expect(FileTest).to receive(:directory?).with(modulepluginsfacter).and_return(false)
        expect(Facter).to receive(:search).with(modulelibfacter, factpath1, factpath2, options[:custom_dir])
        Puppet::Node::Facts::Facter.setup_search_paths @request
      end
    end
  end
end
