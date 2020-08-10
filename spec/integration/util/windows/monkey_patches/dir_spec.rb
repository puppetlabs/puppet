# coding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe 'Dir', if: Puppet::Util::Platform.windows? do

  before(:all) do
    @temp = Dir.tmpdir
    @from = File.join(@temp, 'test_from_directory')
    @ascii_to = File.join(@temp, 'test_to_directory')
    @unicode_to = File.join(@temp, 'Ελλάσ')
    @test_file = File.join(@from, 'test.txt')

    Dir.mkdir(@from)
  end

  after(:all) do
    FileUtils.rm_rf(@ascii_to)
    FileUtils.rm_rf(@unicode_to)
    FileUtils.rm_rf(@from)
  end

  let(:pattern1) { "C:\\Program Files\\Common Files\\System\\*.dll" }
  let(:pattern2) { "C:\\Windows\\*.exe" }
  let(:pathname1) { Pathname.new(pattern1) }
  let(:pathname2) { Pathname.new(pattern2) }

  let(:from) { @from }
  let(:ascii_to) { @ascii_to }
  let(:unicode_to) { @unicode_to }
  let(:test_file) { @test_file }

  describe '.glob' do
    it 'handles backslashes' do
      expect { Dir.glob(pattern1) }.not_to raise_error
      expect(Dir.glob(pattern1)).not_to be_empty
    end

    it 'handles multiple strings' do
      expect { Dir.glob([pattern1, pattern2]) }.not_to raise_error
      expect(Dir.glob([pattern1, pattern2])).not_to be_empty
    end

    it 'still observes flags' do
      expect { Dir.glob('*', File::FNM_DOTMATCH) }.not_to raise_error
      expect(Dir.glob('*', File::FNM_DOTMATCH)).to include('.')
    end

    it 'still honors block' do
      array = []
      expect do
        Dir.glob('*', File::FNM_DOTMATCH) { |m| array << m }
      end.not_to raise_error
      expect(array).to include('.')
    end

    it 'handles Pathname objects' do
      expect { Dir.glob([pathname1, pathname2]) }.not_to raise_error
      expect(Dir.glob([pathname1, pathname2])).not_to be_empty
    end

    it 'requires a stringy argument' do
      expect { Dir.glob(nil) }.to raise_error(TypeError)
    end
  end

  describe '.[]' do
    it 'handles backslashes' do
      expect { Dir[pattern1] }.not_to raise_error
      expect(Dir[pattern1]).not_to be_empty
    end

    it 'handles multiple arguments' do
      expect { Dir[pattern1, pattern2] }.not_to raise_error
      expect(Dir[pattern1, pattern2]).not_to be_empty
    end

    it 'handles Pathname arguments' do
      expect { Dir[pathname1, pathname2] }.not_to raise_error
      expect(Dir[pathname1, pathname2]).not_to be_empty
    end
  end

  describe '.create_junction' do
    after(:all) { FileUtils.rm_f(@test_file) }

    it 'is callable' do
      expect(Dir).to respond_to(:create_junction)
    end

    it 'works as expected with ASCII characters' do
      expect { Dir.create_junction(ascii_to, from) }.not_to raise_error
      expect(File).to exist(ascii_to)
      File.open(test_file, 'w') { |fh| fh.puts 'Hello World' }
      expect(Dir.entries(from)).to eq(Dir.entries(ascii_to))
    end

    it 'works as expected with unicode characters' do
      expect { Dir.create_junction(unicode_to, from) }.not_to raise_error
      expect(File).to exist(unicode_to)
      File.open(test_file, 'w') { |fh| fh.puts 'Hello World' }
      expect(Dir.entries(from)).to eq(Dir.entries(unicode_to))
    end

    it 'works as expected with Pathname objects' do
      expect { Dir.create_junction(Pathname.new(ascii_to), Pathname.new(from)) }.not_to raise_error
      expect(File).to exist(ascii_to)
      File.open(test_file, 'w') { |fh| fh.puts 'Hello World' }
      expect(Dir.entries(from)).to eq(Dir.entries(ascii_to))
    end

    it 'requires stringy arguments' do
      expect { Dir.create_junction(nil, from) }.to raise_error(TypeError)
      expect { Dir.create_junction(ascii_to, nil) }.to raise_error(TypeError)
    end
  end

  describe '.read_junction' do
    it 'works as expected with ASCII characters' do
      expect { Dir.create_junction(ascii_to, from) }.not_to raise_error
      expect(File).to exist(ascii_to)
      expect(Dir.read_junction(ascii_to)).to eq(from)
    end

    it 'works as expected with unicode characters' do
      expect { Dir.create_junction(unicode_to, from) }.not_to raise_error
      expect(File).to exist(unicode_to)
      expect(Dir.read_junction(unicode_to)).to eq(from)
    end

    it 'is joinable with unicode characters' do
      expect { Dir.create_junction(unicode_to, from) }.not_to raise_error
      expect(File).to exist(unicode_to)
      expect { File.join(Dir.read_junction(unicode_to), 'foo') }.not_to raise_error
    end

    it 'works as expected with Pathname objects' do
      expect { Dir.create_junction(Pathname.new(ascii_to), Pathname.new(from)) }.not_to raise_error
      expect(File).to exist(ascii_to)
      expect(Dir.read_junction(ascii_to)).to eq(from)
    end

    it 'requires a stringy argument' do
      expect { Dir.read_junction(nil) }.to raise_error(TypeError)
      expect { Dir.read_junction([]) }.to raise_error(TypeError)
    end
  end

  describe '.junction?' do
    it 'returns a boolean value' do
      expect(Dir).to respond_to(:junction?)
      expect { Dir.create_junction(ascii_to, from) }.not_to raise_error
      expect(Dir.junction?(from)).to be false
      expect(Dir.junction?(ascii_to)).to be true
      expect(Dir.junction?(Pathname.new(ascii_to))).to be true
    end
  end

  describe '.reparse_dir?' do
    it 'aliases junction' do
      expect(Dir).to respond_to(:reparse_dir?)
      expect(Dir.method(:reparse_dir?)).to eq(Dir.method(:junction?))
    end
  end

  describe '.empty?' do
    it 'returns expected result' do
      expect(Dir).to respond_to(:empty?)
      expect(Dir.empty?("C:\\")).to be false
      expect(Dir.empty?(from)).to be true
      expect(Dir.empty?(Pathname.new(from))).to be true
    end
  end

  describe '.pwd' do
    it 'has basic functionality' do
      expect(Dir).to respond_to(:pwd)
      expect { Dir.pwd }.not_to raise_error
      expect(Dir.pwd).to be_a_kind_of(String)
    end

    it 'aliases getwd' do
      expect(Dir.method(:pwd)).to eq(Dir.method(:getwd))
    end

    it 'returns full path even if short path was just used' do
      Dir.chdir("C:\\Progra~1")
      expect(Dir.pwd).to eq("C:\\Program Files")
    end

    it 'returns full path even if long path was just used' do
      Dir.chdir("C:\\Program Files")
      expect(Dir.pwd).to eq("C:\\Program Files")
    end

    it 'uses standard case conventions' do
      Dir.chdir("C:\\PROGRAM FILES")
      expect(Dir.pwd).to eq("C:\\Program Files")
    end

    it 'converts forward slashes to backslashes' do
      Dir.chdir("C:/Program Files")
      expect(Dir.pwd).to eq("C:\\Program Files")
    end
  end

  describe 'constants' do
    ["DESKTOP", "INTERNET", "PROGRAMS", "CONTROLS",
     "PRINTERS", "PERSONAL", "FAVORITES", "STARTUP", "RECENT", "SENDTO",
     "BITBUCKET", "STARTMENU", "MYDOCUMENTS", "MYMUSIC", "MYVIDEO",
     "DESKTOPDIRECTORY", "DRIVES", "NETWORK", "NETHOOD", "FONTS",
     "TEMPLATES", "COMMON_STARTMENU", "COMMON_PROGRAMS",
     "COMMON_STARTUP", "COMMON_FAVORITES", "COMMON_DESKTOPDIRECTORY",
     "APPDATA", "PRINTHOOD", "LOCAL_APPDATA", "ALTSTARTUP",
     "COMMON_ALTSTARTUP", "INTERNET_CACHE", "COOKIES", "HISTORY",
     "COMMON_APPDATA", "WINDOWS", "SYSTEM", "PROGRAM_FILES",
     "MYPICTURES", "PROFILE", "SYSTEMX86", "PROGRAM_FILESX86",
     "PROGRAM_FILES_COMMON", "PROGRAM_FILES_COMMONX86",
     "COMMON_TEMPLATES", "COMMON_DOCUMENTS", "CONNECTIONS",
     "COMMON_MUSIC", "COMMON_PICTURES", "COMMON_VIDEO", "RESOURCES",
     "RESOURCES_LOCALIZED", "COMMON_OEM_LINKS", "CDBURN_AREA",
     "COMMON_ADMINTOOLS", "ADMINTOOLS"].each do |constant|
      it "#{constant} is set" do
        expect(Dir.const_get(constant)).not_to be_nil
        expect(Dir.const_get(constant)).to be_a_kind_of(String)
      end
    end
  end

end
