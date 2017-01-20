# These tasks wrap tasks from the gettext-setup gem, used when generating
# translation files. If you want to use a new task in the gettext-setup
# gem, add a wrapper for it here to expose it in the Puppet repo.
namespace :gettext do
  task :load_gettext_tasks do
    spec = Gem::Specification.find_by_name 'gettext-setup'
    load "#{spec.gem_dir}/lib/tasks/gettext.rake"
    GettextSetup.initialize(File.absolute_path('../locales', File.dirname(__FILE__)))
  end

  desc "Generate a new POT file"
  task :generate_pot => :load_gettext_tasks do
    Rake::Task["gettext:pot"].invoke
  end

  desc "Generate a PO file for the given locale"
  task :generate_po, [:language] => :load_gettext_tasks do |t, args|
    Rake::Task["gettext:po"].invoke(args[:language])
  end

  desc "Update POT file if strings have changed"
  task :update_pot => :load_gettext_tasks do
    Rake::Task["gettext:update_pot"].invoke
  end
end
