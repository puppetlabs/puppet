require 'erb'

def get_version
  if File.exists?('.git')
    %x{git describe}.chomp.gsub('-', '.').split('.')[0..3].join('.').gsub('v', '')
  else
    %x{pwd}.strip!.split('.')[-1]
  end
end

def get_debversion
  @version.include?("rc") ? @version.sub(/rc[0-9]+/, '-0.1\0') : @version + '-1puppetlabs1'
end

def get_origversion
  @debversion.split('-')[0]
end

def get_rpmversion
  @version.match(/^([0-9.]+)/)[1]
end

def get_release
  ENV['RELEASE'] ||
    if @version.include?("rc")
      "0.1" + @version.gsub('-', '_').match(/rc[0-9]+.*/)[0]
    else
      "1"
    end
end

def get_cow
  ENV["COW"] || "base-squeeze-i386.cow"
end

def get_pbuild_conf
  ENV["PBUILDCONF"] || "~/.pbuilderrc.foss"
end

def get_temp
  `mktemp -d -t tmpXXXXXX`.strip
end

@name         = 'hiera-puppet'
@build_root   ||= Dir.pwd
@cow          ||= get_cow
@pbuild_conf  ||= get_pbuild_conf
@version      ||= get_version
@debversion   ||= get_debversion
@origversion  ||= get_origversion
@rpmversion   ||= get_rpmversion
@release      ||= get_release

def erb(erbfile,  outfile)
  template = File.read(erbfile)
  message = ERB.new(template, nil, "-")
  output = message.result(binding)
  File.open(outfile, 'w') { |f| f.write output }
  puts "Generated: #{outfile}"
end

def cp_pr(src, dest, options={})
  mandatory = {:preserve => true}
  cp_r(src, dest, options.merge(mandatory))
end

def cp_p(src, dest, options={})
  mandatory = {:preserve => true}
  cp(src, dest, options.merge(mandatory))
end

def mv_f(src, dest, options={})
  force = {:force => true}
  mv(src, dest, options.merge(mandatory))
end

def build_rpm(buildarg = "-bs")
  %x{which rpmbuild}
  unless $?.success?
    STDERR.puts "rpmbuild command not found...exiting"
    exit 1
  end
  temp = get_temp
  rpm_define = "--define \"%dist .el5\" --define \"%_topdir  #{temp}\" "
  rpm_old_version = '--define "_source_filedigest_algorithm 1" --define "_binary_filedigest_algorithm 1" \
     --define "_binary_payload w9.gzdio" --define "_source_payload w9.gzdio" \
     --define "_default_patch_fuzz 2"'
  args = rpm_define + ' ' + rpm_old_version
  mkdir_p temp
  mkdir_p 'pkg/rpm'
  mkdir_p "#{temp}/SOURCES"
  mkdir_p "#{temp}/SPECS"
  cp_p "pkg/#{@name}-#{@version}.tar.gz", "#{temp}/SOURCES"
  erb "ext/redhat/#{@name}.spec.erb", "#{temp}/SPECS/#{@name}.spec"
  sh "rpmbuild #{args} #{buildarg} --nodeps #{temp}/SPECS/#{@name}.spec"
  output = `find #{temp} -name *.rpm`
  mv FileList["#{temp}/SRPMS/*.rpm", "#{temp}/RPMS/*/*.rpm"], "pkg/rpm"
  rm_rf temp
  puts
  puts "Wrote:"
  output.each_line do | line |
    puts "#{`pwd`.strip}/pkg/rpm/#{line.split('/')[-1]}"
  end
end

desc "Build various packages"
namespace :package do
  desc "Create .deb from this git repository."
  task :deb => :tar  do
    temp = get_temp
    cp_p "pkg/#{@name}-#{@version}.tar.gz", "#{temp}"
    cd temp do
      sh "tar zxf #{@name}-#{@version}.tar.gz"
      mv "#{@name}-#{@version}", "#{@name}-#{@debversion}"
      mv "#{@name}-#{@version}.tar.gz", "#{@name}_#{@origversion}.orig.tar.gz"
      cd "#{@name}-#{@debversion}" do
        mv File.join('ext', 'debian'), '.'
        build_cmd = "pdebuild --configfile #{@pbuild_conf} --buildresult #{temp} --pbuilder cowbuilder -- --basepath /var/cache/pbuilder/#{@cow}/"
        begin
          sh build_cmd
          dest_dir = File.join(@build_root, 'pkg', 'deb')
          mkdir_p dest_dir
          cp FileList["#{temp}/*.deb", "#{temp}/*.dsc", "#{temp}/*.changes", "#{temp}/*.debian.tar.gz", "#{temp}/*.orig.tar.gz"], dest_dir
          output = `find #{dest_dir}`
          puts
          puts "Wrote:"
          output.each_line do | line |
            puts "#{`pwd`.strip}/pkg/deb/#{line.split('/')[-1]}"
          end
        rescue
          STDERR.puts "Something went wrong. Hopefully the backscroll or #{temp}/#{@name}_#{@debversion}.build file has a clue."
        end
      end
      rm_rf temp
    end
  end

  desc "Create srpm from this git repository (unsigned)"
  task :srpm => :tar do
    build_rpm("-bs")
  end

  desc "Create .rpm from this git repository (unsigned)"
  task :rpm => :tar do
    build_rpm("-ba")
  end

  desc "Create a source tar archive"
  task :tar => [ :clean, :build_environment ] do
    workdir = "pkg/#{@name}-#{@version}"
    mkdir_p workdir
    FileList[ "ext", "CHANGELOG", "COPYING", "README.md", "*.md", "lib", "bin", "spec", "Rakefile" ].each do |f|
      cp_pr f, workdir
    end
    erb "#{workdir}/ext/redhat/#{@name}.spec.erb", "#{workdir}/ext/redhat/#{@name}.spec"
    erb "#{workdir}/ext/debian/changelog.erb", "#{workdir}/ext/debian/changelog"
    rm_rf FileList["#{workdir}/ext/debian/*.erb", "#{workdir}/ext/redhat/*.erb"]
    cd "pkg" do
      sh "tar --exclude=.gitignore -zcf #{@name}-#{@version}.tar.gz #{@name}-#{@version}"
    end
    rm_rf workdir
    puts
    puts "Wrote #{`pwd`.strip}/pkg/#{@name}-#{@version}"
  end

  task :build_environment do
    unless ENV['FORCE'] == '1'
      modified = `git status --porcelain | sed -e '/^\?/d'`
      if modified.split(/\n/).length != 0
        puts <<-HERE
!! ERROR: Your git working directory is not clean. You must
!! remove or commit your changes before you can create a package:

#{`git status | grep '^#'`.chomp}

!! To override this check, set FORCE=1 -- e.g. `rake package:deb FORCE=1`
        HERE
        raise
      end
    end
  end
end
