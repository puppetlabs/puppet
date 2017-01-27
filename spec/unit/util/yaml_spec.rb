require 'spec_helper'

require 'puppet/util/yaml'

describe Puppet::Util::Yaml do
  include PuppetSpec::Files

  let(:filename) { tmpfile("yaml") }

  it "reads a YAML file from disk" do
    write_file(filename, YAML.dump({ "my" => "data" }))

    expect(Puppet::Util::Yaml.load_file(filename)).to eq({ "my" => "data" })
  end

  it "writes data formatted as YAML to disk" do
    Puppet::Util::Yaml.dump({ "my" => "data" }, filename)

    expect(Puppet::Util::Yaml.load_file(filename)).to eq({ "my" => "data" })
  end

  it "raises an error when the file is invalid YAML" do
    write_file(filename, "{ invalid")

    expect { Puppet::Util::Yaml.load_file(filename) }.to raise_error(Puppet::Util::Yaml::YamlLoadError)
  end

  it "raises an error when the file does not exist" do
    expect { Puppet::Util::Yaml.load_file("no") }.to raise_error(Puppet::Util::Yaml::YamlLoadError, /No such file or directory/)
  end

  it "raises an error when the filename is illegal" do
    expect { Puppet::Util::Yaml.load_file("not\0allowed") }.to raise_error(Puppet::Util::Yaml::YamlLoadError, /null byte/)
  end

  context "when the file is empty" do
    it "returns false" do
      Puppet::FileSystem.touch(filename)

      expect(Puppet::Util::Yaml.load_file(filename)).to be_falsey
    end

    it "allows return value to be overridden" do
      Puppet::FileSystem.touch(filename)

      expect(Puppet::Util::Yaml.load_file(filename, {})).to eq({})
    end
  end

  it "should allow one to strip ruby tags that would otherwise not parse" do
    write_file(filename, "---\nweirddata: !ruby/hash:Not::A::Valid::Class {}")

    expect(Puppet::Util::Yaml.load_file(filename, {}, true)).to eq({"weirddata" => {}})
  end

  it "should not strip non-ruby tags" do
    write_file(filename, "---\nweirddata: !binary |-\n          e21kNX04MTE4ZGY2NmM5MTc3OTg4ZWE4Y2JiOWEzMjMyNzFkYg==")

    expect(Puppet::Util::Yaml.load_file(filename, {}, true)).to eq({"weirddata" => "{md5}8118df66c9177988ea8cbb9a323271db"})
  end

  def write_file(name, contents)
    File.open(name, "w:UTF-8") do |fh|
      fh.write(contents)
    end
  end
end
