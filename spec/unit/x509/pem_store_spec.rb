# coding: utf-8
require 'spec_helper'
require 'puppet/x509'

class Puppet::X509::TestPemStore
  include Puppet::X509::PemStore
end

describe Puppet::X509::PemStore do
  include PuppetSpec::Files

  let(:subject) { Puppet::X509::TestPemStore.new }

  def with_unreadable_file
    path = tmpfile('pem_store')
    Puppet::FileSystem.touch(path)
    Puppet::FileSystem.chmod(0, path)
    yield path
  ensure
    Puppet::FileSystem.chmod(0600, path)
  end

  def with_unwritable_file(&block)
    if Puppet::Util::Platform.windows?
      with_unwritable_file_win32(&block)
    else
      with_unwritable_file_posix(&block)
    end
  end

  def with_unwritable_file_win32
    dir = tmpdir('pem_store')
    path = File.join(dir, 'unwritable')

    # if file handle is open, then file can't be written by other processes
    File.open(path, 'w') do |f|
      yield path
    end
  end

  def with_unwritable_file_posix
    dir = tmpdir('pem_store')
    path = File.join(dir, 'unwritable')
    # if directory is not executable/traverseable, then file can't be written to
    Puppet::FileSystem.chmod(0, dir)
    begin
      yield path
    ensure
      Puppet::FileSystem.chmod(0700, dir)
    end
  end

  let(:cert_path) { File.join(PuppetSpec::FIXTURE_DIR, 'ssl', 'netlock-arany-utf8.pem') }

  context 'loading' do
    it 'returns nil if it does not exist' do
      expect(subject.load_pem('/does/not/exist')).to be_nil
    end

    it 'returns the file content as UTF-8' do
      expect(
        subject.load_pem(cert_path)
      ).to match(/\ANetLock Arany \(Class Gold\) Főtanúsítvány/)
    end

    it 'raises EACCES if the file is unreadable' do
      with_unreadable_file do |path|
        expect {
          subject.load_pem(path)
        }.to raise_error(Errno::EACCES, /Permission denied/)
      end
    end
  end

  context 'saving' do
    let(:path) { tmpfile('pem_store') }

    it 'writes the file content as UTF-8' do
      # read the file directly to preserve the comments
      utf8 = File.read(cert_path, encoding: 'UTF-8')

      subject.save_pem(utf8, path)

      expect(
        File.read(path, :encoding => 'UTF-8')
      ).to match(/\ANetLock Arany \(Class Gold\) Főtanúsítvány/)
    end

    it 'never changes the owner and group on Windows', if: Puppet::Util::Platform.windows? do
      expect(FileUtils).not_to receive(:chown)

      subject.save_pem('PEM', path, owner: 'Administrator', group: 'None')
    end

    it 'changes the owner and group when running as root', unless: Puppet::Util::Platform.windows? do
      allow(Puppet.features).to receive(:root?).and_return(true)
      expect(FileUtils).to receive(:chown).with('root', 'root', path)

      subject.save_pem('PEM', path, owner: 'root', group: 'root')
    end

    it 'does not change owner and group when running not as roo', unless: Puppet::Util::Platform.windows? do
      allow(Puppet.features).to receive(:root?).and_return(false)
      expect(FileUtils).not_to receive(:chown)

      subject.save_pem('PEM', path, owner: 'root', group: 'root')
    end

    it 'allows a mode of 0600 to be specified', unless: Puppet::Util::Platform.windows? do
      subject.save_pem('PEM', path, mode: 0600)

      expect(File.stat(path).mode & 0777).to eq(0600)
    end

    it 'defaults the mode to 0644' do
      subject.save_pem('PEM', path)

      expect(File.stat(path).mode & 0777).to eq(0644)
    end

    it 'raises EACCES if the file is unwritable' do
      with_unwritable_file do |path|
        expect {
          subject.save_pem('', path)
        }.to raise_error(Errno::EACCES, /Permission denied/)
      end
    end

    it 'raises if the directory does not exist' do
      dir = tmpdir('pem_store')
      Dir.unlink(dir)

      expect {
        subject.save_pem('', File.join(dir, 'something'))
      }.to raise_error(Errno::ENOENT, /No such file or directory/)
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
      expect(File).to_not be_exist(path)
    end

    it 'raises EACCES if the file is undeletable' do
      with_unwritable_file do |path|
        expect {
          subject.delete_pem(path)
        }.to raise_error(Errno::EACCES, /Permission denied/)
      end
    end
  end
end
