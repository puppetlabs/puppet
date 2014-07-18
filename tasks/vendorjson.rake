task 'vendorjson' do
  if defined? Pkg::Config and Pkg::Config.project_root
    json_version = "1.8.1"
    libdir = File.join(Pkg::Config.project_root, "lib")
    source = "https://github.com/flori/json/archive/v#{json_version}.tar.gz"
    target_dir = Pkg::Util::File.mktemp
    target = File.join(target_dir, "json")
    Pkg::Util::Net.fetch_uri(source, target)
    Pkg::Util::File.untar_into(target, target_dir, "--strip-components 1")
    unless Dir.glob("#{File.join(target_dir, "lib", "json*")}").empty?
      rm_rf(Dir.glob("#{File.join(target_dir, "lib", "json*")}"))
    end
    mv(Dir.glob("#{File.join(target_dir, "lib")}/json*"), libdir)
    mv(Dir.glob("#{target_dir}/{COPYING,GPL,VERSION}"), File.join(libdir, "json"))
  else
    warn "It looks like the packaging tasks have not been loaded. You'll need to `rake package:bootstrap` before using this task"
  end
end
