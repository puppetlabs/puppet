# RGen Framework
# (c) Martin Thiede, 2006

module RGen

module TemplateLanguage

module TemplateHelper

	private

	def _splitArgsAndOptions(all)
		if all[-1] and all[-1].is_a? Hash
			args = all[0..-2] || []
			options = all[-1]
		else
			args = all
			options = {}
		end
		return args, options
	end
end

end

end