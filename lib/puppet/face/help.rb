# frozen_string_literal: true

require_relative '../../puppet/face'
require_relative '../../puppet/application/face_base'
require_relative '../../puppet/util/constant_inflector'
require 'pathname'
require 'erb'

Puppet::Face.define(:help, '0.0.1') do
  copyright "Puppet Inc.", 2011
  license   _("Apache 2 license; see COPYING")

  summary _("Display Puppet help.")

  action(:help) do
    summary _("Display help about Puppet subcommands and their actions.")
    arguments _("[<subcommand>] [<action>]")
    returns _("Short help text for the specified subcommand or action.")
    examples _(<<-'EOT')
      Get help for an action:

      $ puppet help
    EOT

    option "--version " + _("VERSION") do
      summary _("The version of the subcommand for which to show help.")
    end

    option "--ronn" do
      summary _("Whether to render the help text in ronn format.")
      default_to { false }
    end

    default
    when_invoked do |*args|
      options = args.pop

      unless options[:ronn]
        if default_case?(args) || help_for_help?(args)
          return erb('global.erb').result(binding)
        end
      end

      if args.length > 2
        # TRANSLATORS 'puppet help' is a command line and should not be translated
        raise ArgumentError, _("The 'puppet help' command takes two (optional) arguments: a subcommand and an action")
      end

      version = :current
      if options.has_key? :version
        if options[:version].to_s !~ /^current$/i
          version = options[:version]
        elsif args.length == 0
          raise ArgumentError, _("Supplying a '--version' only makes sense when a Faces subcommand is given")
          # TRANSLATORS '--version' is a command line option and should not be translated
        end
      end

      facename, actionname = args
      if legacy_applications.include? facename
        if actionname
          raise ArgumentError, _("The legacy subcommand '%{sub_command}' does not support supplying an action") % { sub_command: facename }
        end

        # legacy apps already emit ronn output
        return render_application_help(facename)
      elsif options[:ronn]
        render_face_man(facename || :help)
      # Calling `puppet help <app> --ronn` normally calls this action with
      # <app> as the first argument in the `args` array. However, if <app>
      # happens to match the name of an action, like `puppet help help
      # --ronn`, then face_base "eats" the argument and `args` will be
      # empty. Rather than force users to type `puppet help help help
      # --ronn`, default the facename to `:help`
      else
        render_face_help(facename, actionname, version)
      end
    end
  end

  def default_case?(args)
    args.empty?
  end

  def help_for_help?(args)
    args.length == 1 && args.first == 'help'
  end

  def render_face_man(facename)
    # set 'face' as it's used in the erb processing.
    face = Puppet::Face[facename.to_sym, :current]
    # avoid unused variable warning
    _face = face
    erb('man.erb').result(binding)
  end

  def render_application_help(applicationname)
    return Puppet::Application[applicationname].help
  rescue StandardError, LoadError => detail
    message = []
    message << _('Could not load help for the application %{application_name}.') % { application_name: applicationname }
    message << _('Please check the error logs for more information.')
    message << ''
    message << _('Detail: "%{detail}"') % { detail: detail.message }
    fail ArgumentError, message.join("\n"), detail.backtrace
  end

  def render_face_help(facename, actionname, version)
    face, action = load_face_help(facename, actionname, version)
    return template_for(face, action).result(binding)
  rescue StandardError, LoadError => detail
    message = []
    message << _('Could not load help for the face %{face_name}.') % { face_name: facename }
    message << _('Please check the error logs for more information.')
    message << ''
    message << _('Detail: "%{detail}"') % { detail: detail.message }
    fail ArgumentError, message.join("\n"), detail.backtrace
  end

  def load_face_help(facename, actionname, version)
    face = Puppet::Face[facename.to_sym, version]
    if actionname
      action = face.get_action(actionname.to_sym)
      unless action
        fail ArgumentError, _("Unable to load action %{actionname} from %{face}") % { actionname: actionname, face: face }
      end
    end

    [face, action]
  end

  def template_for(face, action)
    if action.nil?
      erb('face.erb')
    else
      erb('action.erb')
    end
  end

  def erb(name)
    template = (Pathname(__FILE__).dirname + "help" + name)
    erb = Puppet::Util.create_erb(template.read)
    erb.filename = template.to_s
    return erb
  end

  # Return a list of applications that are not simply just stubs for Faces.
  def legacy_applications
    Puppet::Application.available_application_names.reject do |appname|
      (is_face_app?(appname)) or (exclude_from_docs?(appname))
    end.sort
  end

  # Return a list of all applications (both legacy and Face applications), along with a summary
  #  of their functionality.
  # @return [Array] An Array of Arrays.  The outer array contains one entry per application; each
  #  element in the outer array is a pair whose first element is a String containing the application
  #  name, and whose second element is a String containing the summary for that application.
  def all_application_summaries
    available_application_names_special_sort().inject([]) do |result, appname|
      next result if exclude_from_docs?(appname)

      if appname == COMMON || appname == SPECIALIZED || appname == BLANK
        result << appname
      elsif is_face_app?(appname)
        begin
          face = Puppet::Face[appname, :current]
          # Add deprecation message to summary if the face is deprecated
          summary = face.deprecated? ? face.summary + ' ' + _("(Deprecated)") : face.summary
          result << [appname, summary, '  ']
        rescue StandardError, LoadError
          error_message = _("!%{sub_command}! Subcommand unavailable due to error.") % { sub_command: appname }
          error_message += ' ' + _("Check error logs.")
          result << [error_message, '', '  ']
        end
      else
        begin
          summary = Puppet::Application[appname].summary
          if summary.empty?
            summary = horribly_extract_summary_from(appname)
          end
          result << [appname, summary, '  ']
        rescue StandardError, LoadError
          error_message = _("!%{sub_command}! Subcommand unavailable due to error.") % { sub_command: appname }
          error_message += ' ' + _("Check error logs.")
          result << [error_message, '', '  ']
        end
      end
    end
  end

  COMMON = 'Common:'
  SPECIALIZED = 'Specialized:'
  BLANK = "\n"
  def available_application_names_special_sort
    full_list = Puppet::Application.available_application_names
    a_list = full_list & %w{apply agent config help lookup module resource}
    a_list = a_list.sort
    also_ran = full_list - a_list
    also_ran = also_ran.sort
    [[COMMON], a_list, [BLANK], [SPECIALIZED], also_ran].flatten(1)
  end

  def horribly_extract_summary_from(appname)
    help = Puppet::Application[appname].help.split("\n")
    # Now we find the line with our summary, extract it, and return it.  This
    # depends on the implementation coincidence of how our pages are
    # formatted.  If we can't match the pattern we expect we return the empty
    # string to ensure we don't blow up in the summary. --daniel 2011-04-11
    while line = help.shift do # rubocop:disable Lint/AssignmentInCondition
      md = /^puppet-#{appname}\([^\)]+\) -- (.*)$/.match(line)
      if md
        return md[1]
      end
    end
    return ''
  end
  # This should absolutely be a private method, but for some reason it appears
  #  that you can't use the 'private' keyword inside of a Face definition.
  #  See #14205.
  # private :horribly_extract_summary_from

  def exclude_from_docs?(appname)
    %w{face_base indirection_base report status}.include? appname
  end
  # This should absolutely be a private method, but for some reason it appears
  #  that you can't use the 'private' keyword inside of a Face definition.
  #  See #14205.
  # private :exclude_from_docs?

  def is_face_app?(appname)
    clazz = Puppet::Application.find(appname)

    clazz.ancestors.include?(Puppet::Application::FaceBase)
  end
  # This should probably be a private method, but for some reason it appears
  #  that you can't use the 'private' keyword inside of a Face definition.
  #  See #14205.
  # private :is_face_app?
end
