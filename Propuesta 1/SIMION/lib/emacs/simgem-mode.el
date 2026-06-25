;; simgem-mode.el - SIMION GEM major mode for Emacs (GNU+XEmacs)
;;
;; David Manura (c) 2003-2004 Scientific Instrument Services, Inc.
;; $Revision$ $Date$ Created 2004-04.
;;
;; $Date$
;; Related resources:
;;   php-mode.el (a related approach)
;;   http://two-wugs.net/emacs/mode-tutorial.html

(require 'font-lock)
(require 'regexp-opt)

; Build file revision number
(defconst simgem-version (nth 1 (split-string "$Revision$" " "))
  "GEM mode version number."
)

;; Local variables
(defgroup simgem nil
  "Major mode for editing GEM code."
  :prefix "simgem-"
  :group 'languages
)

;; Make simgem-mode the default mode for GEM buffers.
(add-to-list 'auto-mode-alist '("\\.gem\\'" . simgem-mode))


;;;###autoload
(define-derived-mode simgem-mode fundamental-mode "SIMGEM"
  "Major mode for editing GEM code.\n\n\\{simgem-mode-map}"
  
  (defvar sungem-mode-syntax-table simgem-mode-syntax-table)
  ;; underscore is part of token
  (modify-syntax-entry ?_ "w" simgem-mode-syntax-table)

  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults
    '(
      (simgem-font-lock-keywords-1)
      nil    ; KEYWORDS-ONLY
      T      ; CASE-FOLD
      nil    ; SYNTAX-ALIST
      nil    ; SYNTAX-BEGIN
    )
  )

  (font-lock-mode)
)

;; Define shortcut
;;(define-key simgem-mode-map
;;  "\C-c\C-f"
;;  'simgem-zzz
;;)

;; Define abbreviations
;;(define-abbrev simgem-mode-abbrev-table "ret" "return")

;; Define identifiers
(defconst simgem-identifier
  (eval-when-compile '"[\_a-zA-Z][\_a-zA-Z0-9]*")
  "GEM identifier."
)

;; Define types
(defconst simgem-types
  (eval-when-compile
    (regexp-opt '("pa_define") t)
  )
  "GEM types."
)

;; Define keywords
(defconst simgem-keywords
  (eval-when-compile
    (regexp-opt
      '(
        "include" "include_file"
      )
      t
    )
  )
)

;; Define segments
(defconst simgem-segments
  (eval-when-compile
    (regexp-opt
      '(
      )
      t
    )
  )
)

;; Define constants
(defconst simgem-constants
  (eval-when-compile
    (regexp-opt
      '(
        "cylindrical" "planar"
        "none" "x" "y" "z" "xy" "yz" "xz" "xzy"
        "electrostatic"
        "magnetic"
      )
    t)
  )
  "GEM constants."
)

;; Define built-in identifiers
(defconst simgem-builtin-identifiers
  (eval-when-compile
    (regexp-opt
      '(
        "box" "box2d"
        "box3d"
        "centered_box" "centered_box2d" "cent_box" "cent_box2d"
        "centered_box3d" "cent_box3d"
        "circle" "ellipse"
        "corner_box" "corner_box2d" "corn_box" "corn_box2d"
        "corner_box3d" "corn_box3d"
        "cylinder"
        "edge_fill" "edge_fill_volume"
        "electrode" "e" "p" "elect" "pole" 
            "electrode_points" "pole_points"
        "fill" "fill_volume"
        "hyperbola"
        "locate" "project" "project_it" "transform"
        "non_electrode" "n" "non_e" "non_p" "non_pole"
            "non_electrode_points" "non_pole_points"
        "notin"
        "notin_inside"
        "notin_inside_or_on"
        "parabola"
        "points2d"
        "points3d"
        "polyline"
        "rotate_edge_fill"
        "rotate_fill" "rotate_fill_volume"
        "sphere" "ellipsoid"
        "within"
        "within_inside"
        "within_inside_or_on"
      )
      t
    )
  )
)
  
;; Detect common errors
(defconst simgem-errors
  (eval-when-compile
    (regexp-opt '()
     t)
  )
  "GEM types."
)


;; Confiure font locking
(defconst simgem-font-lock-keywords-1
  (list

    (cons
      (concat "\\<\\(" simgem-errors "\\)\\>")
      'font-lock-warning-face
    )
    (cons
      ";.*"
      'font-lock-comment-face
    )
    (cons
      (concat "\\<\\(" simgem-keywords "\\)\\>")
      'font-lock-keyword-face
    )
    (cons
      (concat "\\<\\(" simgem-segments "\\)\\>")
      'font-lock-constant-face
    )
    (cons
      (concat "\\<\\(" simgem-builtin-identifiers "\\)\\>")
      'font-lock-builtin-face
    )
    (cons
      (concat "\\<\\(" simgem-types "\\)\\>")
      'font-lock-type-face
    )
    (cons
      (concat "\\<\\(" simgem-constants "\\)\\>")
      'font-lock-constant-face
    )
    (cons
      (concat "\\<\\(" simgem-identifier "\\)\\>")
      'font-lock-variable-name-face
    )
  )

  "Syntax highlighting for GEM mode."
)


(provide 'simgem-mode)
