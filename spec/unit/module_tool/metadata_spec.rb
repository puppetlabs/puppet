require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::ModuleTool::Metadata do
  let(:data) { {} }
  let(:metadata) { Puppet::ModuleTool::Metadata.new }

  describe 'property lookups' do
    subject { metadata }

    %w[ name version author summary license source project_page issues_url
    dependencies dashed_name release_name description data_provider].each do |prop|
      describe "##{prop}" do
        it "responds to the property" do
          subject.send(prop)
        end
      end
    end
  end

  describe "#update" do
    subject { metadata.update(data) }

    context "with a valid name" do
      let(:data) { { 'name' => 'billgates-mymodule' } }

      it "extracts the author name from the name field" do
        expect(subject.to_hash['author']).to eq('billgates')
      end

      it "extracts a module name from the name field" do
        expect(subject.module_name).to eq('mymodule')
      end

      context "and existing author" do
        before { metadata.update('author' => 'foo') }

        it "avoids overwriting the existing author" do
          expect(subject.to_hash['author']).to eq('foo')
        end
      end
    end

    context "with a valid name and author" do
      let(:data) { { 'name' => 'billgates-mymodule', 'author' => 'foo' } }

      it "use the author name from the author field" do
        expect(subject.to_hash['author']).to eq('foo')
      end

      context "and preexisting author" do
        before { metadata.update('author' => 'bar') }

        it "avoids overwriting the existing author" do
          expect(subject.to_hash['author']).to eq('foo')
        end
      end
    end

    context "with an invalid name" do
      context "(short module name)" do
        let(:data) { { 'name' => 'mymodule' } }

        it "raises an exception" do
          expect { subject }.to raise_error(ArgumentError, "Invalid 'name' field in metadata.json: the field must be a namespaced module name")
        end
      end

      context "(missing namespace)" do
        let(:data) { { 'name' => '/mymodule' } }

        it "raises an exception" do
          expect { subject }.to raise_error(ArgumentError, "Invalid 'name' field in metadata.json: the field must be a namespaced module name")
        end
      end

      context "(missing module name)" do
        let(:data) { { 'name' => 'namespace/' } }

        it "raises an exception" do
          expect { subject }.to raise_error(ArgumentError, "Invalid 'name' field in metadata.json: the field must be a namespaced module name")
        end
      end

      context "(invalid namespace)" do
        let(:data) { { 'name' => "dolla'bill$-mymodule" } }

        it "raises an exception" do
          expect { subject }.to raise_error(ArgumentError, "Invalid 'name' field in metadata.json: the namespace contains non-alphanumeric characters")
        end
      end

      context "(non-alphanumeric module name)" do
        let(:data) { { 'name' => "dollabils-fivedolla'" } }

        it "raises an exception" do
          expect { subject }.to raise_error(ArgumentError, "Invalid 'name' field in metadata.json: the module name contains non-alphanumeric (or underscore) characters")
        end
      end

      context "(module name starts with a number)" do
        let(:data) { { 'name' => "dollabills-5dollars" } }

        it "raises an exception" do
          expect { subject }.to raise_error(ArgumentError, "Invalid 'name' field in metadata.json: the module name must begin with a letter")
        end
      end
    end


    context "with an invalid version" do
      let(:data) { { 'version' => '3.0' } }

      it "raises an exception" do
        expect { subject }.to raise_error(ArgumentError, "Invalid 'version' field in metadata.json: version string cannot be parsed as a valid Semantic Version")
      end
    end

    context "with a valid source" do
      context "which is a GitHub URL" do
        context "with a scheme" do
          before { metadata.update('source' => 'https://github.com/billgates/amazingness') }

          it "predicts a default project_page" do
            expect(subject.to_hash['project_page']).to eq('https://github.com/billgates/amazingness')
          end

          it "predicts a default issues_url" do
            expect(subject.to_hash['issues_url']).to eq('https://github.com/billgates/amazingness/issues')
          end
        end

        context "without a scheme" do
          before { metadata.update('source' => 'github.com/billgates/amazingness') }

          it "predicts a default project_page" do
            expect(subject.to_hash['project_page']).to eq('https://github.com/billgates/amazingness')
          end

          it "predicts a default issues_url" do
            expect(subject.to_hash['issues_url']).to eq('https://github.com/billgates/amazingness/issues')
          end
        end
      end

      context "which is not a GitHub URL" do
        before { metadata.update('source' => 'https://notgithub.com/billgates/amazingness') }

        it "does not predict a default project_page" do
          expect(subject.to_hash['project_page']).to be nil
        end

        it "does not predict a default issues_url" do
          expect(subject.to_hash['issues_url']).to be nil
        end
      end

      context "which is not a URL" do
        before { metadata.update('source' => 'my brain') }

        it "does not predict a default project_page" do
          expect(subject.to_hash['project_page']).to be nil
        end

        it "does not predict a default issues_url" do
          expect(subject.to_hash['issues_url']).to be nil
        end
      end

    end

    context "with a valid dependency" do
      let(:data) { {'dependencies' => [{'name' => 'puppetlabs-goodmodule'}] }}

      it "adds the dependency" do
        expect(subject.dependencies.size).to eq(1)
      end
    end

    context "with a invalid dependency name" do
      let(:data) { {'dependencies' => [{'name' => 'puppetlabsbadmodule'}] }}

      it "raises an exception" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end

    context "with a valid dependency version range" do
      let(:data) { {'dependencies' => [{'name' => 'puppetlabs-badmodule', 'version_requirement' => '>= 2.0.0'}] }}

      it "adds the dependency" do
        expect(subject.dependencies.size).to eq(1)
      end
    end

    context "with a invalid version range" do
      let(:data) { {'dependencies' => [{'name' => 'puppetlabsbadmodule', 'version_requirement' => '>= banana'}] }}

      it "raises an exception" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end

    context "with duplicate dependencies" do
      let(:data) { {'dependencies' => [{'name' => 'puppetlabs-dupmodule', 'version_requirement' => '1.0.0'},
        {'name' => 'puppetlabs-dupmodule', 'version_requirement' => '0.0.1'}] }
      }

      it "raises an exception" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end

    context "adding a duplicate dependency" do
      let(:data) { {'dependencies' => [{'name' => 'puppetlabs-origmodule', 'version_requirement' => '1.0.0'}] }}

      it "with a different version raises an exception" do
        metadata.add_dependency('puppetlabs-origmodule', '>= 0.0.1')
        expect { subject }.to raise_error(ArgumentError)
      end

      it "with the same version does not add another dependency" do
        metadata.add_dependency('puppetlabs-origmodule', '1.0.0')
        expect(subject.dependencies.size).to eq(1)
      end
    end

    context 'with valid data_provider' do
      let(:data) { {'data_provider' => 'the_name'} }

      it 'validates the provider correctly' do
        expect { subject }.not_to raise_error
      end

      it 'returns the provider' do
        expect(subject.data_provider).to eq('the_name')
      end
    end

    context 'with invalid data_provider' do
      let(:data) { }

      it "raises exception unless argument starts with a letter" do
        expect { metadata.update('data_provider' => '_the_name') }.to raise_error(ArgumentError, /field 'data_provider' must begin with a letter/)
        expect { metadata.update('data_provider' => '') }.to raise_error(ArgumentError, /field 'data_provider' must begin with a letter/)
      end

      it "raises exception if argument contains non-alphanumeric characters" do
        expect { metadata.update('data_provider' => 'the::name') }.to raise_error(ArgumentError, /field 'data_provider' contains non-alphanumeric characters/)
      end

      it "raises exception unless argument is a string" do
        expect { metadata.update('data_provider' => 23) }.to raise_error(ArgumentError, /field 'data_provider' must be a string/)
      end
    end
  end

  describe '#dashed_name' do
    it 'returns nil in the absence of a module name' do
      expect(metadata.update('version' => '1.0.0').release_name).to be_nil
    end

    it 'returns a hyphenated string containing namespace and module name' do
      data = metadata.update('name' => 'foo-bar')
      expect(data.dashed_name).to eq('foo-bar')
    end

    it 'properly handles slash-separated names' do
      data = metadata.update('name' => 'foo/bar')
      expect(data.dashed_name).to eq('foo-bar')
    end

    it 'is unaffected by author name' do
      data = metadata.update('name' => 'foo/bar', 'author' => 'me')
      expect(data.dashed_name).to eq('foo-bar')
    end
  end

  describe '#release_name' do
    it 'returns nil in the absence of a module name' do
      expect(metadata.update('version' => '1.0.0').release_name).to be_nil
    end

    it 'returns nil in the absence of a version' do
      expect(metadata.update('name' => 'foo/bar').release_name).to be_nil
    end

    it 'returns a hyphenated string containing module name and version' do
      data = metadata.update('name' => 'foo/bar', 'version' => '1.0.0')
      expect(data.release_name).to eq('foo-bar-1.0.0')
    end

    it 'is unaffected by author name' do
      data = metadata.update('name' => 'foo/bar', 'version' => '1.0.0', 'author' => 'me')
      expect(data.release_name).to eq('foo-bar-1.0.0')
    end
  end

  describe "#to_hash" do
    subject { metadata.to_hash }

    it "contains the default set of keys" do
      expect(subject.keys.sort).to eq(%w[ name version author summary license source issues_url project_page dependencies data_provider].sort)
    end

    describe "['license']" do
      it "defaults to Apache 2" do
        expect(subject['license']).to eq("Apache-2.0")
      end
    end

    describe "['dependencies']" do
      it "defaults to an empty set" do
        expect(subject['dependencies']).to eq(Set.new)
      end
    end

    context "when updated with non-default data" do
      subject { metadata.update('license' => 'MIT', 'non-standard' => 'yup').to_hash }

      it "overrides the defaults" do
        expect(subject['license']).to eq('MIT')
      end

      it 'contains unanticipated values' do
        expect(subject['non-standard']).to eq('yup')
      end
    end
  end
end
