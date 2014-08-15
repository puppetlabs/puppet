require 'spec_helper'

describe Puppet::FileSystem::Uniquefile do
  it "makes the name of the file available" do
    Puppet::FileSystem::Uniquefile.open_tmp('foo') do |file|
      expect(file.path).to match(/foo/)
    end
  end

  it "provides a writeable file" do
    Puppet::FileSystem::Uniquefile.open_tmp('foo') do |file|
      file.write("stuff")
      file.flush

      expect(Puppet::FileSystem.read(file.path)).to eq("stuff")
    end
  end

  it "returns the value of the block" do
    the_value = Puppet::FileSystem::Uniquefile.open_tmp('foo') do |file|
      "my value"
    end

    expect(the_value).to eq("my value")
  end

  it "unlinks the temporary file" do
    filename = Puppet::FileSystem::Uniquefile.open_tmp('foo') do |file|
      file.path
    end

    expect(Puppet::FileSystem.exist?(filename)).to be_false
  end

  it "unlinks the temporary file even if the block raises an error" do
    filename = nil

    begin
      Puppet::FileSystem::Uniquefile.open_tmp('foo') do |file|
        filename = file.path
        raise "error!"
      end
    rescue
    end

    expect(Puppet::FileSystem.exist?(filename)).to be_false
  end
end
