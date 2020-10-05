require 'spec_helper'

require 'puppet/application/doc'
require 'puppet/util/reference'
require 'puppet/util/rdoc'

describe Puppet::Application::Doc do
  before :each do
    @doc = Puppet::Application[:doc]
    allow(@doc).to receive(:puts)
    @doc.preinit
    allow(Puppet::Util::Log).to receive(:newdestination)
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
        expect(@doc.options).to receive(:[]=).with(option, 'arg')
        @doc.send("handle_#{option}".to_sym, 'arg')
      end
    end

    it "should store the format if valid" do
      allow(Puppet::Util::Reference).to receive(:method_defined?).with('to_format').and_return(true)

      @doc.handle_format('format')
      expect(@doc.options[:format]).to eq('to_format')
    end

    it "should raise an error if the format is not valid" do
      allow(Puppet::Util::Reference).to receive(:method_defined?).with('to_format').and_return(false)
      expect { @doc.handle_format('format') }.to raise_error(RuntimeError, /Invalid output format/)
    end

    it "should store the mode if valid" do
      allow(Puppet::Util::Reference).to receive(:modes).and_return(double('mode', :include? => true))

      @doc.handle_mode('mode')
      expect(@doc.options[:mode]).to eq(:mode)
    end

    it "should store the mode if :rdoc" do
      allow(Puppet::Util::Reference.modes).to receive(:include?).with('rdoc').and_return(false)

      @doc.handle_mode('rdoc')
      expect(@doc.options[:mode]).to eq(:rdoc)
    end

    it "should raise an error if the mode is not valid" do
      allow(Puppet::Util::Reference.modes).to receive(:include?).with('unknown').and_return(false)
      expect { @doc.handle_mode('unknown') }.to raise_error(RuntimeError, /Invalid output mode/)
    end

    it "should list all references on list and exit" do
      reference = double('reference')
      ref = double('ref')
      allow(Puppet::Util::Reference).to receive(:references).and_return([reference])

      expect(Puppet::Util::Reference).to receive(:reference).with(reference).and_return(ref)
      expect(ref).to receive(:doc)

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
      allow(Puppet::Log).to receive(:newdestination)
      allow(@doc.command_line).to receive(:args).and_return([])
    end

    it "should default to rdoc mode if there are command line arguments" do
      allow(@doc.command_line).to receive(:args).and_return(["1"])
      allow(@doc).to receive(:setup_rdoc)

      @doc.setup
      expect(@doc.options[:mode]).to eq(:rdoc)
    end

    it "should call setup_rdoc in rdoc mode" do
      @doc.options[:mode] = :rdoc

      expect(@doc).to receive(:setup_rdoc)

      @doc.setup
    end

    it "should call setup_reference if not rdoc" do
      @doc.options[:mode] = :test

      expect(@doc).to receive(:setup_reference)

      @doc.setup
    end

    describe "configuring logging" do
      before :each do
        allow(Puppet::Util::Log).to receive(:newdestination)
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
          expect(Puppet::Util::Log).to receive(:newdestination).with(:console)
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
          expect(Puppet::Util::Log).to receive(:newdestination).with(:console)
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
          expect(Puppet::Util::Log).to receive(:newdestination).with(:console)
          @doc.setup
        end
      end
    end

    describe "in non-rdoc mode" do
      it "should get all non-dynamic reference if --all" do
        @doc.options[:all] = true
        static = double('static', :dynamic? => false)
        dynamic = double('dynamic', :dynamic? => true)
        allow(Puppet::Util::Reference).to receive(:reference).with(:static).and_return(static)
        allow(Puppet::Util::Reference).to receive(:reference).with(:dynamic).and_return(dynamic)
        allow(Puppet::Util::Reference).to receive(:references).and_return([:static,:dynamic])

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
          allow(Puppet.settings).to receive(:handlearg)

          @doc.setup_rdoc

          expect(@doc.unknown_args[0][:arg]).to eq(File.expand_path('path'))
        end

        it "should give them to Puppet.settings" do
          @doc.unknown_args = [ { :opt => :option, :arg => :argument } ]
          expect(Puppet.settings).to receive(:handlearg).with(:option,:argument)

          @doc.setup_rdoc
        end
      end

      it "should operate in server run_mode" do
        expect(@doc.class.run_mode.name).to eq(:server)

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
        allow(Puppet).to receive(:info)
        Puppet[:trace] = false
        Puppet[:modulepath] = modules
        Puppet[:manifest] = manifests
        @doc.options[:all] = false
        @doc.options[:outputdir] = 'doc'
        @doc.options[:charset] = nil
        allow(Puppet.settings).to receive(:define_settings)
        allow(Puppet::Util::RDoc).to receive(:rdoc)
        allow(@doc.command_line).to receive(:args).and_return([])
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
        expect(Puppet.settings).to receive(:[]=).with(:document_all, true)

        expect { @doc.rdoc }.to exit_with(0)
      end

      it "should call Puppet::Util::RDoc.rdoc in full mode" do
        expect(Puppet::Util::RDoc).to receive(:rdoc).with('doc', [modules, manifests], nil)
        expect { @doc.rdoc }.to exit_with(0)
      end

      it "should call Puppet::Util::RDoc.rdoc with a charset if --charset has been provided" do
        @doc.options[:charset] = 'utf-8'
        expect(Puppet::Util::RDoc).to receive(:rdoc).with('doc', [modules, manifests], "utf-8")
        expect { @doc.rdoc }.to exit_with(0)
      end

      it "should call Puppet::Util::RDoc.rdoc in full mode with outputdir set to doc if no --outputdir" do
        @doc.options[:outputdir] = false
        expect(Puppet::Util::RDoc).to receive(:rdoc).with('doc', [modules, manifests], nil)
        expect { @doc.rdoc }.to exit_with(0)
      end

      it "should call Puppet::Util::RDoc.manifestdoc in manifest mode" do
        @doc.manifest = true
        expect(Puppet::Util::RDoc).to receive(:manifestdoc)
        expect { @doc.rdoc }.to exit_with(0)
      end

      it "should get modulepath and manifest values from the environment" do
        FileUtils.mkdir_p(modules)
        FileUtils.mkdir_p(modules2)
        env = Puppet::Node::Environment.create(Puppet[:environment].to_sym,
          [modules, modules2],
          "envmanifests/site.pp")
        Puppet.override({:environments => Puppet::Environments::Static.new(env), :current_environment => env}) do
           allow(Puppet::Util::RDoc).to receive(:rdoc).with('doc', [modules.to_s, modules2.to_s, env.manifest.to_s], nil)
          expect { @doc.rdoc }.to exit_with(0)
        end
      end
    end

    describe "in the other modes" do
      it "should get reference in given format" do
        reference = double('reference')
        @doc.options[:mode] = :none
        @doc.options[:references] = [:ref]
        expect(Puppet::Util::Reference).to receive(:reference).with(:ref).and_return(reference)
        @doc.options[:format] = :format
        allow(@doc).to receive(:exit)

        expect(reference).to receive(:send).with(:format, anything).and_return('doc')
        @doc.other
      end
    end
  end
end
