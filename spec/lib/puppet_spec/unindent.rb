class String
  def unindent
    gsub(/^#{scan(/^\s*/).min_by{ |l| l.length }}/, '')
  end
end
