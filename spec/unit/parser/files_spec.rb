#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/parser/files'

describe Puppet::Parser::Files do
  include PuppetSpec::Files

  let(:modulepath) { tmpdir("modulepath") }
  let(:environment) { Puppet::Node::Environment.create(:testing, [modulepath]) }
  let(:mymod) { File.join(modulepath, "mymod") }
  let(:mymod_files) { File.join(mymod, "files") }
  let(:mymod_a_file) { File.join(mymod_files, "some.txt") }
  let(:mymod_templates) { File.join(mymod, "templates") }
  let(:mymod_a_template) { File.join(mymod_templates, "some.erb") }
  let(:mymod_manifests) { File.join(mymod, "manifests") }
  let(:mymod_init_manifest) { File.join(mymod_manifests, "init.pp") }
  let(:mymod_another_manifest) { File.join(mymod_manifests, "another.pp") }
  let(:an_absolute_file_path_outside_of_module) { make_absolute("afilenamesomewhere") }

  before do
    FileUtils.mkdir_p(mymod_files)
    File.open(mymod_a_file, 'w') do |f|
      f.puts('something')
    end
    FileUtils.mkdir_p(mymod_templates)
    File.open(mymod_a_template, 'w') do |f|
      f.puts('<%= "something" %>')
    end
    FileUtils.mkdir_p(mymod_manifests)
    File.open(mymod_init_manifest, 'w') do |f|
      f.puts('class mymod { }')
    end
    File.open(mymod_another_manifest, 'w') do |f|
      f.puts('class mymod::another { }')
    end
  end

  describe "when searching for files" do
    it "returns fully-qualified file names directly" do
      expect(Puppet::Parser::Files.find_file(an_absolute_file_path_outside_of_module, environment)).to eq(an_absolute_file_path_outside_of_module)
    end

    it "returns the full path to the file if given a modulename/relative_filepath selector " do
      expect(Puppet::Parser::Files.find_file("mymod/some.txt", environment)).to eq(mymod_a_file)
    end

    it "returns nil if the module is not found" do
      expect(Puppet::Parser::Files.find_file("mod_does_not_exist/myfile", environment)).to be_nil
    end

    it "also returns nil if the module is found, but the file is not" do
      expect(Puppet::Parser::Files.find_file("mymod/file_does_not_exist", environment)).to be_nil
    end
  end

  describe "when searching for templates" do
    it "returns fully-qualified templates directly" do
      expect(Puppet::Parser::Files.find_template(an_absolute_file_path_outside_of_module, environment)).to eq(an_absolute_file_path_outside_of_module)
    end

    it "returns the full path to the template if given a modulename/relative_templatepath selector" do
      expect(Puppet::Parser::Files.find_template("mymod/some.erb", environment)).to eq(mymod_a_template)
    end

    it "returns nil if the module is not found" do
      expect(Puppet::Parser::Files.find_template("module_does_not_exist/mytemplate", environment)).to be_nil
    end

    it "returns nil if the module is found, but the template is not " do
      expect(Puppet::Parser::Files.find_template("mymod/template_does_not_exist", environment)).to be_nil
    end
  end

  describe "when searching for manifests in a module" do
    let(:no_manifests_found) { [nil, []] }

    it "ignores invalid module names" do
      expect(Puppet::Parser::Files.find_manifests_in_modules("mod.has.invalid.name/init.pp", environment)).to eq(no_manifests_found)
    end

    it "returns no files when no module is found" do
      expect(Puppet::Parser::Files.find_manifests_in_modules("not_here_module/init.pp", environment)).to eq(no_manifests_found)
    end

    it "returns the name of the module and the manifests from the first found module" do
      expect(Puppet::Parser::Files.find_manifests_in_modules("mymod/init.pp", environment)
            ).to eq(["mymod", [mymod_init_manifest]])
    end

    it "always includes init.pp if present" do
      expect(Puppet::Parser::Files.find_manifests_in_modules("mymod/another.pp", environment)
            ).to eq(["mymod", [mymod_init_manifest, mymod_another_manifest]])
    end

    it "does not find the module when it is a different environment" do
      different_env = Puppet::Node::Environment.create(:different, [])

      expect(Puppet::Parser::Files.find_manifests_in_modules("mymod/init.pp", different_env)).to eq(no_manifests_found)
    end
  end
end
