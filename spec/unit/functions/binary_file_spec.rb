require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'
require 'puppet_spec/files'

describe 'the binary_file function' do
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

  it 'reads an existing absolute file' do
    with_file_content('one') do |one|
      # Note that Binary to String produced Base64 encoded version of 'one' which is 'b23l'
      expect(compile_to_catalog("notify { String(binary_file('#{one}')):}")).to have_resource("Notify[b25l]")
    end
  end

  it 'errors on non existing files' do
    expect do
      with_file_content('one') do |one|
        compile_to_catalog("notify { binary_file('#{one}/nope'):}")
      end
    end.to raise_error(/The given file '.+\/nope' does not exist/)
  end

  it 'reads an existing file in a module' do
    with_file_content('binary_data') do |name|
      mod = mock 'module'
      mod.stubs(:file).with('myfile').returns(name)
      Puppet[:code] = "notify { String(binary_file('mymod/myfile')):}"
      node = Puppet::Node.new('localhost')
      compiler = Puppet::Parser::Compiler.new(node)
      compiler.environment.stubs(:module).with('mymod').returns(mod)
      # Note that the Binary to string produces Base64 encoded version of 'binary_data' which is 'YmluYXJ5X2RhdGE='
      expect(compiler.compile().filter { |r| r.virtual? }).to have_resource("Notify[YmluYXJ5X2RhdGE=]")
    end
  end
end
