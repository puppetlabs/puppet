Puppet::Functions.create_function(:l10n) do
  dispatch :l10n_impl do
  end

  def l10n_impl
    _("IT'S HAPPY FUN TIME")
  end
end
