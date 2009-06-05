;;;
;;; puppet-mode.el
;;;
;;; Author: lutter
;;; Author: Russ Allbery <rra@stanford.edu>
;;;
;;; Description: A simple mode for editing puppet manifests

(defconst puppet-mode-version "0.2")

(defvar puppet-mode-abbrev-table nil
  "Abbrev table in use in puppet-mode buffers.")

(define-abbrev-table 'puppet-mode-abbrev-table ())

(defcustom puppet-indent-level 2
  "*Indentation of Puppet statements."
  :type 'integer :group 'puppet)

(defcustom puppet-include-indent 2
  "*Indentation of continued Puppet include statements."
  :type 'integer :group 'puppet)

(defvar puppet-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-j" 'newline-and-indent)
    (define-key map "\C-m" 'newline-and-indent)
    map)
  "Key map used in puppet-mode buffers.")

(defvar puppet-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?\' "\"'"  table)
    (modify-syntax-entry ?\" "\"\"" table)
    (modify-syntax-entry ?#  "<"    table)
    (modify-syntax-entry ?\n ">#"   table)
    (modify-syntax-entry ?\\ "\\"   table)
    (modify-syntax-entry ?$  "'"    table)
    (modify-syntax-entry ?-  "_"    table)
    (modify-syntax-entry ?:  "_"    table)
    (modify-syntax-entry ?>  "."    table)
    (modify-syntax-entry ?=  "."    table)
    (modify-syntax-entry ?\; "."    table)
    (modify-syntax-entry ?\( "()"   table)
    (modify-syntax-entry ?\) ")("   table)
    (modify-syntax-entry ?\{ "(}"   table)
    (modify-syntax-entry ?\} "){"   table)
    (modify-syntax-entry ?\[ "(]"   table)
    (modify-syntax-entry ?\] ")["   table)
    table)
  "Syntax table in use in puppet-mode buffers.")

(defcustom puppet-indent-tabs-mode nil
  "*Indentation can insert tabs in puppet mode if this is non-nil."
  :type 'boolean :group 'puppet)

(defcustom puppet-comment-column 32
  "*Indentation column of comments."
  :type 'integer :group 'puppet)

(defun puppet-count-matches (re start end)
  "The same as Emacs 22 count-matches, for portability to other versions
of Emacs."
  (save-excursion
    (let ((n 0))
      (goto-char start)
      (while (re-search-forward re end t) (setq n (1+ n)))
      n)))

(defun puppet-comment-line-p ()
  "Return non-nil iff this line is a comment."
  (save-excursion
    (save-match-data
      (beginning-of-line)
      (looking-at (format "\\s-*%s" comment-start)))))

(defun puppet-block-indent ()
  "If point is in a block, return the indentation of the first line of that
block (the line containing the opening brace).  Used to set the indentation
of the closing brace of a block."
  (save-excursion
    (save-match-data
      (let ((opoint (point))
            (apoint (search-backward "{" nil t)))
        (when apoint
          ;; This is a bit of a hack and doesn't allow for strings.  We really
          ;; want to parse by sexps at some point.
          (let ((close-braces (puppet-count-matches "}" apoint opoint))
                (open-braces 0))
            (while (and apoint (> close-braces open-braces))
              (setq apoint (search-backward "{" nil t))
              (when apoint
                (setq close-braces (puppet-count-matches "}" apoint opoint))
                (setq open-braces (1+ open-braces)))))
          (if apoint
              (current-indentation)
            nil))))))

(defun puppet-in-array ()
  "If point is in an array, return the position of the opening '[' of
that array, else return nil."
  (save-excursion
    (save-match-data
      (let ((opoint (point))
            (apoint (search-backward "[" nil t)))
        (when apoint
          ;; This is a bit of a hack and doesn't allow for strings.  We really
          ;; want to parse by sexps at some point.
          (let ((close-brackets (puppet-count-matches "]" apoint opoint))
                (open-brackets 0))
            (while (and apoint (> close-brackets open-brackets))
              (setq apoint (search-backward "[" nil t))
              (when apoint
                (setq close-brackets (puppet-count-matches "]" apoint opoint))
                (setq open-brackets (1+ open-brackets)))))
          apoint)))))

(defun puppet-in-include ()
  "If point is in a continued list of include statements, return the position
of the initial include plus puppet-include-indent."
  (save-excursion
    (save-match-data
      (let ((include-column nil)
            (not-found t))
        (while not-found
          (forward-line -1)
          (cond
           ((bobp)
            (setq not-found nil))
           ((looking-at "^\\s-*include\\s-+.*,\\s-*$")
            (setq include-column
                  (+ (current-indentation) puppet-include-indent))
            (setq not-found nil))
           ((not (looking-at ".*,\\s-*$"))
            (setq not-found nil))))
        include-column))))

(defun puppet-indent-line ()
  "Indent current line as puppet code."
  (interactive)
  (beginning-of-line)
  (if (bobp)
      (indent-line-to 0)                ; First line is always non-indented
    (let ((not-indented t)
          (array-start (puppet-in-array))
          (include-start (puppet-in-include))
          (block-indent (puppet-block-indent))
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
       (include-start
        (setq cur-indent include-start))
       ((and (looking-at "^\\s-*},?\\s-*$") block-indent)
        ;; This line contains a closing brace or a closing brace followed by a
        ;; comma and we're at the inner block, so we should indent it matching
        ;; the indentation of the opening brace of the block.
        (setq cur-indent block-indent))
       (t
        ;; Otherwise, we did not start on a block-ending-only line.
        (save-excursion
          ;; Iterate backwards until we find an indentation hint
          (while not-indented
            (forward-line -1)
            (cond
             ;; Comment lines are ignored unless we're at the start of the
             ;; buffer.
             ((puppet-comment-line-p)
              (if (bobp)
                  (setq not-indented nil)))

             ;; Brace or paren on a line by itself will already be indented to
             ;; the right level, so we can cheat and stop there.
             ((looking-at "^\\s-*[\)}]\\s-*")
              (setq cur-indent (current-indentation))
              (setq not-indented nil))

             ;; Brace (possibly followed by a comma) or paren not on a line by
             ;; itself will be indented one level too much, but don't catch
             ;; cases where the block is started and closed on the same line.
             ((looking-at "^[^\n\({]*[\)}],?\\s-*$")
              (setq cur-indent (- (current-indentation) puppet-indent-level))
              (setq not-indented nil))

             ;; Indent by one level more than the start of our block.  We lose
             ;; if there is more than one block opened and closed on the same
             ;; line but it's still unbalanced; hopefully people don't do that.
             ((looking-at "^.*{[^\n}]*$")
              (setq cur-indent (+ (current-indentation) puppet-indent-level))
              (setq not-indented nil))

             ;; Indent by one level if the line ends with an open paren.
             ((looking-at "^.*\(\\s-*$")
              (setq cur-indent (+ (current-indentation) puppet-indent-level))
              (setq not-indented nil))

             ;; Semicolon ends a block for a resource when multiple resources
             ;; are defined in the same block, but try not to get the case of
             ;; a complete resource on a single line wrong.
             ((looking-at "^\\([^'\":\n]\\|\"[^\n\"]*\"\\|'[^\n']*'\\)*;\\s-*$")
              (setq cur-indent (- (current-indentation) puppet-indent-level))
              (setq not-indented nil))

             ;; Indent an extra level after : since it introduces a resource.
             ((looking-at "^.*:\\s-*$")
              (setq cur-indent (+ (current-indentation) puppet-indent-level))
              (setq not-indented nil))

             ;; Start of buffer.
             ((bobp)
              (setq not-indented nil)))))

        ;; If this line contains only a closing paren, we should lose one
        ;; level of indentation.
        (if (looking-at "^\\s-*\)\\s-*$")
            (setq cur-indent (- cur-indent puppet-indent-level)))))

      ;; We've figured out the indentation, so do it.
      (if (and cur-indent (> cur-indent 0))
          (indent-line-to cur-indent)
        (indent-line-to 0)))))

(defvar puppet-font-lock-syntax-table
  (let* ((tbl (copy-syntax-table puppet-mode-syntax-table)))
    (modify-syntax-entry ?_ "w" tbl)
    tbl))

(defvar puppet-font-lock-keywords
  (list
   ;; defines, classes, and nodes
   '("^\\s *\\(class\\|define\\|node\\)\\s +\\([^( \t\n]+\\)"
     2 font-lock-function-name-face)
   ;; inheritence
   '("\\s +inherits\\s +\\([^( \t\n]+\\)"
     1 font-lock-function-name-face)
   ;; include
   '("\\(^\\|\\s +\\)include\\s +\\(\\([a-zA-Z0-9:_-]+\\(,[ \t\n]*\\)?\\)+\\)"
     2 font-lock-reference-face)
   ;; keywords
   (cons (concat
          "\\b\\(\\("
          (mapconcat
           'identity
           '("alert"
             "case"
             "class"
             "crit"
             "debug"
             "default"
             "define"
             "defined"
             "else"
             "emerg"
             "err"
             "fail"
             "false"
             "file"
             "filebucket"
             "generate"
             "if"
             "import"
             "include"
             "info"
             "inherits"
             "node"
             "notice"
             "realize"
             "search"
             "tag"
             "tagged"
             "template"
             "true"
             "warning"
             )
           "\\|")
          "\\)\\>\\)")
         1)
     ;; variables
     '("\\(^\\|[^_:.@$]\\)\\b\\(true\\|false\\)\\>"
       2 font-lock-variable-name-face)
     '("\\$[a-zA-Z0-9_:]+"
       0 font-lock-variable-name-face)
     ;; usage of types
     '("^\\s *\\([a-z][a-zA-Z0-9_:-]*\\)\\s +{"
       1 font-lock-type-face)
     ;; overrides and type references
     '("\\s +\\([A-Z][a-zA-Z0-9_:-]*\\)\\["
       1 font-lock-type-face)
     ;; general delimited string
     '("\\(^\\|[[ \t\n<+(,=]\\)\\(%[xrqQwW]?\\([^<[{(a-zA-Z0-9 \n]\\)[^\n\\\\]*\\(\\\\.[^\n\\\\]*\\)*\\(\\3\\)\\)"
       (2 font-lock-string-face)))
  "*Additional expressions to highlight in puppet mode.")

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
  (set-syntax-table puppet-mode-syntax-table)
  (set (make-local-variable 'local-abbrev-table) puppet-mode-abbrev-table)
  (set (make-local-variable 'comment-start) "# ")
  (set (make-local-variable 'comment-start-skip) "#+ *")
  (set (make-local-variable 'comment-use-syntax) t)
  (set (make-local-variable 'comment-end) "")
  (set (make-local-variable 'comment-auto-fill-only-comments) t)
  (set (make-local-variable 'comment-column) puppet-comment-column)
  (set (make-local-variable 'indent-line-function) 'puppet-indent-line)
  (set (make-local-variable 'indent-tabs-mode) puppet-indent-tabs-mode)
  (set (make-local-variable 'require-final-newline) t)
  (set (make-local-variable 'paragraph-ignore-fill-prefix) t)
  (set (make-local-variable 'paragraph-start) "\f\\|[ 	]*$\\|#$")
  (set (make-local-variable 'paragraph-separate) "\\([ 	\f]*\\|#\\)$")
  (or (boundp 'font-lock-variable-name-face)
      (setq font-lock-variable-name-face font-lock-type-face))
  (set (make-local-variable 'font-lock-keywords) puppet-font-lock-keywords)
  (set (make-local-variable 'font-lock-multiline) t)
  (set (make-local-variable 'font-lock-defaults)
       '((puppet-font-lock-keywords) nil nil))
  (set (make-local-variable 'font-lock-syntax-table)
       puppet-font-lock-syntax-table)
  (run-hooks 'puppet-mode-hook))

(provide 'puppet-mode)
