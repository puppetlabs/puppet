require 'puppet/transaction/report'
require 'puppet/indirector/yaml'

class Puppet::Transaction::Report::Yaml < Puppet::Indirector::Yaml
  desc "Store last report as a flat file, serialized using YAML."

  # Force report to be saved there
  def path(name,ext='.yaml')
    Puppet[:lastrunreport].split(File::PATH_SEPARATOR).first
  end

  def save(request)
    # Have the superclass save it
    super

    # Make copies in other locations, if needed
    path, *copies = Puppet[:lastrunreport].split(File::PATH_SEPARATOR)
    copies.each do |target|
      copy_report(path, target)
    end
  end

  private

  def copy_report(src, dest)
    basedir = File.dirname(dest)

    Puppet::FileSystem.dir_mkpath(basedir) unless Puppet::FileSystem.dir_exist?(basedir)

    FileUtils.copy_file(src, dest)
  end

end
