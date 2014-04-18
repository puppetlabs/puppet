require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::ModuleTool::Metadata do
  let(:data) { {} }
  let(:metadata) { Puppet::ModuleTool::Metadata.new }

  describe "#update" do
    subject { metadata.update(data) }

    context "with a valid name" do
      let(:data) { { 'name' => 'billgates-mymodule' } }

      it "extracts the author name from the name field" do
        subject.to_hash['author'].should == 'billgates'
      end

      it "extracts a module name from the name field" do
        subject.module_name.should == 'mymodule'
      end

      context "and existing author" do
        before { metadata.update('author' => 'foo') }

        it "avoids overwriting the existing author" do
          subject.to_hash['author'].should == 'foo'
        end
      end
    end

    context "with a valid name and author" do
      let(:data) { { 'name' => 'billgates-mymodule', 'author' => 'foo' } }

      it "use the author name from the author field" do
        subject.to_hash['author'].should == 'foo'
      end

      context "and preexisting author" do
        before { metadata.update('author' => 'bar') }

        it "avoids overwriting the existing author" do
          subject.to_hash['author'].should == 'foo'
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
  end

  describe '#dashed_name' do
    it 'returns nil in the absence of a module name' do
      expect(metadata.update('version' => '1.0.0').release_name).to be_nil
    end

    it 'returns a hyphenated string containing namespace and module name' do
      data = metadata.update('name' => 'foo-bar')
      data.dashed_name.should == 'foo-bar'
    end

    it 'properly handles slash-separated names' do
      data = metadata.update('name' => 'foo/bar')
      data.dashed_name.should == 'foo-bar'
    end

    it 'is unaffected by author name' do
      data = metadata.update('name' => 'foo/bar', 'author' => 'me')
      data.dashed_name.should == 'foo-bar'
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
      data.release_name.should == 'foo-bar-1.0.0'
    end

    it 'is unaffected by author name' do
      data = metadata.update('name' => 'foo/bar', 'version' => '1.0.0', 'author' => 'me')
      data.release_name.should == 'foo-bar-1.0.0'
    end
  end

  describe "#to_hash" do
    subject { metadata.to_hash }

    its(:keys) do
      subject.sort.should == %w[ name version author summary license source dependencies ].sort
    end

    describe "['license']" do
      it "defaults to Apache 2" do
        subject['license'].should == "Apache License, Version 2.0"
      end
    end

    describe "['dependencies']" do
      it "defaults to an empty Array" do
        subject['dependencies'].should == []
      end
    end

    context "when updated with non-default data" do
      subject { metadata.update('license' => 'MIT', 'non-standard' => 'yup').to_hash }

      it "overrides the defaults" do
        subject['license'].should == 'MIT'
      end

      it 'contains unanticipated values' do
        subject['non-standard'].should == 'yup'
      end
    end
  end
end
