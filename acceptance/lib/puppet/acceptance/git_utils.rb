module Puppet
  module Acceptance
    module GitUtils
      def lookup_in_env(env_variable_name, project_name, default)
        project_specific_name = "#{project_name.upcase.gsub("-","_")}_#{env_variable_name}"
        ENV[project_specific_name] || ENV[env_variable_name] || default
      end

      def build_giturl(project_name, git_fork = nil, git_server = nil)
        git_fork ||= lookup_in_env('FORK', project_name, 'puppetlabs')
        git_server ||= lookup_in_env('GIT_SERVER', project_name, 'github.com')
        repo = (git_server == 'github.com') ?
          "#{git_fork}/#{project_name}.git" :
          "#{git_fork}-#{project_name}.git"
        "git://#{git_server}/#{repo}"
      end
    end
  end
end
