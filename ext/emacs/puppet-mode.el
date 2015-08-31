;;; puppet-mode.el --- major mode for Puppet manifests

;; Copyright 2006 David Lutterkort
;; Copyright 2008 Karl Fogel <kfogel@red-bean.com>
;; Copyright 2008, 2012
;;     The Board of Trustees of the Leland Stanford Junior University

;; Author: David Lutterkort
;;	Russ Allbery <rra@stanford.edu>
;; Maintainer: Russ Allbery <rra@stanford.edu>
;; Created: 2006-02-07
;; Version: 1.2
;; Keywords: languages

;; This file is part of Puppet.
;;
;; Licensed under the Apache License, Version 2.0 (the "License"); you may not
;; use this file except in compliance with the License.  You may obtain a copy
;; of the License at
;;
;;     https://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
;; WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
;; License for the specific language governing permissions and limitations
;; under the License.

;;; Code:

(defconst puppet-mode-version "1.2")

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

(defun puppet-analyze-indent ()
  "Analyze the identation at point and return the discovered indentation level
we should use, or nil if we can't determine one."
  (cond
   ;; Comment lines are ignored unless we're at the start of the buffer.
   ((puppet-comment-line-p)
    (if (bobp) 0 nil))

   ;; Closing brace or paren on a line by itself will already be indented to
   ;; the right level, so we can cheat and stop there.
   ((looking-at "^\\s-*[\)}]\\s-*$")
    (current-indentation))

   ;; Closing brace or paren not on a line by itself will be indented one
   ;; level too much, but don't catch cases where the block is started and
   ;; closed on the same line.
   ((looking-at "^[^\n\({]*[\)}]\\s-*$")
    (- (current-indentation) puppet-indent-level))

   ;; Closing brace followed by a comma ends a selector within a resource and
   ;; will be indented just the right amount.  Take similar precautions about
   ;; blocks started and closed on the same line.
   ((looking-at "^[^\n\({]*},\\s-*$")
    (current-indentation))

   ;; Indent by one level more than the start of our block.  We lose if there
   ;; is more than one block opened and closed on the same line but it's still
   ;; unbalanced; hopefully people don't do that.
   ((looking-at "^.*{[^\n}]*$")
    (+ (current-indentation) puppet-indent-level))

   ;; Indent by one level if the line ends with an open paren.
   ((looking-at "^.*(\\s-*$")
    (+ (current-indentation) puppet-indent-level))

   ;; Semicolon ends a block for a resource when multiple resources are
   ;; defined in the same block, but try not to get the case of a complete
   ;; resource on a single line wrong.
   ((looking-at "^\\([^'\":\n]\\|\"[^\n\"]*\"\\|'[^\n']*'\\)*;\\s-*$")
    (- (current-indentation) puppet-indent-level))

   ;; The line following the end of an array and a : should be indented one
   ;; level more than the indentation of the start of the array.
   ((looking-at "^.*\\]\\s-*:\\s-*$")
      (let ((array-start (puppet-in-array)))
        (if array-start
          (save-excursion
            (beginning-of-line)
            (goto-char array-start)
            (+ (current-indentation) puppet-indent-level))
        (+ (current-indentation) puppet-indent-level))))

   ;; Indent an extra level after : since it introduces a resource.
   ((looking-at "^.*:\\s-*$")
    (+ (current-indentation) puppet-indent-level))

   ;; Start of buffer.
   ((bobp)
    0)))

(defun puppet-do-indent ()
  "Internal function for puppet-indent-line.  This does the indent without
worrying about saving the excursion."
  (beginning-of-line)
  (if (bobp)
      (indent-line-to 0)              ; First line is always non-indented
    (let ((not-indented t)
          (array-start (puppet-in-array))
          (include-start (puppet-in-include))
          (block-indent (puppet-block-indent))
          cur-indent)

      ;; First, check if we started in an array or on a block-ending line.
      (cond
       ;; This line probably starts with an element from an array.  Indent
       ;; the line to the same indentation as the first element in that
       ;; array.  That is, this...
       ;;
       ;;    exec { 'add puppetmaster mongrel startup links':
       ;;      creates => [ 'string2', 'string3',
       ;;      'string4', 'string5',
       ;;      'string6', 'string7',
       ;;      'string8' ],
       ;;    }
       ;;
       ;; ...should instead look like this:
       ;;
       ;;    exec { 'add puppetmaster mongrel startup links':
       ;;      creates => [ 'string2', 'string3',
       ;;                   'string4', 'string5',
       ;;                   'string6', 'string7',
       ;;                   'string8' ],
       ;;    }
       (array-start
        (save-excursion
          (goto-char array-start)
          (forward-char 1)
          (if (looking-at "\\s-+\n")
              (setq cur-indent (1+ (current-column)))
            (re-search-forward "\\S-")
            (forward-char -1)
            (setq cur-indent (current-column)))))

       ;; Inside an include.
       (include-start
        (setq cur-indent include-start))

       ;; This line contains a closing brace, a closing brace followed by a
       ;; comma, or a closing brace followed by else or elsif and we're at
       ;; the inner block, so we should indent it matching the indentation
       ;; of the opening brace of the block.
       ((and (looking-at "^\\s-*}\\(,?\\s-*$\\|\\s-*els\\(e\\|if\\)\\s-\\)")
             block-indent)
        (setq cur-indent block-indent))

       ;; Otherwise, we did not start on a block-ending-only line, so we
       ;; have to search backwards for an indentation hint.
       (t
        (save-excursion
          (while
              (not (progn
                     (forward-line -1)
                     (setq cur-indent (puppet-analyze-indent))))))

        ;; If this line contains only a closing paren or a closing paren
        ;; followed by an opening brace, we added one too many levels of
        ;; indentation and should lose one level.
        (if (looking-at "^\\s-*)\\s-*\\({\\s-*\\)?$")
            (setq cur-indent (- cur-indent puppet-indent-level)))))

      ;; We've figured out the indentation, so do it.
      (if (< cur-indent 0)
          (indent-line-to 0)
        (indent-line-to cur-indent)))))

(defun puppet-indent-line ()
  "Indent current line as Puppet code."
  (interactive)
  (if (or (bolp)
          (save-excursion
            (beginning-of-line)
            (save-match-data (looking-at "\\s *\n"))))
      (puppet-do-indent)
    (save-excursion
      (puppet-do-indent))))

(defvar puppet-font-lock-syntax-table
  (let* ((tbl (copy-syntax-table puppet-mode-syntax-table)))
    (modify-syntax-entry ?_ "w" tbl)
    tbl))

;; Stupid hack required to allow me to assign a default face to something.
;; WTF, font-lock mode?  Not required on XEmacs (and breaks XEmacs).
(if (not (string-match "XEmacs" emacs-version))
    (defvar puppet-font-lock-default-face 'default))

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
   ;; variables
   '("\\$[a-zA-Z0-9_:]+" . font-lock-variable-name-face)
   ;; usage of types
   '("^\\s *\\([a-z][a-zA-Z0-9_:-]*\\)\\s +{"
     1 font-lock-type-face)
   ;; overrides, type references, and defaults
   '("\\(\\s \\|[\\[]\\)\\([A-Z][a-zA-Z0-9_:-]*\\)\\s *[\\[{]"
     2 font-lock-type-face)
   ;; general delimited string
   '("\\(^\\|[[ \t\n<+(,=]\\)\\(%[xrqQwW]?\\([^<[{(a-zA-Z0-9 \n]\\)[^\n\\\\]*\\(\\\\.[^\n\\\\]*\\)*\\(\\3\\)\\)"
     2 font-lock-string-face)
   ;; keywords
   (cons (regexp-opt
          '("alert"
            "and"
            "case"
            "class"
            "create_resources"
            "crit"
            "debug"
            "default"
            "define"
            "defined"
            "else"
            "elsif"
            "emerg"
            "err"
            "fail"
            "false"
            "file"
            "filebucket"
            "fqdn_rand"
            "generate"
            "if"
            "import"
            "in"
            "include"
            "info"
            "inherits"
            "inline_template"
            "md5"
            "node"
            "not"
            "notice"
            "or"
            "realize"
            "regsubst"
            "require"
            "search"
            "sha1"
            "shellquote"
            "split"
            "sprintf"
            "tag"
            "tagged"
            "template"
            "true"
            "undef"
            "versioncmp"
            "warning"
            )
          'words)
         1)
   ;; avoid marking require in resources as a keyword
   '("\\b\\(require\\)\\s-*=>"
     1 puppet-font-lock-default-face t))
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
  (set (make-local-variable 'parse-sexp-ignore-comments) t)
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

;;; puppet-mode.el ends here
