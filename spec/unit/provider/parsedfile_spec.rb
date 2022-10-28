require 'spec_helper'
require 'puppet_spec/files'

require 'puppet'
require 'puppet/provider/parsedfile'

Puppet::Type.newtype(:parsedfile_type) do
  newparam(:name)
  newproperty(:target)
end

# Most of the tests for this are still in test/ral/provider/parsedfile.rb.
describe Puppet::Provider::ParsedFile do
  # The ParsedFile provider class is meant to be used as an abstract base class
  # but also stores a lot of state within the singleton class. To avoid
  # sharing data between classes we construct an anonymous class that inherits
  # the ParsedFile provider instead of directly working with the ParsedFile
  # provider itself.
  let(:parsed_type) do
    Puppet::Type.type(:parsedfile_type)
  end

  let!(:provider) { parsed_type.provide(:parsedfile_provider, :parent => described_class) }

  describe "when looking up records loaded from disk" do
    it "should return nil if no records have been loaded" do
      expect(provider.record?("foo")).to be_nil
    end
  end

  describe "when generating a list of instances" do
    it "should return an instance for each record parsed from all of the registered targets" do
      expect(provider).to receive(:targets).and_return(%w{/one /two})
      allow(provider).to receive(:skip_record?).and_return(false)
      one = [:uno1, :uno2]
      two = [:dos1, :dos2]
      expect(provider).to receive(:prefetch_target).with("/one").and_return(one)
      expect(provider).to receive(:prefetch_target).with("/two").and_return(two)

      results = []
      (one + two).each do |inst|
        results << inst.to_s + "_instance"
        expect(provider).to receive(:new).with(inst).and_return(results[-1])
      end

      expect(provider.instances).to eq(results)
    end

    it "should ignore target when retrieve fails" do
      expect(provider).to receive(:targets).and_return(%w{/one /two /three})
      allow(provider).to receive(:skip_record?).and_return(false)
      expect(provider).to receive(:retrieve).with("/one").and_return([
        {:name => 'target1_record1'},
        {:name => 'target1_record2'}
      ])
      expect(provider).to receive(:retrieve).with("/two").and_raise(Puppet::Util::FileType::FileReadError, "some error")
      expect(provider).to receive(:retrieve).with("/three").and_return([
        {:name => 'target3_record1'},
        {:name => 'target3_record2'}
      ])
      expect(Puppet).to receive(:err).with('Could not prefetch parsedfile_type provider \'parsedfile_provider\' target \'/two\': some error. Treating as empty')
      expect(provider).to receive(:new).with({:name => 'target1_record1', :on_disk => true, :target => '/one', :ensure => :present}).and_return('r1')
      expect(provider).to receive(:new).with({:name => 'target1_record2', :on_disk => true, :target => '/one', :ensure => :present}).and_return('r2')
      expect(provider).to receive(:new).with({:name => 'target3_record1', :on_disk => true, :target => '/three', :ensure => :present}).and_return('r3')
      expect(provider).to receive(:new).with({:name => 'target3_record2', :on_disk => true, :target => '/three', :ensure => :present}).and_return('r4')

      expect(provider.instances).to eq(%w{r1 r2 r3 r4})
    end

    it "should skip specified records" do
      expect(provider).to receive(:targets).and_return(%w{/one})
      expect(provider).to receive(:skip_record?).with(:uno).and_return(false)
      expect(provider).to receive(:skip_record?).with(:dos).and_return(true)
      one = [:uno, :dos]
      expect(provider).to receive(:prefetch_target).and_return(one)

      expect(provider).to receive(:new).with(:uno).and_return("eh")
      expect(provider).not_to receive(:new).with(:dos)

      provider.instances
    end

    it "should raise if parsing returns nil" do
      expect(provider).to receive(:targets).and_return(%w{/one})
      expect_any_instance_of(Puppet::Util::FileType::FileTypeFlat).to receive(:read).and_return('a=b')
      expect(provider).to receive(:parse).and_return(nil)

      expect {
        provider.instances
      }.to raise_error(Puppet::DevError, %r{Prefetching /one for provider parsedfile_provider returned nil})
    end
  end

  describe "when matching resources to existing records" do
    let(:first_resource) { double(:one, :name => :one) }
    let(:second_resource) { double(:two, :name => :two) }

    let(:resources) {{:one => first_resource, :two => second_resource}}

    it "returns a resource if the record name matches the resource name" do
      record = {:name => :one}
      expect(provider.resource_for_record(record, resources)).to be first_resource
    end

    it "doesn't return a resource if the record name doesn't match any resource names" do
      record = {:name => :three}
      expect(provider.resource_for_record(record, resources)).to be_nil
    end
  end

  describe "when flushing a file's records to disk" do
    before do
      # This way we start with some @records, like we would in real life.
      allow(provider).to receive(:retrieve).and_return([])
      provider.default_target = "/foo/bar"
      provider.initvars
      provider.prefetch

      @filetype = Puppet::Util::FileType.filetype(:flat).new("/my/file")
      allow(Puppet::Util::FileType.filetype(:flat)).to receive(:new).with("/my/file").and_return(@filetype)

      allow(@filetype).to receive(:write)
    end

    it "should back up the file being written if the filetype can be backed up" do
      expect(@filetype).to receive(:backup)

      provider.flush_target("/my/file")
    end

    it "should not try to back up the file if the filetype cannot be backed up" do
      @filetype = Puppet::Util::FileType.filetype(:ram).new("/my/file")
      expect(Puppet::Util::FileType.filetype(:flat)).to receive(:new).and_return(@filetype)

      allow(@filetype).to receive(:write)

      provider.flush_target("/my/file")
    end

    it "should not back up the file more than once between calls to 'prefetch'" do
      expect(@filetype).to receive(:backup).once

      provider.flush_target("/my/file")
      provider.flush_target("/my/file")
    end

    it "should back the file up again once the file has been reread" do
      expect(@filetype).to receive(:backup).twice

      provider.flush_target("/my/file")
      provider.prefetch
      provider.flush_target("/my/file")
    end
  end

  describe "when flushing multiple files" do
    describe "and an error is encountered" do
      it "the other file does not fail" do
        allow(provider).to receive(:backup_target)

        bad_file = 'broken'
        good_file = 'writable'

        bad_writer = double('bad')
        expect(bad_writer).to receive(:write).and_raise(Exception, "Failed to write to bad file")

        good_writer = double('good')
        expect(good_writer).to receive(:write).and_return(nil)

        allow(provider).to receive(:target_object).with(bad_file).and_return(bad_writer)
        allow(provider).to receive(:target_object).with(good_file).and_return(good_writer)

        bad_resource = parsed_type.new(:name => 'one', :target => bad_file)
        good_resource = parsed_type.new(:name => 'two', :target => good_file)

        expect {
          bad_resource.flush
        }.to raise_error(Exception, "Failed to write to bad file")

        good_resource.flush
      end
    end
  end
end

describe "A very basic provider based on ParsedFile" do
  include PuppetSpec::Files

  let(:input_text) { File.read(my_fixture('simple.txt')) }
  let(:target) { tmpfile('parsedfile_spec') }

  let(:provider) do
    example_provider_class = Class.new(Puppet::Provider::ParsedFile)
    example_provider_class.default_target = target
    # Setup some record rules
    example_provider_class.instance_eval do
      text_line :text, :match => %r{.}
    end
    example_provider_class.initvars
    example_provider_class.prefetch
    # evade a race between multiple invocations of the header method
    allow(example_provider_class).to receive(:header).
      and_return("# HEADER As added by puppet.\n")
    example_provider_class
  end

  context "writing file contents back to disk" do
    it "should not change anything except from adding a header" do
      input_records = provider.parse(input_text)
      expect(provider.to_file(input_records)).
        to match provider.header + input_text
    end
  end

  context "rewriting a file containing a native header" do
    let(:regex) { %r/^# HEADER.*third party\.\n/ }
    let(:input_records) { provider.parse(input_text) }

    before :each do
      allow(provider).to receive(:native_header_regex).and_return(regex)
    end

    it "should move the native header to the top" do
      expect(provider.to_file(input_records)).not_to match(/\A#{provider.header}/)
    end

    context "and dropping native headers found in input" do
      before :each do
        allow(provider).to receive(:drop_native_header).and_return(true)
      end

      it "should not include the native header in the output" do
        expect(provider.to_file(input_records)).not_to match regex
      end
    end
  end

  context 'parsing a record type' do
    let(:input_text) { File.read(my_fixture('aliases.txt')) }
    let(:target) { tmpfile('parsedfile_spec') }
    let(:provider) do
      example_provider_class = Class.new(Puppet::Provider::ParsedFile)
      example_provider_class.default_target = target
      # Setup some record rules
      example_provider_class.instance_eval do
        record_line :aliases, :fields =>  %w{manager alias}, :separator => ':'
      end
      example_provider_class.initvars
      example_provider_class.prefetch
      example_provider_class
    end
    let(:expected_result) do
      [
        {:manager=>"manager", :alias=>"  root", :record_type=>:aliases},
        {:manager=>"dumper", :alias=>"   postmaster", :record_type=>:aliases}
      ]
    end

    subject { provider.parse(input_text) }

    it { is_expected.to  match_array(expected_result) }
  end
end
