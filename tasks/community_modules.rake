task 'community_modules' do
  if defined? Pkg::Config and Pkg::Config.project_root
    puppetfile = File.join(Pkg::Config.project_root, "ext", "Puppetfile")
    FileUtils.cp puppetfile, Pkg::Config.project_root
    system "gem install r10k"
    system "r10k puppetfile install"
    FileUtils.rm File.join(Pkg::Config.project_root, "Puppetfile")
  else
    warn "It looks like the packaging tasks have not been loaded. You'll need to `rake package:bootstrap` before using this task"
  end
end
