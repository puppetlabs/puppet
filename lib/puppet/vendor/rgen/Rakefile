require 'rubygems/package_task'
require 'rdoc/task'

RGenGemSpec = Gem::Specification.new do |s|
  s.name = %q{rgen}
  s.version = "0.7.0"
  s.date = Time.now.strftime("%Y-%m-%d")
  s.summary = %q{Ruby Modelling and Generator Framework}
  s.email = %q{martin dot thiede at gmx de}
  s.homepage = %q{http://ruby-gen.org}
  s.rubyforge_project = %q{rgen}
  s.description = %q{RGen is a framework for Model Driven Software Development (MDSD) in Ruby. This means that it helps you build Metamodels, instantiate Models, modify and transform Models and finally generate arbitrary textual content from it.}
  s.authors = ["Martin Thiede"]
  gemfiles = Rake::FileList.new
  gemfiles.include("{lib,test}/**/*")
  gemfiles.include("README.rdoc", "CHANGELOG", "MIT-LICENSE", "Rakefile") 
  gemfiles.exclude(/\b\.bak\b/)
  s.files = gemfiles
  s.rdoc_options = ["--main", "README.rdoc", "-x", "test", "-x", "metamodels", "-x", "ea_support/uml13*"]
  s.extra_rdoc_files = ["README.rdoc", "CHANGELOG", "MIT-LICENSE"]
end

RDoc::Task.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files.include("README.rdoc", "CHANGELOG", "MIT-LICENSE", "lib/**/*.rb")
  rd.rdoc_files.exclude("lib/metamodels/*")
  rd.rdoc_files.exclude("lib/ea_support/uml13*")
  rd.rdoc_dir = "doc"
end

RGenPackageTask = Gem::PackageTask.new(RGenGemSpec) do |p|
  p.need_zip = false
end	

task :prepare_package_rdoc => :rdoc do
  RGenPackageTask.package_files.include("doc/**/*")
end

task :release => [:prepare_package_rdoc, :package]

task :clobber => [:clobber_rdoc, :clobber_package]
