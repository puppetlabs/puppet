;;;
;;; puppet-mode.el
;;; 
;;; Author: lutter
;;; Description: A simple mode for editing puppet manifests
;;;

(defconst puppet-mode-version "0.0.1")

(defvar puppet-mode-abbrev-table nil
  "Abbrev table in use in puppet-mode buffers.")

(define-abbrev-table 'puppet-mode-abbrev-table ())

(defvar puppet-mode-map nil "Keymap used in puppet mode.")

(if puppet-mode-map
    nil
   (setq puppet-mode-map (make-sparse-keymap))
;;   (define-key puppet-mode-map "{" 'puppet-electric-brace)
;;   (define-key puppet-mode-map "}" 'puppet-electric-brace)
;;   (define-key puppet-mode-map "\e\C-a" 'puppet-beginning-of-defun)
;;   (define-key puppet-mode-map "\e\C-e" 'puppet-end-of-defun)
;;   (define-key puppet-mode-map "\e\C-b" 'puppet-backward-sexp)
;;   (define-key puppet-mode-map "\e\C-f" 'puppet-forward-sexp)
;;   (define-key puppet-mode-map "\e\C-p" 'puppet-beginning-of-block)
;;   (define-key puppet-mode-map "\e\C-n" 'puppet-end-of-block)
;;   (define-key puppet-mode-map "\e\C-h" 'puppet-mark-defun)
;;   (define-key puppet-mode-map "\e\C-q" 'puppet-indent-exp)
;;   (define-key puppet-mode-map "\t" 'puppet-indent-command)
;;   (define-key puppet-mode-map "\C-c\C-e" 'puppet-insert-end)
;;   (define-key puppet-mode-map "\C-j" 'puppet-reindent-then-newline-and-indent)
  (define-key puppet-mode-map "\C-m" 'newline))

(defvar puppet-mode-syntax-table nil
  "Syntax table in use in puppet-mode buffers.")

(if puppet-mode-syntax-table
    ()
  (setq puppet-mode-syntax-table (make-syntax-table))
  (modify-syntax-entry ?\' "\"" puppet-mode-syntax-table)
  (modify-syntax-entry ?\" "\"" puppet-mode-syntax-table)
  (modify-syntax-entry ?# "<" puppet-mode-syntax-table)
  (modify-syntax-entry ?\n ">" puppet-mode-syntax-table)
  (modify-syntax-entry ?\\ "\\" puppet-mode-syntax-table)
  (modify-syntax-entry ?$ "." puppet-mode-syntax-table)
  (modify-syntax-entry ?- "_" puppet-mode-syntax-table)
  (modify-syntax-entry ?> "." puppet-mode-syntax-table)
  (modify-syntax-entry ?= "." puppet-mode-syntax-table)
  (modify-syntax-entry ?\; "." puppet-mode-syntax-table)
  (modify-syntax-entry ?\( "()" puppet-mode-syntax-table)
  (modify-syntax-entry ?\) ")(" puppet-mode-syntax-table)
  (modify-syntax-entry ?\{ "(}" puppet-mode-syntax-table)
  (modify-syntax-entry ?\} "){" puppet-mode-syntax-table)
  (modify-syntax-entry ?\[ "(]" puppet-mode-syntax-table)
  (modify-syntax-entry ?\] ")[" puppet-mode-syntax-table)
  )

(defcustom puppet-indent-tabs-mode nil
  "*Indentation can insert tabs in puppet mode if this is non-nil."
  :type 'boolean :group 'puppet)

(defcustom puppet-comment-column 32
  "*Indentation column of comments."
  :type 'integer :group 'puppet)

(defun puppet-mode-variables ()
  (set-syntax-table puppet-mode-syntax-table)
  (setq local-abbrev-table puppet-mode-abbrev-table)
  ;(make-local-variable 'indent-line-function)
  ;(setq indent-line-function 'ruby-indent-line)
  (make-local-variable 'require-final-newline)
  (setq require-final-newline t)
  (make-variable-buffer-local 'comment-start)
  (setq comment-start "# ")
  (make-variable-buffer-local 'comment-end)
  (setq comment-end "")
  (make-variable-buffer-local 'comment-column)
  (setq comment-column puppet-comment-column)
  (make-variable-buffer-local 'comment-start-skip)
  (setq comment-start-skip "#+ *")
  (setq indent-tabs-mode puppet-indent-tabs-mode)
  (make-local-variable 'parse-sexp-ignore-comments)
  (setq parse-sexp-ignore-comments t)
  (make-local-variable 'paragraph-start)
  (setq paragraph-start (concat "$\\|" page-delimiter))
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)
  (make-local-variable 'paragraph-ignore-fill-prefix)
  (setq paragraph-ignore-fill-prefix t))

(defun puppet-comment-line-p ()
  "Return non-nil iff this line is a comment."
  (save-excursion
    (beginning-of-line)
    (looking-at (format "\\s-*%s" comment-start))))

(defun puppet-in-array ()
  "If point is in an array, return the position of the opening '[' of
that array, else return nil."
  (save-excursion
    (save-match-data
      (let ((opoint (point))
            (apoint (search-backward "[" nil t)))
        (when apoint
          ;; An array opens before point.  If it doesn't close before
          ;; point, then point must be in it.
          ;; ### TODO: of course, the '[' could be in a string literal,
          ;; ### in which case this whole idea is bogus.  But baby
          ;; ### steps, baby steps.  A more robust strategy might be
          ;; ### to walk backwards by sexps, until hit a wall, then
          ;; ### inspect the nature of that wall.
          (if (= (count-matches "\\]" apoint opoint) 0)
              apoint))))))

(defun puppet-indent-line ()
  "Indent current line as puppet code."
  (interactive)
  (beginning-of-line)
  (if (bobp)
      (indent-line-to 0)                ; First line is always non-indented
    (let ((not-indented t)
          (array-start (puppet-in-array))
          cur-indent)
      (cond
       (array-start
        ;; This line probably starts with an element from an array.
        ;; Indent the line to the same indentation as the first
        ;; element in that array.  That is, this...
        ;;
        ;;    exec {     
        ;;      "add_puppetmaster_mongrel_startup_links":
        ;;      command => "string1",
        ;;      creates => [ "string2", "string3", 
        ;;      "string4", "string5", 
        ;;      "string6", "string7",
        ;;      "string3" ],
        ;;      refreshonly => true,
        ;;    }
        ;; 
        ;; ...should instead look like this:
        ;;
        ;;    exec {     
        ;;      "add_puppetmaster_mongrel_startup_links":
        ;;      command => "string1",
        ;;      creates => [ "string2", "string3", 
        ;;                   "string4", "string5", 
        ;;                   "string6", "string7",
        ;;                   "string8" ],
        ;;      refreshonly => true,
        ;;    }
        (save-excursion
          (goto-char array-start)
          (forward-char 1)
          (re-search-forward "\\S-")
          (forward-char -1)
          (setq cur-indent (current-column))))
       ((looking-at "^[^{\n]*}")
        ;; This line contains the end of a block, but the block does
        ;; not also begin on this line, so decrease the indentation.
        (save-excursion
          (forward-line -1)
          (if (looking-at "^.*}")
              (progn
                (setq cur-indent (- (current-indentation) 2))
                (setq not-indented nil))
            (setq cur-indent (- (current-indentation) 2))))
        (if (< cur-indent 0)     ; We can't indent past the left margin
            (setq cur-indent 0)))
       (t
        ;; Otherwise, we did not start on a block-ending-only line.
        (save-excursion
          ;; Iterate backwards until we find an indentation hint
          (while not-indented
            (forward-line -1)
            (cond
             ((puppet-comment-line-p)
              (if (bobp)
                  (setq not-indented nil)
                ;; else ignore the line and continue iterating backwards
                ))
             ((looking-at "^.*}") ; indent at the level of the END_ token
              (setq cur-indent (current-indentation))
              (setq not-indented nil))
             ((looking-at "^.*{") ; indent an extra level
              (setq cur-indent (+ (current-indentation) 2)) 
              (setq not-indented nil))
             ((bobp)
              (setq not-indented nil))
             )))))
      (if cur-indent
          (indent-line-to cur-indent)
        (indent-line-to 0)))))


;;;###autoload
(defun puppet-mode ()
  "Major mode for editing puppet manifests.

The variable puppet-indent-level controls the amount of indentation.
\\{puppet-mode-map}"
  (interactive)
  (kill-all-local-variables)
  (use-local-map puppet-mode-map)
  (setq mode-name "Puppet")
  (setq major-mode 'puppet-mode)
  (puppet-mode-variables)
 ;; Register our indentation function
  (set (make-local-variable 'indent-line-function) 'puppet-indent-line)  
  (run-hooks 'puppet-mode-hook))



(cond
 ((featurep 'font-lock)
  (or (boundp 'font-lock-variable-name-face)
      (setq font-lock-variable-name-face font-lock-type-face))

  (setq puppet-font-lock-syntactic-keywords
        '(
          ("\\(^\\|[=(,~?:;]\\|\\(^\\|\\s \\)\\(if\\|elsif\\|unless\\|while\\|until\\|when\\|and\\|or\\|&&\\|||\\)\\|g?sub!?\\|scan\\|split!?\\)\\s *\\(/\\)[^/\n\\\\]*\\(\\\\.[^/\n\\\\]*\\)*\\(/\\)"
           (4 (7 . ?/))
           (6 (7 . ?/)))
          ("^\\(=\\)begin\\(\\s \\|$\\)" 1 (7 . nil))
          ("^\\(=\\)end\\(\\s \\|$\\)" 1 (7 . nil))))

  (cond ((featurep 'xemacs)
         (put 'puppet-mode 'font-lock-defaults
              '((puppet-font-lock-keywords)
                nil nil nil
                beginning-of-line
                (font-lock-syntactic-keywords
                 . puppet-font-lock-syntactic-keywords))))
        (t
         (add-hook 'puppet-mode-hook
            '(lambda ()
               (make-local-variable 'font-lock-defaults)
               (make-local-variable 'font-lock-keywords)
               (make-local-variable 'font-lock-syntax-table)
               (make-local-variable 'font-lock-syntactic-keywords)
               (setq font-lock-defaults '((puppet-font-lock-keywords) nil nil))
               (setq font-lock-keywords puppet-font-lock-keywords)
               (setq font-lock-syntax-table puppet-font-lock-syntax-table)
               (setq font-lock-syntactic-keywords puppet-font-lock-syntactic-keywords)))))

  (defvar puppet-font-lock-syntax-table
    (let* ((tbl (copy-syntax-table puppet-mode-syntax-table)))
      (modify-syntax-entry ?_ "w" tbl)
      tbl))

  (defvar puppet-font-lock-keywords
    (list
     ;; defines
     '("^\\s *\\(define\\|node\\|class\\)\\s +\\([^( \t\n]+\\)"
       2 font-lock-function-name-face)
     ;; include
     '("^\\s *include\\s +\\([^( \t\n]+\\)"
       1 font-lock-reference-face)
     ;; keywords
     (cons (concat
            "\\b\\(\\("
            (mapconcat
             'identity
             '("case"
               "class"
               "default"
               "define"
               "false"
               "import"
               "include"
               "inherits"
               "node"
               "true"
               )
             "\\|")
            "\\)\\>\\)")
           1)
     ;; variables
     '("\\(^\\|[^_:.@$]\\|\\.\\.\\)\\b\\(nil\\|self\\|true\\|false\\)\\>"
       2 font-lock-variable-name-face)
     ;; variables
     '("\\(\\$\\([^a-zA-Z0-9 \n]\\|[0-9]\\)\\)\\W"
       1 font-lock-variable-name-face)
     '("\\(\\$\\|@\\|@@\\)\\(\\w\\|_\\)+"
       0 font-lock-variable-name-face)
     ;; usage of types
     '("^\\s +\\([a-zA-Z-]+\\)\\s +{" 
       1 font-lock-type-face)
     ;; general delimited string
     '("\\(^\\|[[ \t\n<+(,=]\\)\\(%[xrqQwW]?\\([^<[{(a-zA-Z0-9 \n]\\)[^\n\\\\]*\\(\\\\.[^\n\\\\]*\\)*\\(\\3\\)\\)"
       (2 font-lock-string-face))
     )
    "*Additional expressions to highlight in puppet mode."))
 )

(provide 'puppet-mode)
