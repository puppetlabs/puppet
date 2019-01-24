require 'spec_helper'

require 'puppet/indirector/yaml'

describe Puppet::Indirector::Yaml do
  include PuppetSpec::Files

  class TestSubject
    attr_accessor :name
  end

  before :each do
    @indirection = Puppet::Indirector::Indirection.new(nil, :my_yaml)

    module MyYaml; end
    @store_class = class MyYaml::MyType < Puppet::Indirector::Yaml
      self
    end

    @store = @store_class.new

    @subject = TestSubject.new
    @subject.name = :me

    @dir = tmpdir("yaml_indirector")
    Puppet[:clientyamldir] = @dir
    allow(Puppet.run_mode).to receive(:master?).and_return(false)

    @request = double('request', :key => :me, :instance => @subject)
  end

  after(:each) do
    @indirection.delete
  end

  let(:serverdir) { File.expand_path("/server/yaml/dir") }
  let(:clientdir) { File.expand_path("/client/yaml/dir") }

  describe "when choosing file location" do
    it "should use the server_datadir if the run_mode is master" do
      allow(Puppet.run_mode).to receive(:master?).and_return(true)
      Puppet[:yamldir] = serverdir
      expect(@store.path(:me)).to match(/^#{serverdir}/)
    end

    it "should use the client yamldir if the run_mode is not master" do
      allow(Puppet.run_mode).to receive(:master?).and_return(false)
      Puppet[:clientyamldir] = clientdir
      expect(@store.path(:me)).to match(/^#{clientdir}/)
    end

    it "should use the extension if one is specified" do
      allow(Puppet.run_mode).to receive(:master?).and_return(true)
      Puppet[:yamldir] = serverdir
      expect(@store.path(:me,'.farfignewton')).to match(%r{\.farfignewton$})
    end

    it "should assume an extension of .yaml if none is specified" do
      allow(Puppet.run_mode).to receive(:master?).and_return(true)
      Puppet[:yamldir] = serverdir
      expect(@store.path(:me)).to match(%r{\.yaml$})
    end

    it "should store all files in a single file root set in the Puppet defaults" do
      expect(@store.path(:me)).to match(%r{^#{@dir}})
    end

    it "should use the terminus name for choosing the subdirectory" do
      expect(@store.path(:me)).to match(%r{^#{@dir}/my_yaml})
    end

    it "should use the object's name to determine the file name" do
      expect(@store.path(:me)).to match(%r{me.yaml$})
    end

    ['../foo', '..\\foo', './../foo', '.\\..\\foo',
     '/foo', '//foo', '\\foo', '\\\\goo',
     "test\0/../bar", "test\0\\..\\bar",
     "..\\/bar", "/tmp/bar", "/tmp\\bar", "tmp\\bar",
     " / bar", " /../ bar", " \\..\\ bar",
     "c:\\foo", "c:/foo", "\\\\?\\UNC\\bar", "\\\\foo\\bar",
     "\\\\?\\c:\\foo", "//?/UNC/bar", "//foo/bar",
     "//?/c:/foo",
    ].each do |input|
      it "should resist directory traversal attacks (#{input.inspect})" do
        expect { @store.path(input) }.to raise_error(ArgumentError)
      end
    end
  end

  describe "when storing objects as YAML" do
    it "should only store objects that respond to :name" do
      allow(@request).to receive(:instance).and_return(Object.new)
      expect { @store.save(@request) }.to raise_error(ArgumentError)
    end
  end

  describe "when retrieving YAML" do
    it "should read YAML in from disk and convert it to Ruby objects" do
      @store.save(Puppet::Indirector::Request.new(:my_yaml, :save, "testing", @subject))

      expect(@store.find(Puppet::Indirector::Request.new(:my_yaml, :find, "testing", nil)).name).to eq(:me)
    end

    it "should fail coherently when the stored YAML is invalid" do
      saved_structure = Struct.new(:name).new("testing")

      @store.save(Puppet::Indirector::Request.new(:my_yaml, :save, "testing", saved_structure))
      File.open(@store.path(saved_structure.name), "w") do |file|
        file.puts "{ invalid"
      end

      expect {
        @store.find(Puppet::Indirector::Request.new(:my_yaml, :find, "testing", nil))
      }.to raise_error(Puppet::Error, /Could not parse YAML data/)
    end
  end

  describe "when searching" do
    it "should return an array of fact instances with one instance for each file when globbing *" do
      @request = double('request', :key => "*", :instance => @subject)
      @one = double('one')
      @two = double('two')
      expect(@store).to receive(:path).with(@request.key,'').and_return(:glob)
      expect(Dir).to receive(:glob).with(:glob).and_return(%w{one.yaml two.yaml})
      expect(YAML).to receive(:load_file).with("one.yaml").and_return(@one)
      expect(YAML).to receive(:load_file).with("two.yaml").and_return(@two)
      expect(@store.search(@request)).to contain_exactly(@one, @two)
    end

    it "should return an array containing a single instance of fact when globbing 'one*'" do
      @request = double('request', :key => "one*", :instance => @subject)
      @one = double('one')
      expect(@store).to receive(:path).with(@request.key,'').and_return(:glob)
      expect(Dir).to receive(:glob).with(:glob).and_return(%w{one.yaml})
      expect(YAML).to receive(:load_file).with("one.yaml").and_return(@one)
      expect(@store.search(@request)).to eq([@one])
    end

    it "should return an empty array when the glob doesn't match anything" do
      @request = double('request', :key => "f*ilglobcanfail*", :instance => @subject)
      expect(@store).to receive(:path).with(@request.key,'').and_return(:glob)
      expect(Dir).to receive(:glob).with(:glob).and_return([])
      expect(@store.search(@request)).to eq([])
    end

    describe "when destroying" do
      let(:path) do
        File.join(@dir, @store.class.indirection_name.to_s, @request.key.to_s + ".yaml")
      end

      it "should unlink the right yaml file if it exists" do
        expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)
        expect(Puppet::FileSystem).to receive(:unlink).with(path)

        @store.destroy(@request)
      end

      it "should not unlink the yaml file if it does not exists" do
        expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(false)
        expect(Puppet::FileSystem).not_to receive(:unlink).with(path)

        @store.destroy(@request)
      end
    end
  end
end
