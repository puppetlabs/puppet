require 'erb'

@build_root ||= Dir.pwd
@cow = ENV["COW"] ||= "base-squeeze-i386.cow"
@pbuild_conf = ENV["PBUILDCONF"] ||= "~/.pbuilderrc.foss"

def get_version
  `git describe`.strip
end

def get_debversion
  version = get_version
  version.include?("rc") ? version.sub(/rc[0-9]+/, '-0.1\0') : version + '-1puppetlabs1'
end

def get_rpmversion
  get_version.match(/^([0-9.]+)/)[1]
end

def get_release
  version = get_version
  if version.include?("rc")
    "0.1" + version.gsub('-', '_').match(/rc[0-9]+.*/)[0]
  else
    "1"
  end
end

def get_temp
  `mktemp -d -t tmpXXXXXX`.strip
end

def get_name
  'hiera-puppet'
end

def add_version_file(path)
  sh "echo #{get_version} > #{path}/VERSION"
end

def update_redhat_spec_file(base)
  name = get_name
  spec_date = Time.now.strftime("%a %b %d %Y")
  release = ENV['RELEASE'] ||= get_release
  version = get_version
  rpmversion = get_rpmversion
  specfile = File.join(base, 'ext', 'redhat', "#{name}.spec")
  erbfile = File.join(base, 'ext', 'redhat', "#{name}.spec.erb")
  template = IO.read(erbfile)
  message = ERB.new(template, 0, "-")
  output = message.result(binding)
  holder = `mktemp -t tmpXXXXXX`.strip!
  File.open(holder, 'w') {|f| f.write(output) }
  mv holder , specfile
  rm_f erbfile
end

def update_debian_changelog(base)
  name = get_name
  dt = Time.now.strftime("%a, %d %b %Y %H:%M:%S %z")
  version = get_debversion
  version.gsub!('v', '')
  debversion = get_debversion
  deb_changelog = File.join(base, 'ext', 'debian', 'changelog')
  erbfile = File.join(base, 'ext', 'debian', 'cl.erb')
  template = IO.read(erbfile)
  message = ERB.new(template, 0, "-")
  output = message.result(binding)
  holder = `mktemp -t tmpXXXXXX`.strip!
  sh "echo -n \"#{output}\" | cat - #{deb_changelog}  > #{holder}"
  mv holder, deb_changelog
  rm_f erbfile
end

def prep_rpm_builds
  name=get_name
  version=get_version
  temp=`mktemp -d -t tmpXXXXXX`.strip!
  raise "No /usr/bin/rpmbuild found!" unless File.exists? '/usr/bin/rpmbuild'
  dirs = [ 'BUILD', 'SPECS', 'SOURCES', 'RPMS', 'SRPMS' ]
  dirs.each do |d|
    FileUtils.mkdir_p "#{temp}//#{d}"
  end
  rpm_defines = " --define \"_specdir #{temp}/SPECS\" --define \"_rpmdir #{temp}/RPMS\" --define \"_sourcedir #{temp}/SOURCES\" --define \" _srcrpmdir #{temp}/SRPMS\" --define \"_builddir #{temp}/BUILD\"" + ' --define "_source_filedigest_algorithm 1" --define "_binary_filedigest_algorithm 1" \
         --define "_binary_payload w9.gzdio" --define "_source_payload w9.gzdio" \
         --define "_default_patch_fuzz 2"'
  sh "tar zxvf  pkg/tar/#{name}-#{version}.tar.gz  --no-anchored ext/redhat/#{name}.spec"
  mv "#{name}-#{version}/ext/redhat/#{name}.spec",  "#{temp}/SPECS"
  rm_rf "#{name}-#{version}"
  sh "cp pkg/tar/*.tar.gz #{temp}/SOURCES"
  return [ temp,  rpm_defines ]
end

namespace :package do
  desc "Create .deb from this git repository, set KEY_ID=your_key to use a specific key or UNSIGNED=1 to leave unsigned."
  task :deb => :tar  do
    name = get_name
    version = get_version
    debversion = get_debversion
    dt = Time.now.strftime("%a, %d %b %Y %H:%M:%S %z")
    temp=`mktemp -d -t tmpXXXXXX`.strip!
    base="#{temp}/#{name}-#{debversion}"
    sh "cp pkg/tar/#{name}-#{version}.tar.gz #{temp}"
    cd temp do
      sh "tar zxf *.tar.gz"
      cd "#{name}-#{version}" do
        mv File.join('ext', 'debian'), '.'
        dsc_cmd = "pdebuild --configfile #{@pbuild_conf} --pbuilder cowbuilder -- --basepath /var/cache/pbuilder/#{@cow}/"
        begin
          sh dsc_cmd
          deb_cmd = "sudo cowbuilder --build #{latest_file(File.join(temp, '*.dsc'))} --basepath /var/cache/pbuilder/#{@cow}/"
          result_dir = "/var/cache/pbuilder/result"
          dest_dir = File.join(@build_root, 'pkg', 'deb')
          mkdir_p dest_dir
          cp latest_file(File.join(result_dir, '*.deb')), dest_dir
          cp latest_file(File.join(result_dir, '*.dsc')), dest_dir
          cp latest_file(File.join(result_dir, '*.changes')), dest_dir
          cp latest_file(File.join(result_dir, '*.tar.gz')), dest_dir
          puts
          puts "** Created package: "+ latest_file(File.expand_path(File.join(@build_root, 'pkg', 'deb', '*.deb')))
        rescue
          puts <<-HERE
!! Building the .deb failed!
!! Perhaps you want to run:

    rake package:deb UNSIGNED=1

!! Or provide a specific key id, e.g.:

    rake package:deb KEY_ID=4BD6EC30
    rake package:deb KEY_ID=me@example.com

          HERE
        end
      end
    end
      rm_rf temp
  end

  desc "Create srpm from this git repository (unsigned)"
  task :srpm => :tar do
    name = get_name
    version = get_version
    temp,  rpm_defines = prep_rpm_builds
    sh "rpmbuild #{rpm_defines} -bs --nodeps #{temp}/SPECS/*.spec"
    mkdir_p "#{@build_root}/pkg/srpm"
    sh "mv -f #{temp}/SRPMS/* #{@build_root}/pkg/srpm"
    rm_rf temp
    puts
    puts "** Created package: "+ latest_file(File.expand_path(File.join(@build_root, 'pkg', 'srpm', '*.rpm')))
  end

  desc "Create .rpm from this git repository (unsigned)"
  task :rpm => :srpm do
    name = get_name
    version = get_version
    temp, rpm_defines = prep_rpm_builds
    sh "rpmbuild #{rpm_defines} -ba #{temp}/SPECS/*.spec"
    mkdir_p "#{@build_root}/pkg/srpm"
    mkdir_p "#{@build_root}/pkg/rpm"
    sh "mv -f #{temp}/SRPMS/* pkg/srpm"
    sh "mv -f #{temp}/RPMS/*/*rpm pkg/rpm"
    rm_rf temp
    puts
    puts "** Created package: "+ latest_file(File.expand_path(File.join(@build_root, 'pkg', 'rpm', '*.rpm')))
  end


  desc "Create a release .tar.gz"
  task :tar => :build_environment do
    name = get_name
    rm_rf 'pkg/tar'
    temp=`mktemp -d -t tmpXXXXXX`.strip!
    version = get_version
    base = "#{temp}/#{name}-#{version}/"
    mkdir_p base
    sh "git checkout-index -af --prefix=#{base}"
    add_version_file(base)
    update_redhat_spec_file(base)
    update_debian_changelog(base)
    mkdir_p "pkg/tar"
    sh "tar -C #{temp} -p -c -z -f #{temp}/#{name}-#{version}.tar.gz #{name}-#{version}"
    mv "#{temp}/#{name}-#{version}.tar.gz",  "#{@build_root}/pkg/tar"
    rm_rf temp
    puts
    puts "Tarball is pkg/tar/#{name}-#{version}.tar.gz"
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

  # Return the file with the latest mtime matching the String filename glob (e.g. "foo/*.bar").
  def latest_file(glob)
    require 'find'
    return FileList[glob].map{|path| [path, File.mtime(path)]}.sort_by(&:last).map(&:first).last
  end

end
