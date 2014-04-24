require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/files'
require 'pathname'

describe Puppet::ModuleTool::Applications::Checksummer do
  let(:tmpdir) do
    Pathname.new(PuppetSpec::Files.tmpdir('checksummer'))
  end

  let(:checksums) { Puppet::ModuleTool::Checksums.new(tmpdir).data }

  subject do
    described_class.run(tmpdir)
  end

  before do
    File.open(tmpdir + 'README', 'w') { |f| f.puts "This is a README!" }
    File.open(tmpdir + 'CHANGES', 'w') { |f| f.puts "This is a changelog!" }
    File.open(tmpdir + 'DELETEME', 'w') { |f| f.puts "I've got a really good feeling about this!" }
    Dir.mkdir(tmpdir + 'pkg')
    File.open(tmpdir + 'pkg' + 'build-artifact', 'w') { |f| f.puts "I'm unimportant!" }
    File.open(tmpdir + 'metadata.json', 'w') { |f| f.puts '{"name": "package-name", "version": "1.0.0"}' }
    File.open(tmpdir + 'checksums.json', 'w') { |f| f.puts '{}' }
  end

  context 'with checksums.json' do
    before do
      File.open(tmpdir + 'checksums.json', 'w') { |f| f.puts checksums.to_json }
      File.open(tmpdir + 'CHANGES', 'w') { |f| f.puts "This is a changed log!" }
      File.open(tmpdir + 'pkg' + 'build-artifact', 'w') { |f| f.puts "I'm still unimportant!" }
      (tmpdir + 'DELETEME').unlink
    end

    it 'reports changed files' do
      expect(subject).to include 'CHANGES'
    end

    it 'reports removed files' do
      expect(subject).to include 'DELETEME'
    end

    it 'does not report unchanged files' do
      expect(subject).to_not include 'README'
    end

    it 'does not report build artifacts' do
      expect(subject).to_not include 'pkg/build-artifact'
    end

    it 'does not report checksums.json' do
      expect(subject).to_not include 'checksums.json'
    end
  end

  context 'without checksums.json' do
    context 'but with metadata.json containing checksums' do
      before do
        (tmpdir + 'checksums.json').unlink
        File.open(tmpdir + 'metadata.json', 'w') { |f| f.puts "{\"checksums\":#{checksums.to_json}}" }
        File.open(tmpdir + 'CHANGES', 'w') { |f| f.puts "This is a changed log!" }
        File.open(tmpdir + 'pkg' + 'build-artifact', 'w') { |f| f.puts "I'm still unimportant!" }
        (tmpdir + 'DELETEME').unlink
      end

      it 'reports changed files' do
        expect(subject).to include 'CHANGES'
      end

      it 'reports removed files' do
        expect(subject).to include 'DELETEME'
      end

      it 'does not report unchanged files' do
        expect(subject).to_not include 'README'
      end

      it 'does not report build artifacts' do
        expect(subject).to_not include 'pkg/build-artifact'
      end

      it 'does not report checksums.json' do
        expect(subject).to_not include 'checksums.json'
      end
    end

    context 'and with metadata.json that does not contain checksums' do
      before do
        (tmpdir + 'checksums.json').unlink
        File.open(tmpdir + 'CHANGES', 'w') { |f| f.puts "This is a changed log!" }
        File.open(tmpdir + 'pkg' + 'build-artifact', 'w') { |f| f.puts "I'm still unimportant!" }
        (tmpdir + 'DELETEME').unlink
      end

      it 'fails' do
        expect { subject }.to raise_error(ArgumentError, 'No file containing checksums found.')
      end
    end

    context 'and without metadata.json' do
      before do
        (tmpdir + 'checksums.json').unlink
        (tmpdir + 'metadata.json').unlink

        File.open(tmpdir + 'CHANGES', 'w') { |f| f.puts "This is a changed log!" }
        File.open(tmpdir + 'pkg' + 'build-artifact', 'w') { |f| f.puts "I'm still unimportant!" }
        (tmpdir + 'DELETEME').unlink
      end

      it 'fails' do
        expect { subject }.to raise_error(ArgumentError, 'No file containing checksums found.')
      end
    end
  end
end
