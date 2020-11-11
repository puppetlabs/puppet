require 'spec_helper'

require 'puppet/indirector/file_bucket_file/selector'
require 'puppet/indirector/file_bucket_file/file'
require 'puppet/indirector/file_bucket_file/rest'

describe Puppet::FileBucketFile::Selector do
  let(:model) { Puppet::FileBucket::File.new('') }
  let(:indirection) { Puppet::FileBucket::File.indirection }
  let(:terminus) { indirection.terminus(:selector) }

  %w[head find save search destroy].each do |method|
    describe "##{method}" do
      it "should proxy to rest terminus for https requests" do
        key = "https://example.com/path/to/file"

        expect(indirection.terminus(:rest)).to receive(method)

        if method == 'save'
          terminus.send(method, indirection.request(method, key, model))
        else
          terminus.send(method, indirection.request(method, key, nil))
        end
      end

      it "should proxy to file terminus for other requests" do
        key = "file:///path/to/file"

        case method
        when 'save'
          expect(indirection.terminus(:file)).to receive(method)
          terminus.send(method, indirection.request(method, key, model))
        when 'find', 'head'
          expect(indirection.terminus(:file)).to receive(method)
          terminus.send(method, indirection.request(method, key, nil))
        else
          # file terminus doesn't implement search or destroy
          expect {
            terminus.send(method, indirection.request(method, key, nil))
          }.to raise_error(NoMethodError)
        end
      end
    end
  end
end

