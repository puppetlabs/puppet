require 'spec_helper'
require 'uri'

describe Puppet::Type.type(:file).attrclass(:content_uri) do
  include PuppetSpec::Files

  describe "#validate" do

    let(:path) { tmpfile('file_content_uri_validate') }
    let(:resource) { Puppet::Type.type(:file).new(:path => path) }

    it "should fail if the URI is not a valid URI" do
      URI.expects(:parse).with('not_a_uri').raises RuntimeError
      expect(lambda { resource[:content_uri] = 'not_a_uri' }).to raise_error(Puppet::Error)
    end

    it "should fail if the URI does not adhere to the Puppet URI scheme" do
      expect(lambda { resource[:content_uri] = 'ftp://foo/bar' }).to raise_error(Puppet::Error, /Must use URLs of type puppet as content URI/)
    end
  end
end
