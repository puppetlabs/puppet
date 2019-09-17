require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'
require 'puppet_spec/files'

describe 'the find_template function' do
  include PuppetSpec::Compiler
  include Matchers::Resource
  include PuppetSpec::Files

  def with_file_content(content)
    path = tmpfile('find-file-function')
    file = File.new(path, 'wb')
    file.sync = true
    file.print content
    yield path
  end

  it 'finds an existing absolute file when given arguments individually' do
    with_file_content('one') do |one|
      with_file_content('two') do |two|
        expect(compile_to_catalog("notify { find_template('#{one}', '#{two}'):}")).to have_resource("Notify[#{one}]")
      end
    end
  end

  it 'skips non existing files' do
    with_file_content('one') do |one|
      with_file_content('two') do |two|
        expect(compile_to_catalog("notify { find_template('#{one}/nope', '#{two}'):}")).to have_resource("Notify[#{two}]")
      end
    end
  end

  it 'accepts arguments given as an array' do
    with_file_content('one') do |one|
      with_file_content('two') do |two|
        expect(compile_to_catalog("notify { find_template(['#{one}', '#{two}']):}")).to have_resource("Notify[#{one}]")
      end
    end
  end

  it 'finds an existing file in a module' do
    with_file_content('file content') do |name|
      mod = double('module')
      allow(mod).to receive(:template).with('myfile').and_return(name)
      Puppet.override(code: "notify { find_template('mymod/myfile'):}") do
        node = Puppet::Node.new('localhost')
        compiler = Puppet::Parser::Compiler.new(node)
        allow(compiler.environment).to receive(:module).with('mymod').and_return(mod)

        expect(compiler.compile().filter { |r| r.virtual? }).to have_resource("Notify[#{name}]")
      end
    end
  end

  it 'returns undef when none of the paths were found' do
    mod = double('module')
    allow(mod).to receive(:template).with('myfile').and_return(nil)
    Puppet.override(code: "notify { String(type(find_template('mymod/myfile', 'nomod/nofile'))):}") do
      node = Puppet::Node.new('localhost')
      compiler = Puppet::Parser::Compiler.new(node)
      # For a module that does not have the file
      allow(compiler.environment).to receive(:module).with('mymod').and_return(mod)
      # For a module that does not exist
      allow(compiler.environment).to receive(:module).with('nomod').and_return(nil)

      expect(compiler.compile().filter { |r| r.virtual? }).to have_resource("Notify[Undef]")
    end
  end
end
