task 'cfpropertylist' do
  if defined? Pkg::Config and Pkg::Config.project_root
    cfp_version = "2.2.7"
    libdir = File.join(Pkg::Config.project_root, "lib")
    source = "https://github.com/ckruse/CFPropertyList/archive/cfpropertylist-#{cfp_version}.tar.gz"
    target_dir = Pkg::Util::File.mktemp
    target = File.join(target_dir, "cfpropertylist")
    Pkg::Util::Net.fetch_uri(source, target)
    Pkg::Util::File.untar_into(target, target_dir, "--strip-components 1")
    mv(Dir.glob("#{File.join(target_dir, "lib")}/cfpropertylist*"), libdir)
    mv(Dir.glob("#{target_dir}/{LICENSE,README,THANKS}"), File.join(libdir, "cfpropertylist"))
  else
    warn "It looks like the packaging tasks have not been loaded. You'll need to `rake package:bootstrap` before using this task"
  end
end
