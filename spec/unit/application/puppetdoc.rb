#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/puppetdoc'

describe "puppetdoc" do
    before :each do
        @puppetdoc = Puppet::Application[:puppetdoc]
        @puppetdoc.stubs(:puts)
        @puppetdoc.run_preinit
        Puppet::Util::Log.stubs(:newdestination)
        Puppet::Util::Log.stubs(:level=)
    end

    it "should ask Puppet::Application to not parse Puppet configuration file" do
        @puppetdoc.should_parse_config?.should be_false
    end

    it "should declare a other command" do
        @puppetdoc.should respond_to(:other)
    end

    it "should declare a rdoc command" do
        @puppetdoc.should respond_to(:rdoc)
    end

    it "should declare a trac command" do
        @puppetdoc.should respond_to(:trac)
    end

    it "should declare a fallback for unknown options" do
        @puppetdoc.should respond_to(:handle_unknown)
    end

    it "should declare a preinit block" do
        @puppetdoc.should respond_to(:run_preinit)
    end

    describe "in preinit" do
        it "should set references to []" do
            @puppetdoc.run_preinit

            @puppetdoc.options[:references].should == []
        end

        it "should init mode to text" do
            @puppetdoc.run_preinit

            @puppetdoc.options[:mode].should == :text
        end

        it "should init format to to_rest" do
            @puppetdoc.run_preinit

            @puppetdoc.options[:format].should == :to_rest
        end
    end

    describe "when handling options" do
        [:all, :outputdir, :verbose, :debug].each do |option|
            it "should declare handle_#{option} method" do
                @puppetdoc.should respond_to("handle_#{option}".to_sym)
            end

            it "should store argument value when calling handle_#{option}" do
                @puppetdoc.options.expects(:[]=).with(option, 'arg')
                @puppetdoc.send("handle_#{option}".to_sym, 'arg')
            end
        end

        it "should store the format if valid" do
            Puppet::Util::Reference.stubs(:method_defined?).with('to_format').returns(true)

            @puppetdoc.options.expects(:[]=).with(:format, 'to_format')

            @puppetdoc.handle_format('format')
        end

        it "should raise an error if the format is not valid" do
            Puppet::Util::Reference.stubs(:method_defined?).with('to_format').returns(false)
            lambda { @puppetdoc.handle_format('format') }
        end

        it "should store the mode if valid" do
            Puppet::Util::Reference.stubs(:modes).returns(stub('mode', :include? => true))

            @puppetdoc.options.expects(:[]=).with(:mode, :mode)

            @puppetdoc.handle_mode('mode')
        end

        it "should store the mode if :rdoc" do
            Puppet::Util::Reference.modes.stubs(:include?).with('rdoc').returns(false)

            @puppetdoc.options.expects(:[]=).with(:mode, :rdoc)

            @puppetdoc.handle_mode('rdoc')
        end

        it "should raise an error if the mode is not valid" do
            Puppet::Util::Reference.modes.stubs(:include?).with('unknown').returns(false)
            lambda { @puppetdoc.handle_mode('unknown') }
        end

        it "should list all references on list and exit" do
            reference = stubs 'reference'
            ref = stubs 'ref'
            Puppet::Util::Reference.stubs(:references).returns([reference])

            Puppet::Util::Reference.expects(:reference).with(reference).returns(ref)
            ref.expects(:doc)
            @puppetdoc.expects(:exit)

            @puppetdoc.handle_list(nil)
        end

        it "should add reference to references list with --reference" do
            @puppetdoc.options[:references] = [:ref1]

            @puppetdoc.handle_reference('ref2')

            @puppetdoc.options[:references].should == [:ref1,:ref2]
        end
    end

    describe "during setup" do

        before :each do
            Puppet::Log.stubs(:newdestination)
            ARGV.stubs(:size).returns(0)
        end

        it "should default to rdoc mode if there are command line arguments" do
            ARGV.stubs(:size).returns(1)
            @puppetdoc.stubs(:setup_rdoc)

            @puppetdoc.options.expects(:[]=).with(:mode,:rdoc)

            @puppetdoc.run_setup
        end

        it "should call setup_rdoc in rdoc mode" do
            @puppetdoc.options.stubs(:[]).with(:mode).returns(:rdoc)

            @puppetdoc.expects(:setup_rdoc)

            @puppetdoc.run_setup
        end

        it "should call setup_reference if not rdoc" do
            @puppetdoc.options.stubs(:[]).with(:mode).returns(:test)

            @puppetdoc.expects(:setup_reference)

            @puppetdoc.run_setup
        end

        describe "in non-rdoc mode" do

            it "should get all non-dynamic reference if --all" do
                @puppetdoc.options.stubs(:[]).with(:all).returns(true)
                @puppetdoc.options.stubs(:[]).with(:references).returns([])
                static = stub 'static', :dynamic? => false
                dynamic = stub 'dynamic', :dynamic? => true
                Reference.stubs(:reference).with(:static).returns(static)
                Reference.stubs(:reference).with(:dynamic).returns(dynamic)
                Reference.stubs(:references).returns([:static,:dynamic])

                @puppetdoc.options.stubs(:[]=).with(:references, [:static])

                @puppetdoc.setup_reference
            end

            it "should default to :type if no references" do
                @puppetdoc.options.stubs(:[]).with(:all).returns(false)
                array = stub 'array', :empty? => true
                @puppetdoc.options.stubs(:[]).with(:references).returns(array)

                array.expects(:<<).with(:type)

                @puppetdoc.setup_reference
            end

        end

        describe "in rdoc mode" do

            before :each do
                @puppetdoc.options.stubs(:[]).returns(false)
                Puppet.stubs(:[]=).with(:name, "puppetmasterd")
                Puppet.stubs(:parse_config)
                Puppet::Util::Log.stubs(:level=)
                Puppet::Util::Log.stubs(:newdestination)
            end

            describe "when there are unknown args" do

                it "should expand --modulepath if any" do
                    @puppetdoc.unknown_args = [ { :opt => "--modulepath", :arg => "path" } ]
                    Puppet.settings.stubs(:handlearg)

                    File.expects(:expand_path).with("path")

                    @puppetdoc.setup_rdoc
                end

                it "should expand --manifestdir if any" do
                    @puppetdoc.unknown_args = [ { :opt => "--manifestdir", :arg => "path" } ]
                    Puppet.settings.stubs(:handlearg)

                    File.expects(:expand_path).with("path")

                    @puppetdoc.setup_rdoc
                end

                it "should give them to Puppet.settings" do
                    @puppetdoc.unknown_args = [ { :opt => :option, :arg => :argument } ]
                    Puppet.settings.expects(:handlearg).with(:option,:argument)

                    @puppetdoc.setup_rdoc
                end
            end

            it "should pretend to be puppetmasterd" do
                Puppet.expects(:[]=).with(:name, "puppetmasterd")

                @puppetdoc.setup_rdoc
            end

            it "should parse puppet configuration" do
                Puppet.expects(:parse_config)

                @puppetdoc.setup_rdoc
            end

            it "should set log level to debug if --debug" do
                @puppetdoc.options.stubs(:[]).with(:debug).returns(true)
                Puppet::Util::Log.expects(:level=).with(:debug)

                @puppetdoc.setup_rdoc
            end

            it "should set log level to info if --verbose" do
                @puppetdoc.options.stubs(:[]).with(:verbose).returns(true)
                Puppet::Util::Log.expects(:level=).with(:info)

                @puppetdoc.setup_rdoc
            end

            it "should set log destination to console if --verbose" do
                @puppetdoc.options.stubs(:[]).with(:verbose).returns(true)

                Puppet::Util::Log.expects(:newdestination).with(:console)

                @puppetdoc.setup_rdoc
            end

            it "should set log destination to console if --debug" do
                @puppetdoc.options.stubs(:[]).with(:debug).returns(true)

                Puppet::Util::Log.expects(:newdestination).with(:console)

                @puppetdoc.setup_rdoc
            end

        end

    end

    describe "when running" do
        before :each do
        end

        describe "in trac mode" do
            it "should call trac for each reference" do
                ref = stub 'ref'
                Puppet::Util::Reference.stubs(:reference).with(:ref).returns(ref)
                @puppetdoc.options.stubs(:[]).with(:references).returns([:ref])
                @puppetdoc.options.stubs(:[]).with(:mode).returns(:trac)

                ref.expects(:trac)

                @puppetdoc.trac
            end
        end

        describe "in rdoc mode" do
            before :each do
                @puppetdoc.manifest = false
                Puppet.stubs(:info)
                Puppet.stubs(:[]).with(:trace).returns(false)
                @env = stub 'env'
                Puppet::Node::Environment.stubs(:new).returns(@env)
                @env.stubs(:modulepath).returns(['modules'])
                @env.stubs(:[]).with(:manifest).returns('manifests/site.pp')
                @puppetdoc.options.stubs(:[]).with(:all).returns(false)
                @puppetdoc.options.stubs(:[]).with(:outputdir).returns('doc')
                Puppet.settings.stubs(:[]=).with(:document_all, false)
                Puppet.settings.stubs(:setdefaults)
                Puppet::Util::RDoc.stubs(:rdoc)
                @puppetdoc.stubs(:exit)
                @old = ARGV.dup
                ARGV.clear
            end

            after :each do
                ARGV << @old
            end

            it "should set document_all on --all" do
                @puppetdoc.options.expects(:[]).with(:all).returns(true)
                Puppet.settings.expects(:[]=).with(:document_all, true)

                @puppetdoc.rdoc
            end

            it "should call Puppet::Util::RDoc.rdoc in full mode" do
                Puppet::Util::RDoc.expects(:rdoc).with('doc', ['modules','manifests'])
                @puppetdoc.rdoc
            end

            it "should call Puppet::Util::RDoc.rdoc in full mode with outputdir set to doc if no --outputdir" do
                @puppetdoc.options.expects(:[]).with(:outputdir).returns(false)
                Puppet::Util::RDoc.expects(:rdoc).with('doc', ['modules','manifests'])
                @puppetdoc.rdoc
            end

            it "should call Puppet::Util::RDoc.manifestdoc in manifest mode" do
                @puppetdoc.manifest = true
                Puppet::Util::RDoc.expects(:manifestdoc)
                @puppetdoc.rdoc
            end

            it "should get modulepath and manifestdir values from the environment" do
                @env.expects(:modulepath).returns(['envmodules1','envmodules2'])
                @env.expects(:[]).with(:manifest).returns('envmanifests/site.pp')

                Puppet::Util::RDoc.expects(:rdoc).with('doc', ['envmodules1','envmodules2','envmanifests'])

                @puppetdoc.rdoc
            end
        end

        describe "in the other modes" do
            it "should get reference in given format" do
                reference = stub 'reference'
                @puppetdoc.options.stubs(:[]).with(:mode).returns(:none)
                @puppetdoc.options.stubs(:[]).with(:references).returns([:ref])
                Puppet::Util::Reference.expects(:reference).with(:ref).returns(reference)
                @puppetdoc.options.stubs(:[]).with(:format).returns(:format)
                @puppetdoc.stubs(:exit)

                reference.expects(:send).with { |format,contents| format == :format }.returns('doc')
                @puppetdoc.other
            end
        end

    end
end
