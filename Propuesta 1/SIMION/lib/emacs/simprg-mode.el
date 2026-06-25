;; simprg-mode.el - SIMION PRG major mode for Emacs (GNU+XEmacs)
;;
;; David Manura (c) 2003-2004 Scientific Instrument Services, Inc.
;; $Revision$ $Date$ Created 2004-04.
;;
;; Related resources:
;;   php-mode.el (a related approach)
;;   http://two-wugs.net/emacs/mode-tutorial.html

(require 'font-lock)
(require 'regexp-opt)

; Build file revision number
(defconst simprg-version (nth 1 (split-string "$Revision$" " "))
  "PRG mode version number."
)

;; Local variables
(defgroup simprg nil
  "Major mode for editing PRG code."
  :prefix "simprg-"
  :group 'languages
)

;; Make simprg-mode the default mode for PRG buffers.
(add-to-list 'auto-mode-alist '("\\.prg\\'" . simprg-mode))


;;;###autoload
(define-derived-mode simprg-mode fundamental-mode "SIMPRG"
  "Major mode for editing PRG code.\n\n\\{simprg-mode-map}"
  
  (defvar sunprg-mode-syntax-table simprg-mode-syntax-table)
  ;; underscore is part of token
  (modify-syntax-entry ?_ "w" simprg-mode-syntax-table)

  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults
    '(
      (simprg-font-lock-keywords-1)
      nil    ; KEYWORDS-ONLY
      T      ; CASE-FOLD
      nil    ; SYNTAX-ALIST
      nil    ; SYNTAX-BEGIN
    )
  )

  (font-lock-mode)
)

;; Define function for browsing SIMION web site
(defun simion-website ()
  "Open SIMION web site."
  (interactive)
  (browse-url "http://www.simion.com/")
)

;; Define shortcut
;;(define-key simprg-mode-map
;;  "\C-c\C-f"
;;  'simprg-zzz
;;)

;; Define abbreviations
;;(define-abbrev simprg-mode-abbrev-table "ret" "return")

;; Define identifiers
(defconst simprg-identifier
  (eval-when-compile '"[\_a-zA-Z][\_a-zA-Z0-9]*")
  "PRG identifier."
)

;; Define types
(defconst simprg-types
  (eval-when-compile
    (regexp-opt '("defa" "defs") t)
  )
  "PRG types."
)

;; Define keywords
(defconst simprg-keywords
  (eval-when-compile
    (regexp-opt
      '(
        ;; SIMION opcodes
        "+" "ADD"
        "-" "SUBTRACT"
        "*" "MULTIPLY"
        "/" "DIVIDE"
        "1/X" "RECIPROCAL_OF_X"
        "10^X" "10_TO_THE_X"
        ">ARR" "PA_COORDS_To_ARRAY_COORDS"
        ">AZR" "AZIMUTH_ROTATE"
        ">DEG" "RADIANS_TO_DEGREES"
        ">ELR" "ELEVATION_ROTATE"
        ">KE" "SPEED_TO_KINETIC_ENERGY"
        ">P" "RECT_TO_POLAR"
        ">P3D" "RECT3D_TO_POLAR3D"
        ">PAC" "WB_COORDS_TO_PA_COORDS"
        ">PAO" "WB_ORIENT_TO_PA_ORIENT"
        ">R" "POLAR_TO_RECT"
        ">R3D" "POLAR3D_TO_RECT3D"
        ">RAD" "DEGREES_TO_RADIANS"
        ">SPD" "KINETIC_ENERGY_TO_SPEED"
        ">WBC" "PA_COORDS_TO_WB_COORDS"
        ">WBO" "PA_ORIENT_TO_WB_ORIENT"
        "ABS" "ABSOLUTE_VALUE"
        "ACOS" "ARC_COSINE"
        "ALOAD" "ARRAY_LOAD"
        "ARCL" "ARRAY_RECALL"
        "ASAVE" "ARRAY_SAVE"
        "ASIN" "ARC_SINE"
        "ASTO" "ARRAY_STORE"
        "ATAN" "ARC_TANGENT"
        "BEEP" "BEEP_SOUND"
        "BELL" "RING_BELL"
        "CHS" "CHANGE_SIGN"
        "CLICK" "CLICK_SOUND"
        "COS" "COSINE"
        "E^X" "E_TO_THE_X"
        "ENTR" "ENTER" "DUPLICATE_X"
        "EXIT"
        "FRAC" "DECIMAL_FRACTION"
        "GSB" "GOSUB" "GO_SUBROUTINE"
        "GTO" "GOTO" "GO_TO"
        "INT" "INTEGER"
        "KEY?" "CHECK_FOR_KEY_INPUT"
        "LBL" "LABEL" "ENTRY" "SUBROUTINE"
        "LN" "NATURAL_LOG"
        "LOG" "BASE_10_LOG"
        "MARK" "MARK_ALL_IONS"
        "MESS" "MESSAGE"
        "NINT" "NEAREST_INTEGER"
        "NOP"
        "R/S" "RUN/STOP"
        "RAND" "RANDOM_NUMBER"
        "RCL" "RECALL"
        "REDRAW" "REDRAW_SCREEN"
        "RLDN" "ROLL_REGISTER_POINTER_DOWN"
        "RLUP" "ROLL_REGISTER_POINTER_UP"
        "RTN" "RETURN" "RETURN_FROM_SUBROUTINE"
        "SEED" "RANDOM_SEED"
        "SEG" "BEGIN_SEGMENT"
        "SIN" "SINE"
        "SQRT" "SQUARE_ROOT"
        "STO" "STORE"
        "TAN" "TANGENT"
        "X><Y" "X<>Y" "XY_SWAP" "SWAP_XY"
        "X=0"  "IF_X_EQ_0" "IF_X_EQUALS_0"
        "X!=0" "IF_X_NE_0" "IF_X_NOT_EQUAL_0"
        "X<0"  "IF_X_LT_0" "IF_X_LESS_THEN_0"
        "X<=0" "IF_X_LE_0" "IF_X_LESS_THAN_OR_EQUAL_0"
        "X>0"  "IF_X_GT_0" "IF_X_GREATER_THAN_0"
        "X>=0" "IF_X_GE_0" "IF_X_GREATER_THAN_OR_EQUAL_0"
        "X=Y"  "IF_X_EQ_0" "IF_X_EQUALS_Y"
        "X!=Y" "IF_X_NE_0" "IF_X_NOT_EQUAL_Y"
        "X<Y"  "IF_X_LT_0" "IF_X_LESS_THEN_Y"
        "X<=Y" "IF_X_LE_0" "IF_X_LESS_THAN_OR_EQUAL_Y"
        "X>Y"  "IF_X_GT_0" "IF_X_GREATER_THAN_Y"
        "X>=Y" "IF_X_GE_0" "IF_X_GREATER_THAN_OR_EQUAL_Y"
      )
      t
    )
  )
)

;; Define segments
(defconst simprg-segments
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
(defconst simprg-constants
  (eval-when-compile
    (regexp-opt '() t)
  )
  "PRG constants."
)

;; Define built-in identifiers
(defconst simprg-builtin-identifiers
  (eval-when-compile
    (concat
    (regexp-opt
      '(
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
(defconst simprg-errors
  (eval-when-compile
    (regexp-opt '()
     t)
  )
  "PRG types."
)


;; Confiure font locking
(defconst simprg-font-lock-keywords-1
  (list

    (cons
      (concat "\\<\\(" simprg-errors "\\)\\>")
      'font-lock-warning-face
    )
    (cons
      ";.*"
      'font-lock-comment-face
    )
    (cons
      (concat "\\<\\(" simprg-keywords "\\)\\>")
      'font-lock-keyword-face
    )
    (cons
      (concat "\\<\\(" simprg-segments "\\)\\>")
      'font-lock-constant-face
    )
    (cons
      (concat "\\<\\(" simprg-builtin-identifiers "\\)\\>")
      'font-lock-builtin-face
    )
    (cons
      (concat "\\<\\(" simprg-types "\\)\\>")
      'font-lock-type-face
    )
    (cons
      (concat "\\<\\(" simprg-constants "\\)\\>")
      'font-lock-constant-face
    )
    (cons
      (concat "\\<\\(" simprg-identifier "\\)\\>")
      'font-lock-variable-name-face
    )
  )

  "Syntax highlighting for PRG mode."
)


(provide 'simprg-mode)
