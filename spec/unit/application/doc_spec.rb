#!/usr/bin/env rspec
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

  it "should ask Puppet::Application to not parse Puppet configuration file" do
    @doc.should_parse_config?.should be_false
  end

  it "should declare a other command" do
    @doc.should respond_to(:other)
  end

  it "should declare a rdoc command" do
    @doc.should respond_to(:rdoc)
  end

  it "should declare a fallback for unknown options" do
    @doc.should respond_to(:handle_unknown)
  end

  it "should declare a preinit block" do
    @doc.should respond_to(:preinit)
  end

  describe "in preinit" do
    it "should set references to []" do
      @doc.preinit

      @doc.options[:references].should == []
    end

    it "should init mode to text" do
      @doc.preinit

      @doc.options[:mode].should == :text
    end

    it "should init format to to_markdown" do
      @doc.preinit

      @doc.options[:format].should == :to_markdown
    end
  end

  describe "when handling options" do
    [:all, :outputdir, :verbose, :debug, :charset].each do |option|
      it "should declare handle_#{option} method" do
        @doc.should respond_to("handle_#{option}".to_sym)
      end

      it "should store argument value when calling handle_#{option}" do
        @doc.options.expects(:[]=).with(option, 'arg')
        @doc.send("handle_#{option}".to_sym, 'arg')
      end
    end

    it "should store the format if valid" do
      Puppet::Util::Reference.stubs(:method_defined?).with('to_format').returns(true)

      @doc.options.expects(:[]=).with(:format, 'to_format')

      @doc.handle_format('format')
    end

    it "should raise an error if the format is not valid" do
      Puppet::Util::Reference.stubs(:method_defined?).with('to_format').returns(false)
      lambda { @doc.handle_format('format') }
    end

    it "should store the mode if valid" do
      Puppet::Util::Reference.stubs(:modes).returns(stub('mode', :include? => true))

      @doc.options.expects(:[]=).with(:mode, :mode)

      @doc.handle_mode('mode')
    end

    it "should store the mode if :rdoc" do
      Puppet::Util::Reference.modes.stubs(:include?).with('rdoc').returns(false)

      @doc.options.expects(:[]=).with(:mode, :rdoc)

      @doc.handle_mode('rdoc')
    end

    it "should raise an error if the mode is not valid" do
      Puppet::Util::Reference.modes.stubs(:include?).with('unknown').returns(false)
      lambda { @doc.handle_mode('unknown') }
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

      @doc.options[:references].should == [:ref1,:ref2]
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

      @doc.options.expects(:[]=).with(:mode,:rdoc)

      @doc.setup
    end

    it "should call setup_rdoc in rdoc mode" do
      @doc.options.stubs(:[]).with(:mode).returns(:rdoc)

      @doc.expects(:setup_rdoc)

      @doc.setup
    end

    it "should call setup_reference if not rdoc" do
      @doc.options.stubs(:[]).with(:mode).returns(:test)

      @doc.expects(:setup_reference)

      @doc.setup
    end

    describe "in non-rdoc mode" do

      it "should get all non-dynamic reference if --all" do
        @doc.options.stubs(:[]).with(:all).returns(true)
        @doc.options.stubs(:[]).with(:references).returns([])
        static = stub 'static', :dynamic? => false
        dynamic = stub 'dynamic', :dynamic? => true
        Puppet::Util::Reference.stubs(:reference).with(:static).returns(static)
        Puppet::Util::Reference.stubs(:reference).with(:dynamic).returns(dynamic)
        Puppet::Util::Reference.stubs(:references).returns([:static,:dynamic])

        @doc.options.stubs(:[]=).with(:references, [:static])

        @doc.setup_reference
      end

      it "should default to :type if no references" do
        @doc.options.stubs(:[]).with(:all).returns(false)
        array = stub 'array', :empty? => true
        @doc.options.stubs(:[]).with(:references).returns(array)

        array.expects(:<<).with(:type)

        @doc.setup_reference
      end

    end

    describe "in rdoc mode" do

      before :each do
        @doc.options.stubs(:[]).returns(false)
        Puppet.stubs(:parse_config)
        Puppet::Util::Log.stubs(:newdestination)
      end

      describe "when there are unknown args" do

        it "should expand --modulepath if any" do
          @doc.unknown_args = [ { :opt => "--modulepath", :arg => "path" } ]
          Puppet.settings.stubs(:handlearg)

          File.expects(:expand_path).with("path")

          @doc.setup_rdoc
        end

        it "should expand --manifestdir if any" do
          @doc.unknown_args = [ { :opt => "--manifestdir", :arg => "path" } ]
          Puppet.settings.stubs(:handlearg)

          File.expects(:expand_path).with("path")

          @doc.setup_rdoc
        end

        it "should give them to Puppet.settings" do
          @doc.unknown_args = [ { :opt => :option, :arg => :argument } ]
          Puppet.settings.expects(:handlearg).with(:option,:argument)

          @doc.setup_rdoc
        end
      end

      it "should operate in master run_mode" do
        @doc.class.run_mode.name.should == :master

        @doc.setup_rdoc
      end

      it "should parse puppet configuration" do
        Puppet.expects(:parse_config)

        @doc.setup_rdoc
      end

      it "should set log level to debug if --debug" do
        @doc.options.stubs(:[]).with(:debug).returns(true)
        @doc.setup_rdoc
        Puppet::Util::Log.level.should == :debug
      end

      it "should set log level to info if --verbose" do
        @doc.options.stubs(:[]).with(:verbose).returns(true)
        @doc.setup_rdoc
        Puppet::Util::Log.level.should == :info
      end

      it "should set log destination to console if --verbose" do
        @doc.options.stubs(:[]).with(:verbose).returns(true)

        Puppet::Util::Log.expects(:newdestination).with(:console)

        @doc.setup_rdoc
      end

      it "should set log destination to console if --debug" do
        @doc.options.stubs(:[]).with(:debug).returns(true)

        Puppet::Util::Log.expects(:newdestination).with(:console)

        @doc.setup_rdoc
      end

    end

  end

  describe "when running" do

    describe "in rdoc mode" do
      before :each do
        @doc.manifest = false
        Puppet.stubs(:info)
        Puppet.stubs(:[]).with(:trace).returns(false)
        @env = stub 'env'
        Puppet::Node::Environment.stubs(:new).returns(@env)
        @env.stubs(:modulepath).returns(['modules'])
        @env.stubs(:[]).with(:manifest).returns('manifests/site.pp')
        Puppet.stubs(:[]).with(:modulepath).returns('modules')
        Puppet.stubs(:[]).with(:manifestdir).returns('manifests')
        @doc.options.stubs(:[]).with(:all).returns(false)
        @doc.options.stubs(:[]).with(:outputdir).returns('doc')
        @doc.options.stubs(:[]).with(:charset).returns(nil)
        Puppet.settings.stubs(:[]=).with(:document_all, false)
        Puppet.settings.stubs(:setdefaults)
        Puppet::Util::RDoc.stubs(:rdoc)
        File.stubs(:expand_path).with('modules').returns('modules')
        File.stubs(:expand_path).with('manifests').returns('manifests')
        @doc.command_line.stubs(:args).returns([])
      end

      it "should set document_all on --all" do
        @doc.options.expects(:[]).with(:all).returns(true)
        Puppet.settings.expects(:[]=).with(:document_all, true)

        expect { @doc.rdoc }.to exit_with 0
      end

      it "should call Puppet::Util::RDoc.rdoc in full mode" do
        Puppet::Util::RDoc.expects(:rdoc).with('doc', ['modules','manifests'], nil)
        expect { @doc.rdoc }.to exit_with 0
      end

      it "should call Puppet::Util::RDoc.rdoc with a charset if --charset has been provided" do
        @doc.options.expects(:[]).with(:charset).returns("utf-8")
        Puppet::Util::RDoc.expects(:rdoc).with('doc', ['modules','manifests'], "utf-8")
        expect { @doc.rdoc }.to exit_with 0
      end

      it "should call Puppet::Util::RDoc.rdoc in full mode with outputdir set to doc if no --outputdir" do
        @doc.options.expects(:[]).with(:outputdir).returns(false)
        Puppet::Util::RDoc.expects(:rdoc).with('doc', ['modules','manifests'], nil)
        expect { @doc.rdoc }.to exit_with 0
      end

      it "should call Puppet::Util::RDoc.manifestdoc in manifest mode" do
        @doc.manifest = true
        Puppet::Util::RDoc.expects(:manifestdoc)
        expect { @doc.rdoc }.to exit_with 0
      end

      it "should get modulepath and manifestdir values from the environment" do
        @env.expects(:modulepath).returns(['envmodules1','envmodules2'])
        @env.expects(:[]).with(:manifest).returns('envmanifests/site.pp')

        Puppet::Util::RDoc.expects(:rdoc).with('doc', ['envmodules1','envmodules2','envmanifests'], nil)

        expect { @doc.rdoc }.to exit_with 0
      end
    end

    describe "in the other modes" do
      it "should get reference in given format" do
        reference = stub 'reference'
        @doc.options.stubs(:[]).with(:mode).returns(:none)
        @doc.options.stubs(:[]).with(:references).returns([:ref])
        require 'puppet/util/reference'
        Puppet::Util::Reference.expects(:reference).with(:ref).returns(reference)
        @doc.options.stubs(:[]).with(:format).returns(:format)
        @doc.stubs(:exit)

        reference.expects(:send).with { |format,contents| format == :format }.returns('doc')
        @doc.other
      end
    end

  end
end
