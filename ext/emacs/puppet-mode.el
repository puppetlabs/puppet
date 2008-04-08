;;;
;;; puppet-mode.el
;;; 
;;; Author: lutter
;;; Description: A simple mode for editing puppet manifests
;;;

(defconst puppet-mode-version "0.1")

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
    (modify-syntax-entry ?\' "\"" table)
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?#  "<"  table)
    (modify-syntax-entry ?\n ">"  table)
    (modify-syntax-entry ?\\ "\\" table)
    (modify-syntax-entry ?$  "."  table)
    (modify-syntax-entry ?-  "_"  table)
    (modify-syntax-entry ?>  "."  table)
    (modify-syntax-entry ?=  "."  table)
    (modify-syntax-entry ?\; "."  table)
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    table)
  "Syntax table in use in puppet-mode buffers.")

(defcustom puppet-indent-tabs-mode nil
  "*Indentation can insert tabs in puppet mode if this is non-nil."
  :type 'boolean :group 'puppet)

(defcustom puppet-comment-column 32
  "*Indentation column of comments."
  :type 'integer :group 'puppet)

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
             ((puppet-comment-line-p)
              (if (bobp)
                  (setq not-found nil)))
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
       ((looking-at "^[^{\n]*}")
        ;; This line contains the end of a block, but the block does
        ;; not also begin on this line, so decrease the indentation.
        (save-excursion
          (forward-line -1)
          (if (looking-at "^.*}")
              (progn
                (setq cur-indent (- (current-indentation) puppet-indent-level))
                (setq not-indented nil))
            (setq cur-indent (- (current-indentation) puppet-indent-level))))
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
              (setq cur-indent (+ (current-indentation) puppet-indent-level)) 
              (setq not-indented nil))
             ((looking-at "^.*;\\s-*$") ; Semicolon ends a nested resource
              (setq cur-indent (- (current-indentation) puppet-indent-level))
              (setq not-indented nil))
             ((looking-at "^.*:\\s-*$") ; indent an extra level after :
              (setq cur-indent (+ (current-indentation) puppet-indent-level))
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
  (set-syntax-table puppet-mode-syntax-table)
  (set (make-local-variable 'local-abbrev-table) puppet-mode-abbrev-table)
  (set (make-local-variable 'comment-start) "# ")
  (set (make-local-variable 'comment-start-skip) "#+ *")
  (set (make-local-variable 'comment-end) "")
  (set (make-local-variable 'comment-column) puppet-comment-column)
  (set (make-local-variable 'indent-line-function) 'puppet-indent-line)
  (set (make-local-variable 'indent-tabs-mode) puppet-indent-tabs-mode)
  (set (make-local-variable 'require-final-newline) t)
  (set (make-local-variable 'paragraph-ignore-fill-prefix) t)
  (set (make-local-variable 'paragraph-start) "\f\\|[ 	]*$")
  (set (make-local-variable 'paragraph-separate) "[ 	\f]*$")
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
     '("\\s +inherits\\s +\\([^( \t\n]+\\)"
       1 font-lock-function-name-face)
     ;; include
     '("^\\s *include\\s +\\([^( \t\n,]+\\)"
       1 font-lock-reference-face)
     ;; hack to catch continued includes
     '("^\\s *\\([a-zA-Z0-9:_-]+\\),?\\s *$"
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
               "realize"
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
     '("^\\s +\\([a-zA-Z_-]+\\)\\s +{" 
       1 font-lock-type-face)
     ;; overrides
     '("^\\s +\\([a-zA-Z_-]+\\)\\["
       1 font-lock-type-face)
     ;; general delimited string
     '("\\(^\\|[[ \t\n<+(,=]\\)\\(%[xrqQwW]?\\([^<[{(a-zA-Z0-9 \n]\\)[^\n\\\\]*\\(\\\\.[^\n\\\\]*\\)*\\(\\3\\)\\)"
       (2 font-lock-string-face))
     )
    "*Additional expressions to highlight in puppet mode."))
 )

(provide 'puppet-mode)
