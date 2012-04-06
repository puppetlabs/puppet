require 'rubygems'

require 'rubygems/package_task'
require 'rdoc/task'
require 'rake/testtask'

spec = Gem::Specification.new do |s|
  s.name = "CFPropertyList"
  s.version = "2.1"
  s.author = "Christian Kruse"
  s.email = "cjk@wwwtech.de"
  s.homepage = "http://github.com/ckruse/CFPropertyList"
  s.platform = Gem::Platform::RUBY
  s.summary = "Read, write and manipulate both binary and XML property lists as defined by apple"
  s.description = "This is a module to read, write and manipulate both binary and XML property lists as defined by apple."
  s.files = FileList["lib/*"].to_a
  s.require_path = "lib"
  #s.autorequire = "name"
  #s.test_files = FileList["{test}/**/*test.rb"].to_a
  s.has_rdoc = true
  s.extra_rdoc_files = ["README"]
  s.add_development_dependency("rake",">=0.7.0")
end

desc 'Generate RDoc documentation for the CFPropertyList module.'
Rake::RDocTask.new do |rdoc|
  files = ['README', 'LICENSE', 'lib/*.rb']
  rdoc.rdoc_files.add(files)
  rdoc.main = 'README'
  rdoc.title = 'CFPropertyList RDoc'
  rdoc.rdoc_dir = 'doc'
  rdoc.options << '--line-numbers' << '--inline-source' << '-c utf8'
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end

Rake::TestTask.new do |test|
  test.libs << 'test'
  test.test_files = Dir.glob('test/test*.rb')
end

# eof
