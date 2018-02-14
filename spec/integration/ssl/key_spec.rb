#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/ssl/key'

describe Puppet::SSL::Key do
  include PuppetSpec::Files

  # different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte ܎ - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  let (:mixed_utf8) { "A\u06FF\u16A0\u{2070E}" } # Aۿᚠ܎

  before do
    # Get a safe temporary file
    dir = tmpdir('key_integration_testing')

    Puppet.settings[:confdir] = dir
    Puppet.settings[:vardir] = dir

    # This is necessary so the terminus instances don't lie around.
    # and so that Puppet::SSL::Key.indirection.save may be used
    Puppet::SSL::Key.indirection.termini.clear
  end

  describe 'with a custom user-specified passfile' do

    before do
      # write custom password file to where Puppet expects
      password_file = tmpfile('passfile')
      Puppet[:passfile] = password_file
      Puppet::FileSystem.open(password_file, nil, 'w:UTF-8') { |f| f.print(mixed_utf8) }
    end

    it 'should use the configured password file if it is not the CA key' do
      key = Puppet::SSL::Key.new('test')
      expect(key.password_file).to eq(Puppet[:passfile])
      expect(key.password).to eq(mixed_utf8.force_encoding(Encoding::BINARY))
    end

    it "should be able to read an existing private key given the correct password" do
      Puppet[:keylength] = '50'

      key_name = 'test'
      # use OpenSSL APIs to generate a private key
      private_key = OpenSSL::PKey::RSA.generate(512)

      # stash it in Puppets private key directory
      FileUtils.mkdir_p(Puppet[:privatekeydir])
      pem_path = File.join(Puppet[:privatekeydir], "#{key_name}.pem")
      Puppet::FileSystem.open(pem_path, nil, 'w:UTF-8') do |f|
        # with password protection enabled
        pem = private_key.to_pem(OpenSSL::Cipher::DES.new(:EDE3, :CBC), mixed_utf8)
        f.print(pem)
      end

      # indirector loads existing .pem off disk instead of replacing it
      host = Puppet::SSL::Host.new(key_name)
      host.generate

      # newly loaded host private key matches the manually created key
      # Private-Key: (512 bit) style data
      expect(host.key.content.to_text).to eq(private_key.to_text)
      # -----BEGIN RSA PRIVATE KEY-----
      expect(host.key.content.to_s).to eq(private_key.to_s)
      expect(host.key.password).to eq(mixed_utf8.force_encoding(Encoding::BINARY))
    end

    it 'should export the private key to PEM using the password' do
      Puppet[:keylength] = '50'

      key_name = 'test'

      # uses specified :passfile when writing the private key
      key = Puppet::SSL::Key.new(key_name)
      key.generate
      Puppet::SSL::Key.indirection.save(key)

      # indirector writes file here
      pem_path = File.join(Puppet[:privatekeydir], "#{key_name}.pem")

      # note incorrect password is an error
      expect do
        Puppet::FileSystem.open(pem_path, nil, 'r:ASCII') do |f|
          OpenSSL::PKey::RSA.new(f.read, 'invalid_password')
        end
      end.to raise_error(OpenSSL::PKey::RSAError)

      # but when specifying the correct password
      reloaded_key = nil
      Puppet::FileSystem.open(pem_path, nil, 'r:ASCII') do |f|
        reloaded_key = OpenSSL::PKey::RSA.new(f.read, mixed_utf8)
      end

      # the original key matches the manually reloaded key
      # Private-Key: (512 bit) style data
      expect(key.content.to_text).to eq(reloaded_key.to_text)
      # -----BEGIN RSA PRIVATE KEY-----
      expect(key.content.to_s).to eq(reloaded_key.to_s)
    end
  end
end
