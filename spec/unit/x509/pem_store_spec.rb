# coding: utf-8
require 'spec_helper'
require 'puppet/x509'

class Puppet::X509::TestPemStore
  include Puppet::X509::PemStore
end

describe Puppet::X509::PemStore do
  include PuppetSpec::Files

  let(:subject) { Puppet::X509::TestPemStore.new }

  context 'loading' do
    it 'returns nil if it does not exist' do
      expect(subject.load_pem('/does/not/exist')).to be_nil
    end

    it 'returns the file content as UTF-8' do
      expect(
        subject.load_pem(my_fixture('utf8-comment.pem'))
      ).to match(/\ANetLock Arany \(Class Gold\) Főtanúsítvány/)
    end
  end

  context 'saving' do
    let(:content) { <<X509 }
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
X509

    it 'writes the file content as UTF-8' do
      path = tmpfile('pem_store')
      utf8 = File.read(my_fixture('utf8-comment.pem'), :encoding => 'UTF-8')

      subject.save_pem(utf8, path)

      expect(
        File.read(path, :encoding => 'UTF-8')
      ).to match(/\ANetLock Arany \(Class Gold\) Főtanúsítvány/)
    end
  end

  context 'deleting' do
    it 'returns false if the file does not exist' do
      expect(subject.delete_pem('/does/not/exist')).to eq(false)
    end

    it 'returns true if the file exists' do
      path = tmpfile('pem_store')
      FileUtils.touch(path)

      expect(subject.delete_pem(path)).to eq(true)
    end
  end
end
