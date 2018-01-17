require 'puppet'
require 'fiddle'

# Early versions of Fiddle relied on the deprecated DL module and used
# classes defined in the namespace of that module instead of classes defined
# in the Fiddle's own namespace e.g. DL::Handle instead of Fiddle::Handle.
# We don't support those.
raise LoadError, _('The loaded Fiddle version is not supported.') unless defined?(Fiddle::Handle)

# Solaris implementation of the Puppet::Util::AtFork handler.
# The callbacks defined in this implementation ensure the forked process runs
# in a different contract than the parent process. This is necessary in order
# for the child process to be able to survive termination of the contract its
# parent process runs in. This is needed notably for an agent run executed
# by a puppet agent service to be able to restart that service without being
# killed in the process as a consequence of running in the same contract as
# the service, as all processes in the contract are killed when the contract
# is terminated during the service restart.
class Puppet::Util::AtFork::Solaris
  private

  {
    'libcontract.so.1' => [
      #function name,            return value type, parameter types, ...
      [:ct_ctl_abandon,          Fiddle::TYPE_INT,  Fiddle::TYPE_INT],
      [:ct_tmpl_activate,        Fiddle::TYPE_INT,  Fiddle::TYPE_INT],
      [:ct_tmpl_clear,           Fiddle::TYPE_INT,  Fiddle::TYPE_INT],

      [:ct_tmpl_set_informative, Fiddle::TYPE_INT,  Fiddle::TYPE_INT, Fiddle::TYPE_INT],
      [:ct_tmpl_set_critical,    Fiddle::TYPE_INT,  Fiddle::TYPE_INT, Fiddle::TYPE_INT],
      [:ct_pr_tmpl_set_param,    Fiddle::TYPE_INT,  Fiddle::TYPE_INT, Fiddle::TYPE_INT],
      [:ct_pr_tmpl_set_fatal,    Fiddle::TYPE_INT,  Fiddle::TYPE_INT, Fiddle::TYPE_INT],

      [:ct_status_read,          Fiddle::TYPE_INT,  Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],

      [:ct_status_get_id,        Fiddle::TYPE_INT,  Fiddle::TYPE_VOIDP],
      [:ct_status_free,          Fiddle::TYPE_VOID, Fiddle::TYPE_VOIDP],
    ],
  }.each do |library, functions|
    libhandle = Fiddle::Handle.new(library)

    functions.each do |f|
      define_method f[0], Fiddle::Function.new(libhandle[f[0].to_s], f[2..-1], f[1]).method(:call).to_proc
    end
  end

  CTFS_PR_ROOT = File.join('', %w(system contract process))
  CTFS_PR_TEMPLATE = File.join(CTFS_PR_ROOT, %q(template))
  CTFS_PR_LATEST = File.join(CTFS_PR_ROOT, %q(latest))

  CT_PR_PGRPONLY = 0x4
  CT_PR_EV_HWERR = 0x20

  CTD_COMMON = 0

  def raise_if_error(&block)
    unless (e = yield) == 0
      e = SystemCallError.new(nil, e)
      raise e, e.message, caller
    end
  end

  def activate_new_contract_template
    begin
      tmpl = File.open(CTFS_PR_TEMPLATE, File::RDWR)

      begin
        tmpl_fd = tmpl.fileno

        raise_if_error { ct_pr_tmpl_set_param(tmpl_fd, CT_PR_PGRPONLY) }
        raise_if_error { ct_pr_tmpl_set_fatal(tmpl_fd, CT_PR_EV_HWERR) }
        raise_if_error { ct_tmpl_set_critical(tmpl_fd, 0) }
        raise_if_error { ct_tmpl_set_informative(tmpl_fd, CT_PR_EV_HWERR) }

        raise_if_error { ct_tmpl_activate(tmpl_fd) }
      rescue
        tmpl.close
        raise
      end

      @tmpl = tmpl
    rescue => detail
      Puppet.log_exception(detail, _('Failed to activate a new process contract template'))
    end
  end

  def deactivate_contract_template(parent)
    return if @tmpl.nil?

    tmpl = @tmpl
    @tmpl = nil

    begin
      raise_if_error { ct_tmpl_clear(tmpl.fileno) }
    rescue => detail
      msg = if parent
              _('Failed to deactivate process contract template in the parent process')
            else
              _('Failed to deactivate process contract template in the child process')
            end
      Puppet.log_exception(detail, msg)
      exit(1)
    ensure
      tmpl.close
    end
  end

  def get_latest_child_contract_id
    begin
      stat = File.open(CTFS_PR_LATEST, File::RDONLY)

      begin
        stathdl = Fiddle::Pointer.new(0)

        raise_if_error { ct_status_read(stat.fileno, CTD_COMMON, stathdl.ref) }
        ctid = ct_status_get_id(stathdl)
        ct_status_free(stathdl)
      ensure
        stat.close
      end

      ctid
    rescue => detail
      Puppet.log_exception(detail, _('Failed to get latest child process contract id'))
      nil
    end
  end

  def abandon_latest_child_contract
    ctid = get_latest_child_contract_id
    return if ctid.nil?

    begin
      ctl = File.open(File.join(CTFS_PR_ROOT, ctid.to_s, %q(ctl)), File::WRONLY)

      begin
        raise_if_error { ct_ctl_abandon(ctl.fileno) }
      ensure
        ctl.close
      end
    rescue => detail
      Puppet.log_exception(detail, _('Failed to abandon a child process contract'))
    end
  end

  public

  def prepare
    activate_new_contract_template
  end

  def parent
    deactivate_contract_template(true)
    abandon_latest_child_contract
  end

  def child
    deactivate_contract_template(false)
  end
end
