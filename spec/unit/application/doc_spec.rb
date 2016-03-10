#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/application/doc'
require 'puppet/util/reference'
require 'puppet/util/rdoc'

describe Puppet::Application::Doc do
  before :each do
    @doc = Puppet::Application[:doc]
    @doc.stubs(:puts)
    @doc.preinit
    Puppet::Util::Log.stubs(:newdestination)
  end

  it "should declare an other command" do
    expect(@doc).to respond_to(:other)
  end

  it "should declare a rdoc command" do
    expect(@doc).to respond_to(:rdoc)
  end

  it "should declare a fallback for unknown options" do
    expect(@doc).to respond_to(:handle_unknown)
  end

  it "should declare a preinit block" do
    expect(@doc).to respond_to(:preinit)
  end

  describe "in preinit" do
    it "should set references to []" do
      @doc.preinit

      expect(@doc.options[:references]).to eq([])
    end

    it "should init mode to text" do
      @doc.preinit

      expect(@doc.options[:mode]).to eq(:text)
    end

    it "should init format to to_markdown" do
      @doc.preinit

      expect(@doc.options[:format]).to eq(:to_markdown)
    end
  end

  describe "when handling options" do
    [:all, :outputdir, :verbose, :debug, :charset].each do |option|
      it "should declare handle_#{option} method" do
        expect(@doc).to respond_to("handle_#{option}".to_sym)
      end

      it "should store argument value when calling handle_#{option}" do
        @doc.options.expects(:[]=).with(option, 'arg')
        @doc.send("handle_#{option}".to_sym, 'arg')
      end
    end

    it "should store the format if valid" do
      Puppet::Util::Reference.stubs(:method_defined?).with('to_format').returns(true)

      @doc.handle_format('format')
      expect(@doc.options[:format]).to eq('to_format')
    end

    it "should raise an error if the format is not valid" do
      Puppet::Util::Reference.stubs(:method_defined?).with('to_format').returns(false)
      expect { @doc.handle_format('format') }.to raise_error(RuntimeError, /Invalid output format/)
    end

    it "should store the mode if valid" do
      Puppet::Util::Reference.stubs(:modes).returns(stub('mode', :include? => true))

      @doc.handle_mode('mode')
      expect(@doc.options[:mode]).to eq(:mode)
    end

    it "should store the mode if :rdoc" do
      Puppet::Util::Reference.modes.stubs(:include?).with('rdoc').returns(false)

      @doc.handle_mode('rdoc')
      expect(@doc.options[:mode]).to eq(:rdoc)
    end

    it "should raise an error if the mode is not valid" do
      Puppet::Util::Reference.modes.stubs(:include?).with('unknown').returns(false)
      expect { @doc.handle_mode('unknown') }.to raise_error(RuntimeError, /Invalid output mode/)
    end

    it "should list all references on list and exit" do
      reference = stubs 'reference'
      ref = stubs 'ref'
      Puppet::Util::Reference.stubs(:references).returns([reference])

      Puppet::Util::Reference.expects(:reference).with(reference).returns(ref)
      ref.expects(:doc)

      expect { @doc.handle_list(nil) }.to exit_with 0
    end

    it "should add reference to references list with --reference" do
      @doc.options[:references] = [:ref1]

      @doc.handle_reference('ref2')

      expect(@doc.options[:references]).to eq([:ref1,:ref2])
    end
  end

  describe "during setup" do

    before :each do
      Puppet::Log.stubs(:newdestination)
      @doc.command_line.stubs(:args).returns([])
    end

    it "should default to rdoc mode if there are command line arguments" do
      @doc.command_line.stubs(:args).returns(["1"])
      @doc.stubs(:setup_rdoc)

      @doc.setup
      expect(@doc.options[:mode]).to eq(:rdoc)
    end

    it "should call setup_rdoc in rdoc mode" do
      @doc.options[:mode] = :rdoc

      @doc.expects(:setup_rdoc)

      @doc.setup
    end

    it "should call setup_reference if not rdoc" do
      @doc.options[:mode] = :test

      @doc.expects(:setup_reference)

      @doc.setup
    end

    describe "configuring logging" do
      before :each do
        Puppet::Util::Log.stubs(:newdestination)
      end

      describe "with --debug" do
        before do
          @doc.options[:debug] = true
        end

        it "should set log level to debug" do
          @doc.setup
          expect(Puppet::Util::Log.level).to eq(:debug)
        end

        it "should set log destination to console" do
          Puppet::Util::Log.expects(:newdestination).with(:console)
          @doc.setup
        end
      end

      describe "with --verbose" do
        before do
          @doc.options[:verbose] = true
        end

        it "should set log level to info" do
          @doc.setup
          expect(Puppet::Util::Log.level).to eq(:info)
        end

        it "should set log destination to console" do
          Puppet::Util::Log.expects(:newdestination).with(:console)
          @doc.setup
        end
      end

      describe "without --debug or --verbose" do
        before do
          @doc.options[:debug] = false
          @doc.options[:verbose] = false
        end

        it "should set log level to warning" do
          @doc.setup
          expect(Puppet::Util::Log.level).to eq(:warning)
        end

        it "should set log destination to console" do
          Puppet::Util::Log.expects(:newdestination).with(:console)
          @doc.setup
        end
      end
    end

    describe "in non-rdoc mode" do
      it "should get all non-dynamic reference if --all" do
        @doc.options[:all] = true
        static = stub 'static', :dynamic? => false
        dynamic = stub 'dynamic', :dynamic? => true
        Puppet::Util::Reference.stubs(:reference).with(:static).returns(static)
        Puppet::Util::Reference.stubs(:reference).with(:dynamic).returns(dynamic)
        Puppet::Util::Reference.stubs(:references).returns([:static,:dynamic])

        @doc.setup_reference
        expect(@doc.options[:references]).to eq([:static])
      end

      it "should default to :type if no references" do
        @doc.setup_reference
        expect(@doc.options[:references]).to eq([:type])
      end
    end

    describe "in rdoc mode" do
      describe "when there are unknown args" do
        it "should expand --modulepath if any" do
          @doc.unknown_args = [ { :opt => "--modulepath", :arg => "path" } ]
          Puppet.settings.stubs(:handlearg)

          @doc.setup_rdoc

          expect(@doc.unknown_args[0][:arg]).to eq(File.expand_path('path'))
        end

        it "should give them to Puppet.settings" do
          @doc.unknown_args = [ { :opt => :option, :arg => :argument } ]
          Puppet.settings.expects(:handlearg).with(:option,:argument)

          @doc.setup_rdoc
        end
      end

      it "should operate in master run_mode" do
        expect(@doc.class.run_mode.name).to eq(:master)

        @doc.setup_rdoc
      end
    end
  end

  describe "when running" do
    describe "in rdoc mode" do
      include PuppetSpec::Files

      let(:envdir) { tmpdir('env') }
      let(:modules) { File.join(envdir, "modules") }
      let(:modules2) { File.join(envdir, "modules2") }
      let(:manifests) { File.join(envdir, "manifests") }

      before :each do
        @doc.manifest = false
        Puppet.stubs(:info)
        Puppet[:trace] = false
        Puppet[:modulepath] = modules
        Puppet[:manifest] = manifests
        @doc.options[:all] = false
        @doc.options[:outputdir] = 'doc'
        @doc.options[:charset] = nil
        Puppet.settings.stubs(:define_settings)
        Puppet::Util::RDoc.stubs(:rdoc)
        @doc.command_line.stubs(:args).returns([])
      end

      around(:each) do |example|
        FileUtils.mkdir_p(modules)
        env = Puppet::Node::Environment.create(Puppet[:environment].to_sym, [modules], "#{manifests}/site.pp")
        Puppet.override({:environments => Puppet::Environments::Static.new(env), :current_environment => env}) do
          example.run
        end
      end

      it "should set document_all on --all" do
        @doc.options[:all] = true
        Puppet.settings.expects(:[]=).with(:document_all, true)

        expect { @doc.rdoc }.to exit_with(0)
      end

      it "should call Puppet::Util::RDoc.rdoc in full mode" do
        Puppet::Util::RDoc.expects(:rdoc).with('doc', [modules, manifests], nil)
        expect { @doc.rdoc }.to exit_with(0)
      end

      it "should call Puppet::Util::RDoc.rdoc with a charset if --charset has been provided" do
        @doc.options[:charset] = 'utf-8'
        Puppet::Util::RDoc.expects(:rdoc).with('doc', [modules, manifests], "utf-8")
        expect { @doc.rdoc }.to exit_with(0)
      end

      it "should call Puppet::Util::RDoc.rdoc in full mode with outputdir set to doc if no --outputdir" do
        @doc.options[:outputdir] = false
        Puppet::Util::RDoc.expects(:rdoc).with('doc', [modules, manifests], nil)
        expect { @doc.rdoc }.to exit_with(0)
      end

      it "should call Puppet::Util::RDoc.manifestdoc in manifest mode" do
        @doc.manifest = true
        Puppet::Util::RDoc.expects(:manifestdoc)
        expect { @doc.rdoc }.to exit_with(0)
      end

      it "should get modulepath and manifest values from the environment" do
        FileUtils.mkdir_p(modules)
        FileUtils.mkdir_p(modules2)
        env = Puppet::Node::Environment.create(Puppet[:environment].to_sym,
          [modules, modules2],
          "envmanifests/site.pp")
        Puppet.override({:environments => Puppet::Environments::Static.new(env), :current_environment => env}) do
           Puppet::Util::RDoc.stubs(:rdoc).with('doc', [modules.to_s, modules2.to_s, env.manifest.to_s], nil)
          expect { @doc.rdoc }.to exit_with(0)
        end
      end
    end

    describe "in the other modes" do
      it "should get reference in given format" do
        reference = stub 'reference'
        @doc.options[:mode] = :none
        @doc.options[:references] = [:ref]
        Puppet::Util::Reference.expects(:reference).with(:ref).returns(reference)
        @doc.options[:format] = :format
        @doc.stubs(:exit)

        reference.expects(:send).with { |format,contents| format == :format }.returns('doc')
        @doc.other
      end
    end
  end
end
