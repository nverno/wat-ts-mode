;;; wat-ts-mode.el --- Major modes for webassembly text formats using tree sitter -*- lexical-binding: t; -*-
;; Author: Noah Peart <noah.v.peart@gmail.com>
;; URL: https://github.com/nverno/wat-ts-mode
;; Version: 1.0.0
;; Package-Requires: ((emacs "29.1"))
;; Created: 13 September 2023
;; Keywords: wasm wat wast languages tree-sitter

;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; This package defines tree-sitter enabled major modes for webassembly,
;; `wat-ts-mode' and `wat-ts-wast-mode', for webassembly text format and script
;; buffers respectively. They provides support for indentation, font-locking,
;; imenu, and structural navigation.
;;
;; The tree-sitter grammars compatible with this package can be found at
;; https://github.com/wasm-lsp/tree-sitter-wasm.
;;
;;; Installation:
;;
;; For a simple way to install the tree-sitter grammar libraries,
;; add the following entries to `treesit-language-source-alist':
;;
;;    '(wast "https://github.com/wasm-lsp/tree-sitter-wasm" nil "wast/src")
;;    '(wat "https://github.com/wasm-lsp/tree-sitter-wasm" nil "wat/src")
;; eg. for wat
;;     (add-to-list
;;      'treesit-language-source-alist
;;      '(wat "https://github.com/wasm-lsp/tree-sitter-wasm" nil "wat/src"))
;;
;; and call `treesit-install-language-grammar' to do the installation.
;;
;;; Code:

(eval-when-compile (require 'cl-lib))
(require 'treesit)

(defcustom wat-ts-mode-indent-level 2
  "Number of spaces for each indententation step."
  :group 'wat
  :type 'integer
  :safe 'integerp)

(defvar wat-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?\( "()1nb" table) ; (; .. ;)
    (modify-syntax-entry ?\) ")(4nb" table)
    (modify-syntax-entry ?\; "< 123" table)
    (modify-syntax-entry ?\n ">b" table)
    (modify-syntax-entry ?. "_" table)
    (modify-syntax-entry ?_ "w" table)
    (modify-syntax-entry ?$ "'" table)
    (modify-syntax-entry ?@ "'" table)
    table))

(defun wat-ts-mode--indent-rules (language)
  "Tree-sitter indentation rules for LANGUAGE, one of `wat' or `wast'."
  `((,language
     ((parent-is "ROOT") parent 0)
     ((node-is ";)") parent-bol 0)
     ((node-is "then") parent-bol 0)
     ((node-is "else") parent-bol 0)
     ((node-is "end") parent-bol 0)
     ((and (node-is "(") (parent-is "if_block")) parent-bol wat-ts-mode-indent-level)
     ((and (node-is ")") (parent-is "if_block")) parent-bol wat-ts-mode-indent-level)
     ((and (node-is "instr_list") (parent-is "if_block")) first-sibling 0)
     ((node-is ")") parent-bol 0)
     ((parent-is "module_field") parent-bol wat-ts-mode-indent-level)
     ((parent-is "instr_list") first-sibling 0)
     ((parent-is "comment_block") no-indent)
     (no-node parent-bol wat-ts-mode-indent-level)
     (catch-all parent-bol wat-ts-mode-indent-level))))

(defvar wat-ts-mode--keywords
  '("align" "block" "br_table" "data" "declare" "elem" "else" "end" "export"
    "func" "global" "if" "import" "item" "let" "local" "loop" "memory" "module"
    "offset" "param" "result" "select" "start" "table" "then" "type")
  "Wat keywords.")

(defvar wat-ts--wast-assertions
  '("assert_malformed"
    "assert_return"
    "assert_invalid"
    "assert_return_arithmetic_nan"
    "assert_return_canonical_nan"
    "assert_trap"
    "assert_unlinkable"
    ;; "assert_uninstantiable"             ; XXX: missing from grammar
    "assert_exhaustion"
    ;; "assert_exception"                  ; XXX: missing from grammar
    )
  "Wast assertion commands.")

(defvar wat-ts--wast-keywords
  `("binary"                            ; module binary
    "get"
    "input"
    "invoke"
    "output"
    "quote"                             ; module quote
    "register"
    "script"
    ,@wat-ts--wast-assertions)
  "Wast mode keywords.")

(defun wat-ts-mode--font-lock-settings (language)
  "Tree-sitter font-lock settings for LANGUAGE, one of `wat' or `wast'."
  (treesit-font-lock-rules
   :language language
   :feature 'comment
   '([(comment_line) (comment_block)] @font-lock-comment-face)

   :language language
   :feature 'string
   '((string) @font-lock-string-face)
   
   :language language
   :feature 'number
   '([(nat) (float) (nan) (align_offset_value)] @font-lock-number-face)

   :language language
   :feature 'type
   '([(value_type) (ref_type) (ref_kind) (elem_kind)] @font-lock-type-face
     (global_type_mut "mut" @font-lock-type-face)
     (memory_type (_ (_) @font-lock-type-face)))

   :language language
   :feature 'definition
   '((module
      identifier: (identifier) @font-lock-function-name-face)

     (module_field_func
      identifier: (identifier) @font-lock-function-name-face)
     
     (identifier) @font-lock-variable-name-face)

   :language language
   :feature 'annotations
   '((annotation
      "(@" (identifier_pattern) @font-lock-property-use-face)
     (reserved) @font-lock-constant-face)
   
   :language language
   :feature 'keyword
   (append
    `([,@(append (when (eq 'wast language) wat-ts--wast-keywords)
                 wat-ts-mode--keywords)]
      @font-lock-keyword-face

      ([(op_nullary) (op_index)] @kw
       (:match
        ,(rx (or "return" "nop" "unreachable" (seq "br" (? (seq "_" (* word))))))
        @kw))
      @font-lock-keyword-face))

   :language language
   :feature 'instruction
   '([(pat00) (pat01)] @font-lock-builtin-face
     (instr_list_call _ @font-lock-builtin-face)
     (instr_plain _ @font-lock-builtin-face)
     (op_table_init _ @font-lock-builtin-face))

   :language language
   :feature 'simd
   '((op_simd_lane _ @font-lock-builtin-face)
     (op_simd_const
      _ @font-lock-builtin-face
      _ @font-lock-type-face))

   ;; :language language
   ;; :feature 'exceptions
   ;; XXX: try/catch/throw/rethrow/delegate
   ;; not defined in tree sitter grammar
   
   :language language
   :feature 'bracket
   '(("(" ")") @font-lock-bracket-face)

   :language language
   :feature 'operator
   '(("=") @font-lock-operator-face)
   
   :language language
   :feature 'escape-sequence
   :override t
   '((escape_sequence) @font-lock-escape-face)

   :language language
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face)))

(defun wat-ts-mode--defun-name (node)
  "Return name for NODE or nil if NODE has no name or is invalid."
  (treesit-node-text
   (pcase (treesit-node-type node)
     ((pred (string-match-p
             (rx "module"
                 (? (seq "_field_" (or "func" "memory" "table" "global" "type")))
                 eos)))
      (treesit-node-child-by-field-name node "identifier"))
     (_ (treesit-search-subtree
         (treesit-node-child node 0 "index") "identifier" nil nil 1)))))

(defun wat-ts-mode--valid-imenu-p (node)
  "Return nil if NODE shouldn't be included in imenu."
  (wat-ts-mode--defun-name node))

(defvar wat-ts-mode--sentence-nodes
  (rx (or "expr"
          "instr_list")))

(defvar wat-ts-mode--sexp-nodes
  (rx (or "annotation"
          "command"
          "comment"
          "elem"
          "export"
          (seq "expr" eos)
          (seq "func" eos)
          "func_locals" "func_type"
          "global"
          "identifier"
          "import"
          "index"
          (seq "instr" eos)
          "local"
          "module"
          "name"
          "nat"
          "num"
          "offset"
          "op"
          "ref"
          "string"
          "table"
          "type"
          "value")))

;;;###autoload
(define-derived-mode wat-ts-mode prog-mode "Wat"
  "Major mode for editing webassembly text format buffers.

\\<wat-ts-mode-map>"
  :group 'wat
  :syntax-table wat-ts-mode--syntax-table
  (when (treesit-ready-p 'wat)
    (treesit-parser-create 'wat))

  (setq-local comment-start ";; ")
  (setq-local comment-end "")
  (setq-local comment-start-skip (rx ";;" (* (syntax whitespace))))
  
  ;; Indentation
  (setq-local treesit-simple-indent-rules (wat-ts-mode--indent-rules 'wat))

  ;; Font-Locking
  (setq-local treesit-font-lock-settings (wat-ts-mode--font-lock-settings 'wat))
  (setq-local treesit-font-lock-feature-list
              '(( comment string definition)
                ( keyword type variable instruction annotations
                  ;; optionally enabled
                  simd exceptions)
                ( constant number escape-sequence)
                ( bracket operator error)))
  
  ;; Navigation
  (setq-local treesit-defun-prefer-top-level t)
  (setq-local treesit-defun-name-function #'wat-ts-mode--defun-name)
  (setq-local treesit-defun-type-regexp (rx bos "module"))

  ;; navigation objects
  (setq-local treesit-thing-settings
              `((wat
                 (sexp ,wat-ts-mode--sexp-nodes)
                 (sentence ,wat-ts-mode--sentence-nodes)
                 (text ,(rx (or "comment_line" "comment_block" "string"))))))

  ;; Imenu
  (setq-local treesit-simple-imenu-settings
              (cl-loop
               for kind in '("func" "elem" "data" "global" "type" "table" "memory")
               collect (list kind (concat "\\`module_field_" kind)
                             #'wat-ts-mode--valid-imenu-p nil)))

  (treesit-major-mode-setup))

(if (treesit-ready-p 'wat)
    (add-to-list 'auto-mode-alist '("\\.wat\\'" . wat-ts-mode)))

;; -------------------------------------------------------------------
;;; Wast

(defun wat-ts--wast-defun-name (node)
  "Return name for NODE or nil if NODE has no name or is invalid."
  (or (wat-ts-mode--defun-name node)
      (treesit-node-text
       (pcase (treesit-node-type node)
         ((pred (string-match-p
                 (rx (or (seq "meta_" (or "input" "output" "script"))
                         (seq "script_module_" (or "binary" "quote"))
                         "register")
                     eos)))
          (treesit-search-subtree node "identifier" nil nil 1))
         (_ node)))))

(defun wat-ts--wast-valid-imenu-p (node)
  "Return nil if NODE shouldn't be included in imenu."
  (wat-ts--wast-defun-name node))

;;;###autoload
(define-derived-mode wat-ts-wast-mode wat-ts-mode "Wast"
  "Major mode for editing webassembly script buffers.

\\<wat-ts-mode-map>"
  :group 'wat
  :syntax-table wat-ts-mode--syntax-table
  (when (treesit-ready-p 'wast)
    (treesit-parser-create 'wast))

  ;; Indentation
  (setq-local treesit-simple-indent-rules (wat-ts-mode--indent-rules 'wast))

  ;; Font-Locking
  (setq-local treesit-font-lock-settings (wat-ts-mode--font-lock-settings 'wast))
  
  ;; Navigation
  (setq-local treesit-defun-prefer-top-level t)
  (setq-local treesit-defun-name-function #'wat-ts--wast-defun-name)
  (setq-local treesit-defun-type-regexp
              (rx bos (or "meta" "register" "module" "script")))

  ;; navigation objects
  (setq-local treesit-thing-settings
              (list (cons 'wast (cdr (assq 'wat treesit-thing-settings)))))

  ;; Imenu
  (setq-local treesit-simple-imenu-settings
              (append treesit-simple-imenu-settings
                      `(("meta" ,(rx bos "meta_" (or "input" "output" "module") eos)
                         wat-ts--wast-valid-imenu-p nil)
                        ("register" "\\`register\\'" wat-ts--wast-valid-imenu-p nil)
                        ("module"
                         ,(rx bos "script_module_" (or "binary" "quote") eos)
                         wat-ts--wast-valid-imenu-p nil))))

  (treesit-major-mode-setup))

(if (treesit-ready-p 'wast)
    (add-to-list 'auto-mode-alist '("\\.wast\\'" . wat-ts-wast-mode)))

(provide 'wat-ts-mode)
;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:
;;; wat-ts-mode.el ends here
