;; simsl-mode.el - SIMION SL major mode for Emacs (GNU+XEmacs)
;;
;; David Manura (c) 2003-2004 Scientific Instrument Services, Inc.
;; $Revision$ $Date$ Created 2004-04.
;; Related resources:
;;   php-mode.el (a related approach)
;;   http://two-wugs.net/emacs/mode-tutorial.html

(require 'font-lock)
(require 'regexp-opt)

; Build file revision number
(defconst simsl-version (nth 1 (split-string "$Revision$" " "))
  "SL mode version number."
)

;; Local variables
(defgroup simsl nil
  "Major mode for editing SL code."
  :prefix "simsl-"
  :group 'languages
)

;; Make simsl-mode the default mode for SL buffers.
(add-to-list 'auto-mode-alist '("\\.sl\\'" . simsl-mode))


;;;###autoload
(define-derived-mode simsl-mode fundamental-mode "SIMSL"
  "Major mode for editing SL code.\n\n\\{simsl-mode-map}"
  
  (defvar sunsl-mode-syntax-table simsl-mode-syntax-table)
  ;; underscore is part of token
  (modify-syntax-entry ?_ "w" simsl-mode-syntax-table)

  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults
    '(
      (simsl-font-lock-keywords-1)
      nil    ; KEYWORDS-ONLY
      T      ; CASE-FOLD
      nil    ; SYNTAX-ALIST
      nil    ; SYNTAX-BEGIN
    )
  )

  (font-lock-mode)
)

;; Define function for browsing SL web site
(defun simsl-website ()
  "Open SL web site."
  (interactive)
  (browse-url "http://www.simion.com/sl")
)

;; Define shortcut
;;(define-key simsl-mode-map
;;  "\C-c\C-f"
;;  'simsl-zzz
;;)

;; Define abbreviations
(define-abbrev simsl-mode-abbrev-table "ret" "return")

;; Define identifiers
(defconst simsl-identifier
  (eval-when-compile '"[\_a-zA-Z][\_a-zA-Z0-9]*")
  "SL identifier."
)

;; Define types
(defconst simsl-types
  (eval-when-compile
    (regexp-opt '("adjustable" "static") t)
  )
  "SL types."
)

;; Define keywords
(defconst simsl-keywords
  (eval-when-compile
    (regexp-opt
      '("for" "endfor" "to" "step"
        "if" "endif" "else" "elseif"
        "while" "endwhile"
        "declaresub" "sub" "endsub"
        "exit" "or" "and" "not"
        "returns" "remote" "import"
      )
      t
    )
  )
)

;; Define segments
(defconst simsl-segments
  (eval-when-compile
    (regexp-opt
      '(
        "initialize"
        "init_p_values"
        "tstep_adjust"
        "fast_adjust"
        "efield_adjust"
        "mfield_adjust"
        "accel_adjust"
        "other_actions"
        "terminate"
      )
      t
    )
  )
)

;; Define constants
(defconst simsl-constants
  (eval-when-compile
    (regexp-opt '() t)
  )
  "SL constants."
)

;; Define built-in identifiers
(defconst simsl-builtin-identifiers
  (eval-when-compile
    (concat
    (regexp-opt
      '(
        ;; SIMION functions
        "pow10"
        "pa_coords_to_array_coords"
        "azimuth_rotate"
        "degrees"
        "elevation_rotate"
        "speed_to_ke"
        "rect_to_polar"
        "rect3d_to_polar3d"
        "wb_coords_to_pa_coords"
        "wb_orient_to_pa_orient"
        "polar_to_rect"
        "polar3d_to_rect3d"
        "radians"
        "ke_to_speed"
        "pa_coords_to_wb_coords"
        "pa_orient_to_wb_orient"
        "abs"
        "acos"
        "array_load"
        "array_save"
        "asin"
        "atan"
        "beep"
        "click"
        "cos"
        "exp"
        "frac"
        "int"
        "key"
        "ln"
        "log"
        "mark"
        "mess"
        "print"
        "nint"
        "nop"
        "run_stop"
        "rand"
        "redraw_screen"
        "seed"
        "sin"
        "sqrt"
        "tan"

        ;; utility functions
        "if"
        "min"
        "max"
        "floor"
        "ceil"

        ;; built-in vars
        "ion_ax_mm"
        "ion_ay_mm"
        "ion_az_mm"
        "ion_bfieldx_gu"
        "ion_bfieldy_gu"
        "ion_bfieldz_gu"
        "ion_bfieldx_mm"
        "ion_bfieldy_mm"
        "ion_bfieldz_mm"
        "ion_charge"
        "ion_color"
        "ion_dvoltsx_gu"
        "ion_dvoltsy_gu"
        "ion_dvoltsz_gu"
        "ion_dvoltsx_mm"
        "ion_dvoltsy_mm"
        "ion_dvoltsz_mm"
        "ion_instance"
        "ion_mass"
        "ion_mm_per_grid_unit"
        "ion_number"
        "ion_px_abs_gu"
        "ion_py_abs_gu"
        "ion_pz_abs_gu"
        "ion_px_gu"
        "ion_py_gu"
        "ion_pz_gu"
        "ion_px_mm"
        "ion_py_mm"
        "ion_pz_mm"
        "ion_splat"
        "ion_time_of_birth"
        "ion_time_of_flight"
        "ion_time_step"
        "ion_volts"
        "ion_vx_mm"
        "ion_vy_mm"
        "ion_vz_mm"
        "rerun_flym"
        "trajectory_image_control"
        "retain_changed_potentials"
        "update_pe_surface"
      )
      t
    )
    ;; more built-in vars
    "\\|adj_elect[0-9][0-9]"
    "\\|adj_pole[0-9][0-9]"
    )
  )
)
  
;; Detect common errors
(defconst simsl-errors
  (eval-when-compile
    (regexp-opt '(
      "end for"
      "end if"
      "else if"
      "end while"
      "declare sub"
      "end sub"
     )
     t)
  )
  "SL types."
)


;; Confiure font locking
(defconst simsl-font-lock-keywords-1
  (list

    (cons
      (concat "\\<\\(" simsl-errors "\\)\\>")
      'font-lock-warning-face
    )
    (cons
      "#.*"
      'font-lock-comment-face
    )
    (cons
      (concat "\\<\\(" simsl-keywords "\\)\\>")
      'font-lock-keyword-face
    )
    (cons
      (concat "\\<\\(" simsl-segments "\\)\\>")
      'font-lock-constant-face
    )
    (cons
      (concat "\\<\\(" simsl-builtin-identifiers "\\)\\>")
      'font-lock-builtin-face
    )
    (cons
      (concat "\\<\\(" simsl-types "\\)\\>")
      'font-lock-type-face
    )
    (cons
      (concat "\\<\\(" simsl-constants "\\)\\>")
      'font-lock-constant-face
    )
    (cons
      (concat "\\<\\(" simsl-identifier "\\)\\>")
      'font-lock-variable-name-face
    )
  )

  "Syntax highlighting for SL mode."
)


(provide 'simsl-mode)
