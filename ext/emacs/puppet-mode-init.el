;;
;; Setup puppet-mode for autoloading
;;
(autoload 'puppet-mode "puppet-mode" "Major mode for editing puppet manifests")

(add-to-list 'auto-mode-alist '("\\.pp\\'" . puppet-mode))
