require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'
require 'puppet_spec/files'

describe 'the find_file function' do
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
        expect(compile_to_catalog("notify { find_file('#{one}', '#{two}'):}")).to have_resource("Notify[#{one}]")
      end
    end
  end

  it 'skips non existing files' do
    with_file_content('one') do |one|
      with_file_content('two') do |two|
        expect(compile_to_catalog("notify { find_file('#{one}/nope', '#{two}'):}")).to have_resource("Notify[#{two}]")
      end
    end
  end

  it 'accepts arguments given as an array' do
    with_file_content('one') do |one|
      with_file_content('two') do |two|
        expect(compile_to_catalog("notify { find_file(['#{one}', '#{two}']):}")).to have_resource("Notify[#{one}]")
      end
    end
  end

  it 'finds an existing file in a module' do
    with_file_content('file content') do |name|
      mod = mock 'module'
      mod.stubs(:file).with('myfile').returns(name)
      Puppet[:code] = "notify { find_file('mymod/myfile'):}"
      node = Puppet::Node.new('localhost')
      compiler = Puppet::Parser::Compiler.new(node)
      compiler.environment.stubs(:module).with('mymod').returns(mod)

      expect(compiler.compile().filter { |r| r.virtual? }).to have_resource("Notify[#{name}]")
    end
  end

  it 'returns undef when none of the paths were found' do
    mod = mock 'module'
    mod.stubs(:file).with('myfile').returns(nil)
    Puppet[:code] = "notify { String(type(find_file('mymod/myfile', 'nomod/nofile'))):}"
    node = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    # For a module that does not have the file
    compiler.environment.stubs(:module).with('mymod').returns(mod)
    # For a module that does not exist
    compiler.environment.stubs(:module).with('nomod').returns(nil)

    expect(compiler.compile().filter { |r| r.virtual? }).to have_resource("Notify[Undef]")
  end
end
