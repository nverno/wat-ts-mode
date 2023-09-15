;;; wat-ts-mode.el --- Tree-sitter support for wasm buffers -*- lexical-binding: t; -*-

;; This is free and unencumbered software released into the public domain.

;; Author: Noah Peart <noah.v.peart@gmail.com>
;; URL: https://github.com/nverno/wasm-ts-mode
;; Version: 1.0.0
;; Package-Requires: ((emacs "29.1"))
;; Created: 11 September 2023
;; Keywords: wasm wat languages tree-sitter

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
;; This package defines tree-sitter enabled major modes, `wat-ts-mode' and
;; `wat-ts-mode', for wasm and wat source buffers. It provides support for
;; indentation, font-locking, imenu, and structural navigation.
;;
;; The tree-sitter grammars compatible with this package can be found at
;; https://github.com/nverno/tree-sitter-wasm.
;;
;;; Installation:
;;
;; For a simple way to install the tree-sitter grammar library:
;; add the following entries to `treesit-language-source-alist'
;;
;;    '(wast "https://github.com/nverno/tree-sitter-wasm" nil nil "wast/src")
;;    '(wat "https://github.com/nverno/tree-sitter-wasm" nil "wat/src")
;; eg.
;;     (add-to-list
;;      'treesit-language-source-alist
;;      '(wat "https://github.com/wasm-lsp/tree-sitter-wasm" nil "wat/src"))
;;
;; and call `treesit-install-language-grammar' to do the installation.
;;
;;; Code:

(require 'treesit)


(defgroup wat nil
  "Customization variables for Wasm/Wat modes."
  :group 'languages)

(defcustom wat-ts-mode-indent-level 2
  "Number of spaces for each indententation step."
  :type 'integer
  :safe 'integerp)

(defvar wat-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?\( "()1nb" table) ; (; .. ;)
    (modify-syntax-entry ?\) ")(4nb" table)
    (modify-syntax-entry ?\; "< 123" table)
    (modify-syntax-entry ?\n ">b" table)
    table))

(defvar wat-ts-mode--indent-rules
  `((wat
     ((parent-is "ROOT") parent 0)
     ((node-is ")") parent-bol 0)
     ((node-is "end") parent-bol 0)
     ((parent-is "module_field") parent-bol wat-ts-mode-indent-level)
     ((parent-is "instr_list") first-sibling 0)
     (no-node parent-bol wat-ts-mode-indent-level)
     (catch-all parent-bol wat-ts-mode-indent-level)))
  "Tree-sitter indentation rules for wat.")

(defvar wat-ts-mode--keywords
  '(
    "elem"
    "export"
    "module"
    "memory"
    "data"
    "table"
    "func"
    "block"
    "end"
    "result"
    "param"
    "type"
    "loop"
    "import"
    ;; "return"
    ))

(defvar wat-ts-mode--builtins
  '())

;;; func: funcref anyfunc??
;;; number: i32 i64 f32 f64
;;; global: mut
(defvar wat-ts-mode--types
  '())

;;; TODO: separate wat/wast, types, keywords
(defvar wat-ts-mode---keywords
  '("array" "assert_exception" "assert_exhaustion" "assert_invalid" "assert_malformed"
    "assert_return" "assert_trap" "assert_unlinkable" "atomic.fence" "binary" "block" "br"
    "br_if" "br_table" "call" "call_indirect" "call_ref" "catch" "catch_all" "data"
    "data.drop" "declare" "delegate" "do" "drop" "either" "elem" "elem.drop" "else" "end"
    "export" "extern" "externref" "f32" "f32.abs" "f32.add" "f32.ceil" "f32.const"
    "f32.convert_i32_s" "f32.convert_i32_u" "f32.convert_i64_s" "f32.convert_i64_u"
    "f32.copysign" "f32.demote_f64" "f32.div" "f32.eq" "f32.floor" "f32.ge" "f32.gt"
    "f32.le" "f32.load" "f32.lt" "f32.max" "f32.min" "f32.mul" "f32.ne" "f32.nearest"
    "f32.neg" "f32.reinterpret_i32" "f32.sqrt" "f32.store" "f32.sub" "f32.trunc" "f32x4"
    "f32x4.abs" "f32x4.add" "f32x4.ceil" "f32x4.convert_i32x4_s" "f32x4.convert_i32x4_u"
    "f32x4.demote_f64x2_zero" "f32x4.div" "f32x4.eq" "f32x4.extract_lane" "f32x4.floor"
    "f32x4.ge" "f32x4.gt" "f32x4.le" "f32x4.lt" "f32x4.max" "f32x4.min" "f32x4.mul"
    "f32x4.ne" "f32x4.nearest" "f32x4.neg" "f32x4.pmax" "f32x4.pmin" "f32x4.relaxed_madd"
    "f32x4.relaxed_max" "f32x4.relaxed_min" "f32x4.relaxed_nmadd" "f32x4.replace_lane"
    "f32x4.splat" "f32x4.sqrt" "f32x4.sub" "f32x4.trunc" "f64" "f64.abs" "f64.add"
    "f64.ceil" "f64.const" "f64.convert_i32_s" "f64.convert_i32_u" "f64.convert_i64_s"
    "f64.convert_i64_u" "f64.copysign" "f64.div" "f64.eq" "f64.floor" "f64.ge" "f64.gt"
    "f64.le" "f64.load" "f64.lt" "f64.max" "f64.min" "f64.mul" "f64.ne" "f64.nearest"
    "f64.neg" "f64.promote_f32" "f64.reinterpret_i64" "f64.sqrt" "f64.store" "f64.sub"
    "f64.trunc" "f64x2" "f64x2.abs" "f64x2.add" "f64x2.ceil" "f64x2.convert_low_i32x4_s"
    "f64x2.convert_low_i32x4_u" "f64x2.div" "f64x2.eq" "f64x2.extract_lane" "f64x2.floor"
    "f64x2.ge" "f64x2.gt" "f64x2.le" "f64x2.lt" "f64x2.max" "f64x2.min" "f64x2.mul"
    "f64x2.ne" "f64x2.nearest" "f64x2.neg" "f64x2.pmax" "f64x2.pmin"
    "f64x2.promote_low_f32x4" "f64x2.relaxed_madd" "f64x2.relaxed_max" "f64x2.relaxed_min"
    "f64x2.relaxed_nmadd" "f64x2.replace_lane" "f64x2.splat" "f64x2.sqrt" "f64x2.sub"
    "f64x2.trunc" "field" "func" "funcref" "get" "global" "global.get" "global.set" "i16x8"
    "i16x8.abs" "i16x8.add" "i16x8.add_sat_s" "i16x8.add_sat_u" "i16x8.all_true"
    "i16x8.avgr_u" "i16x8.bitmask" "i16x8.dot_i8x16_i7x16_s" "i16x8.eq"
    "i16x8.extadd_pairwise_i8x16_s" "i16x8.extadd_pairwise_i8x16_u"
    "i16x8.extend_high_i8x16_s" "i16x8.extend_high_i8x16_u" "i16x8.extend_low_i8x16_s"
    "i16x8.extend_low_i8x16_u" "i16x8.extmul_high_i8x16_s" "i16x8.extmul_high_i8x16_u"
    "i16x8.extmul_low_i8x16_s" "i16x8.extmul_low_i8x16_u" "i16x8.extract_lane_s"
    "i16x8.extract_lane_u" "i16x8.ge_s" "i16x8.ge_u" "i16x8.gt_s" "i16x8.gt_u" "i16x8.le_s"
    "i16x8.le_u" "i16x8.lt_s" "i16x8.lt_u" "i16x8.max_s" "i16x8.max_u" "i16x8.min_s"
    "i16x8.min_u" "i16x8.mul" "i16x8.narrow_i32x4_s" "i16x8.narrow_i32x4_u" "i16x8.ne"
    "i16x8.neg" "i16x8.q15mulr_sat_s" "i16x8.relaxed_laneselect" "i16x8.relaxed_q15mulr_s"
    "i16x8.replace_lane" "i16x8.shl" "i16x8.shr_s" "i16x8.shr_u" "i16x8.splat" "i16x8.sub"
    "i16x8.sub_sat_s" "i16x8.sub_sat_u" "i32" "i32.add" "i32.and" "i32.atomic.load"
    "i32.atomic.load16_u" "i32.atomic.load8_u" "i32.atomic.rmw.add" "i32.atomic.rmw.and"
    "i32.atomic.rmw.cmpxchg" "i32.atomic.rmw.or" "i32.atomic.rmw.sub" "i32.atomic.rmw.xchg"
    "i32.atomic.rmw.xor" "i32.atomic.rmw16.add_u" "i32.atomic.rmw16.and_u"
    "i32.atomic.rmw16.cmpxchg_u" "i32.atomic.rmw16.or_u" "i32.atomic.rmw16.sub_u"
    "i32.atomic.rmw16.xchg_u" "i32.atomic.rmw16.xor_u" "i32.atomic.rmw8.add_u"
    "i32.atomic.rmw8.and_u" "i32.atomic.rmw8.cmpxchg_u" "i32.atomic.rmw8.or_u"
    "i32.atomic.rmw8.sub_u" "i32.atomic.rmw8.xchg_u" "i32.atomic.rmw8.xor_u"
    "i32.atomic.store" "i32.atomic.store16" "i32.atomic.store8" "i32.clz" "i32.const"
    "i32.ctz" "i32.div_s" "i32.div_u" "i32.eq" "i32.eqz" "i32.extend16_s" "i32.extend8_s"
    "i32.ge_s" "i32.ge_u" "i32.gt_s" "i32.gt_u" "i32.le_s" "i32.le_u" "i32.load"
    "i32.load16_s" "i32.load16_u" "i32.load8_s" "i32.load8_u" "i32.lt_s" "i32.lt_u"
    "i32.mul" "i32.ne" "i32.or" "i32.popcnt" "i32.reinterpret_f32" "i32.rem_s" "i32.rem_u"
    "i32.rotl" "i32.rotr" "i32.shl" "i32.shr_s" "i32.shr_u" "i32.store" "i32.store16"
    "i32.store8" "i32.sub" "i32.trunc_f32_s" "i32.trunc_f32_u" "i32.trunc_f64_s"
    "i32.trunc_f64_u" "i32.trunc_sat_f32_s" "i32.trunc_sat_f32_u" "i32.trunc_sat_f64_s"
    "i32.trunc_sat_f64_u" "i32.wrap_i64" "i32.xor" "i32x4" "i32x4.abs" "i32x4.add"
    "i32x4.all_true" "i32x4.bitmask" "i32x4.dot_i16x8_s" "i32x4.dot_i8x16_i7x16_add_s"
    "i32x4.eq" "i32x4.extadd_pairwise_i16x8_s" "i32x4.extadd_pairwise_i16x8_u"
    "i32x4.extend_high_i16x8_s" "i32x4.extend_high_i16x8_u" "i32x4.extend_low_i16x8_s"
    "i32x4.extend_low_i16x8_u" "i32x4.extmul_high_i16x8_s" "i32x4.extmul_high_i16x8_u"
    "i32x4.extmul_low_i16x8_s" "i32x4.extmul_low_i16x8_u" "i32x4.extract_lane" "i32x4.ge_s"
    "i32x4.ge_u" "i32x4.gt_s" "i32x4.gt_u" "i32x4.le_s" "i32x4.le_u" "i32x4.lt_s"
    "i32x4.lt_u" "i32x4.max_s" "i32x4.max_u" "i32x4.min_s" "i32x4.min_u" "i32x4.mul"
    "i32x4.ne" "i32x4.neg" "i32x4.relaxed_laneselect" "i32x4.relaxed_trunc_f32x4_s"
    "i32x4.relaxed_trunc_f32x4_u" "i32x4.relaxed_trunc_f64x2_s_zero"
    "i32x4.relaxed_trunc_f64x2_u_zero" "i32x4.replace_lane" "i32x4.shl" "i32x4.shr_s"
    "i32x4.shr_u" "i32x4.splat" "i32x4.sub" "i32x4.trunc_sat_f32x4_s"
    "i32x4.trunc_sat_f32x4_u" "i32x4.trunc_sat_f64x2_s_zero" "i32x4.trunc_sat_f64x2_u_zero"
    "i64" "i64.add" "i64.and" "i64.atomic.load" "i64.atomic.load16_u" "i64.atomic.load32_u"
    "i64.atomic.load8_u" "i64.atomic.rmw.add" "i64.atomic.rmw.and" "i64.atomic.rmw.cmpxchg"
    "i64.atomic.rmw.or" "i64.atomic.rmw.sub" "i64.atomic.rmw.xchg" "i64.atomic.rmw.xor"
    "i64.atomic.rmw16.add_u" "i64.atomic.rmw16.and_u" "i64.atomic.rmw16.cmpxchg_u"
    "i64.atomic.rmw16.or_u" "i64.atomic.rmw16.sub_u" "i64.atomic.rmw16.xchg_u"
    "i64.atomic.rmw16.xor_u" "i64.atomic.rmw32.add_u" "i64.atomic.rmw32.and_u"
    "i64.atomic.rmw32.cmpxchg_u" "i64.atomic.rmw32.or_u" "i64.atomic.rmw32.sub_u"
    "i64.atomic.rmw32.xchg_u" "i64.atomic.rmw32.xor_u" "i64.atomic.rmw8.add_u"
    "i64.atomic.rmw8.and_u" "i64.atomic.rmw8.cmpxchg_u" "i64.atomic.rmw8.or_u"
    "i64.atomic.rmw8.sub_u" "i64.atomic.rmw8.xchg_u" "i64.atomic.rmw8.xor_u"
    "i64.atomic.store" "i64.atomic.store16" "i64.atomic.store32" "i64.atomic.store8"
    "i64.clz" "i64.const" "i64.ctz" "i64.div_s" "i64.div_u" "i64.eq" "i64.eqz"
    "i64.extend16_s" "i64.extend32_s" "i64.extend8_s" "i64.extend_i32_s" "i64.extend_i32_u"
    "i64.ge_s" "i64.ge_u" "i64.gt_s" "i64.gt_u" "i64.le_s" "i64.le_u" "i64.load"
    "i64.load16_s" "i64.load16_u" "i64.load32_s" "i64.load32_u" "i64.load8_s" "i64.load8_u"
    "i64.lt_s" "i64.lt_u" "i64.mul" "i64.ne" "i64.or" "i64.popcnt" "i64.reinterpret_f64"
    "i64.rem_s" "i64.rem_u" "i64.rotl" "i64.rotr" "i64.shl" "i64.shr_s" "i64.shr_u"
    "i64.store" "i64.store16" "i64.store32" "i64.store8" "i64.sub" "i64.trunc_f32_s"
    "i64.trunc_f32_u" "i64.trunc_f64_s" "i64.trunc_f64_u" "i64.trunc_sat_f32_s"
    "i64.trunc_sat_f32_u" "i64.trunc_sat_f64_s" "i64.trunc_sat_f64_u" "i64.xor" "i64x2"
    "i64x2.abs" "i64x2.add" "i64x2.all_true" "i64x2.bitmask" "i64x2.eq"
    "i64x2.extend_high_i32x4_s" "i64x2.extend_high_i32x4_u" "i64x2.extend_low_i32x4_s"
    "i64x2.extend_low_i32x4_u" "i64x2.extmul_high_i32x4_s" "i64x2.extmul_high_i32x4_u"
    "i64x2.extmul_low_i32x4_s" "i64x2.extmul_low_i32x4_u" "i64x2.extract_lane" "i64x2.ge_s"
    "i64x2.gt_s" "i64x2.le_s" "i64x2.lt_s" "i64x2.mul" "i64x2.ne" "i64x2.neg"
    "i64x2.relaxed_laneselect" "i64x2.replace_lane" "i64x2.shl" "i64x2.shr_s" "i64x2.shr_u"
    "i64x2.splat" "i64x2.sub" "i8x16" "i8x16.abs" "i8x16.add" "i8x16.add_sat_s"
    "i8x16.add_sat_u" "i8x16.all_true" "i8x16.avgr_u" "i8x16.bitmask" "i8x16.eq"
    "i8x16.extract_lane_s" "i8x16.extract_lane_u" "i8x16.ge_s" "i8x16.ge_u" "i8x16.gt_s"
    "i8x16.gt_u" "i8x16.le_s" "i8x16.le_u" "i8x16.lt_s" "i8x16.lt_u" "i8x16.max_s"
    "i8x16.max_u" "i8x16.min_s" "i8x16.min_u" "i8x16.narrow_i16x8_s" "i8x16.narrow_i16x8_u"
    "i8x16.ne" "i8x16.neg" "i8x16.popcnt" "i8x16.relaxed_laneselect"
    "i8x16.relaxed_swizzle" "i8x16.replace_lane" "i8x16.shl" "i8x16.shr_s" "i8x16.shr_u"
    "i8x16.shuffle" "i8x16.splat" "i8x16.sub" "i8x16.sub_sat_s" "i8x16.sub_sat_u"
    "i8x16.swizzle" "if" "import" "input" "invoke" "item" "local" "local.get" "local.set"
    "local.tee" "loop" "memory" "memory.atomic.notify" "memory.atomic.wait32"
    "memory.atomic.wait64" "memory.copy" "memory.fill" "memory.grow" "memory.init"
    "memory.size" "module" "mut" "nan:arithmetic" "nan:canonical" "nop" "offset" "output"
    "param" "quote" "ref" "ref.extern" "ref.func" "ref.is_null" "ref.null" "register"
    "result" "rethrow" "return" "return_call" "return_call_indirect" "select" "shared"
    "start" "struct" "table" "table.copy" "table.fill" "table.get" "table.grow"
    "table.init" "table.set" "table.size" "tag" "then" "throw" "try" "type" "unreachable"
    "v128" "v128.and" "v128.andnot" "v128.any_true" "v128.bitselect" "v128.const"
    "v128.load" "v128.load16_lane" "v128.load16_splat" "v128.load16x4_s" "v128.load16x4_u"
    "v128.load32_lane" "v128.load32_splat" "v128.load32_zero" "v128.load32x2_s"
    "v128.load32x2_u" "v128.load64_lane" "v128.load64_splat" "v128.load64_zero"
    "v128.load8_lane" "v128.load8_splat" "v128.load8x8_s" "v128.load8x8_u" "v128.not"
    "v128.or" "v128.store" "v128.store16_lane" "v128.store32_lane" "v128.store64_lane"
    "v128.store8_lane" "v128.xor"))

(defvar wat-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'wat
   :feature 'comment
   '([(comment_line) (comment_block)] @font-lock-comment-face)

   :language 'wat
   :feature 'string
   '((string) @font-lock-string-face)
   
   :language 'wat
   :feature 'number
   '([(nat) (float) (nan)] @font-lock-number-face)

   :language 'wat
   :feature 'type
   '([(value_type) (ref_type) (ref_kind) (elem_kind)] @font-lock-type-face
     (global_type_mut "mut" @font-lock-type-face))

   :language 'wat
   :feature 'definition
   '((module
      identifier: (identifier) @font-lock-function-name-face)

     (module_field_func
      identifier: (identifier) @font-lock-function-name-face)

     ;; (import_desc_func_type (identifier) @font-lock-function-name-face)
     ;; (import_desc_type_use (identifier) @font-lock-function-name-face)
     
     (identifier) @font-lock-variable-name-face

     ;; (module_field_type
     ;;  identifier: (identifier) @font-lock-variable-name-face)

     ;; (module_field_table
     ;;  identifier: (identifier) @font-lock-variable-name-face)

     ;; (module_field_memory
     ;;  identifier: (identifier) @font-lock-variable-name-face)

     ;; (module_field_global
     ;;  identifier: (identifier) @font-lock-variable-name-face)

     ;; (import_desc_func_type (identifier) @font-lock-variable-name-face)

     ;; (index (identifier) @font-lock-variable-name-face)
     )
   
   :language 'wat
   :feature 'keyword
   `([,@wat-ts-mode--keywords] @font-lock-keyword-face
     (module_field_elem
      ["elem" "declare"] @font-lock-keyword-face))

   :language 'wat
   :feature 'instruction
   '([(pat00) (pat01)] @font-lock-builtin-face
     (instr_list_call "call_indirect" @font-lock-builtin-face) 
     (instr_plain
      [(_) "ref.null" "table.init"] @font-lock-builtin-face))
     
   :language 'wat
   :feature 'bracket
   '(("(" ")") @font-lock-bracket-face)

   :language 'wat
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face)
   )
  "Tree-sitter font-lock settings for wat.")

;;;###autoload
(define-derived-mode wat-ts-mode prog-mode "Wat"
  "Major mode for editing wat buffers.

\\<wat-ts-mode-map>"
  :group 'wat
  :syntax-table wat-ts-mode--syntax-table
  (when (treesit-ready-p 'wat)
    (treesit-parser-create 'wat))

  (setq-local comment-start ";; ")
  (setq-local comment-end "")
  (setq-local comment-start-skip (rx ";;" (* (syntax whitespace))))
  
  ;; Indentation
  (setq-local treesit-simple-indent-rules wat-ts-mode--indent-rules)

  ;; Font-Locking
  (setq-local treesit-font-lock-settings wat-ts-mode--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '(( comment string definition)
                ( keyword type variable instruction)
                ( constant number escape-sequence)
                ( bracket operator error)))
  
  ;; Imenu
  ;; (setq-local treesit-simple-imenu-settings
  ;;             `(("Function" "\\`function_definition\\'" nil nil))

  ;; Navigation
  ;; (setq-local treesit-defun-type-regexp
  ;;             (rx string-start (or "function_definition") string-end))
  ;; (setq-local treesit-defun-name-function #'wat-ts-mode--defun-name)
  (setq-local treesit-text-type-regexp (rx (or "comment_line" "comment_block" "string")))
  ;; (setq-local treesit-sentence-type-regexp
  ;;             (rx (or wat-ts-mode--treesit-sentence-nodes)))
  ;; (setq-local treesit-sexp-type-regexp (rx (or wat-ts-mode--treesit-sexp-nodes)))
  ;; (setq-local treesit-defun-prefer-top-level t)

  (treesit-major-mode-setup))

(if (treesit-ready-p 'wat)
    (add-to-list 'auto-mode-alist '("\\.\\(?:wa\\(?:s?t\\)\\)\\'" . wat-ts-mode)))

;; -------------------------------------------------------------------
;;; Wast

(defvar wast-ts-mode--commands
  '(
    "action"
    "assert_invalid"
    "assert_malformed"
    "assert_return"
    "assert_invalid"
    ;; "assert_return_arithmetic_nan"
    ;; "assert_return_canonical_nan"
    ;; "assert_trap"
    "assert_unlinkable"
    "assert_uninstantiable"
    "assert_exhaustion"
    "assert_exception"
    ;; "assertion:"
    "binary"
    "get"
    "input"
    "invoke"
    ;; "meta:"
    ;; "module:"
    "module"
    "output"
    "quote"
    "register"
    ;; "script:"
    ))

(provide 'wat-ts-mode)
;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:
;;; wat-ts-mode.el ends here
