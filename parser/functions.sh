(defun yaml-font-lock-block-literals (bound)
  "Find lines within block literals.
Find the next line of the first (if any) block literal after point and
prior to BOUND.  Returns the beginning and end of the block literal
line in the match data, as consumed by `font-lock-keywords' matcher
functions.  The function begins by searching backwards to determine
whether or not the current line is within a block literal.  This could
be time-consuming in large buffers, so the number of lines searched is
artificially limitted to the value of
`yaml-block-literal-search-lines'."
  (if (eolp) (goto-char (1+ (point))))
  (unless (or (eobp) (>= (point) bound))
    (let ((begin (point))
          (end (min (1+ (point-at-eol)) bound)))
      (goto-char (point-at-bol))
      (while (and (looking-at yaml-blank-line-re) (not (bobp)))
        (forward-line -1))
      (let ((nlines yaml-block-literal-search-lines)
            (min-level (current-indentation)))
      (forward-line -1)
      (while (and (/= nlines 0)
                  (/= min-level 0)
                  (not (looking-at yaml-block-literal-re))
                  (not (bobp)))
        (set 'nlines (1- nlines))
        (unless (looking-at yaml-blank-line-re)
          (set 'min-level (min min-level (current-indentation))))
        (forward-line -1))
      (cond
       ((and (< (current-indentation) min-level)
             (looking-at yaml-block-literal-re))
          (goto-char end) (set-match-data (list begin end)) t)
         ((progn
            (goto-char begin)
            (re-search-forward (concat yaml-block-literal-re
                                       " *\\(.*\\)\n")
                               bound t))
          (set-match-data (nthcdr 2 (match-data))) t))))))

(defun yaml-syntactic-block-literals (bound)
  "Find quote characters within block literals.
Finds the first quote character within a block literal (if any) after
point and prior to BOUND.  Returns the position of the quote character
in the match data, as consumed by matcher functions in
`font-lock-syntactic-keywords'.  This allows the mode to treat ['\"]
characters in block literals as punctuation syntax instead of string
syntax, preventing unmatched quotes in block literals from painting
the entire buffer in `font-lock-string-face'."
  (let ((found nil))
    (while (and (not found)
                (/= (point) bound)
                (yaml-font-lock-block-literals bound))
      (let ((begin (match-beginning 0)) (end (match-end 0)))
        (goto-char begin)
        (cond
         ((re-search-forward "['\"]" end t) (setq found t))
         ((goto-char end)))))
    found))


;; Indentation and electric keys

(defun yaml-compute-indentation ()
  "Calculate the maximum sensible indentation for the current line."
  (save-excursion
    (beginning-of-line)
    (if (looking-at yaml-document-delimiter-re) 0
      (forward-line -1)
      (while (and (looking-at yaml-blank-line-re)
                  (> (point) (point-min)))
        (forward-line -1))
      (+ (current-indentation)
         (if (looking-at yaml-nested-map-re) yaml-indent-offset 0)
         (if (looking-at yaml-nested-sequence-re) yaml-indent-offset 0)
         (if (looking-at yaml-block-literal-re) yaml-indent-offset 0)))))

(defun yaml-indent-line ()
  "Indent the current line.
The first time this command is used, the line will be indented to the
maximum sensible indentation.  Each immediately subsequent usage will
back-dent the line by `yaml-indent-offset' spaces.  On reaching column
0, it will cycle back to the maximum sensible indentation."
  (interactive "*")
  (let ((ci (current-indentation))
        (cc (current-column))
        (need (yaml-compute-indentation)))
    (save-excursion
      (beginning-of-line)
      (delete-horizontal-space)
      (if (and (equal last-command this-command) (/= ci 0))
          (indent-to (* (/ (- ci 1) yaml-indent-offset) yaml-indent-offset))
        (indent-to need)))
      (if (< (current-column) (current-indentation))
          (forward-to-indentation 0))))

(defun yaml-electric-backspace (arg)
  "Delete characters or back-dent the current line.
If invoked following only whitespace on a line, will back-dent to the
immediately previous multiple of `yaml-indent-offset' spaces."
  (interactive "*p")
  (if (or (/= (current-indentation) (current-column)) (bolp))
      (funcall yaml-backspace-function arg)
    (let ((ci (current-column)))
      (beginning-of-line)
      (delete-horizontal-space)
      (indent-to (* (/ (- ci (* arg yaml-indent-offset))
                       yaml-indent-offset)
                    yaml-indent-offset)))))

(defun yaml-electric-bar-and-angle (arg)
  "Insert the bound key and possibly begin a block literal.
Inserts the bound key.  If inserting the bound key causes the current
line to match the initial line of a block literal, then inserts the
matching string from `yaml-block-literal-electric-alist', a newline,
and indents appropriately."
  (interactive "*P")
  (self-insert-command (prefix-numeric-value arg))
  (let ((extra-chars
         (assoc last-command-event
                yaml-block-literal-electric-alist)))
    (cond
     ((and extra-chars (not arg) (eolp)
           (save-excursion
             (beginning-of-line)
             (looking-at yaml-block-literal-re)))
      (insert (cdr extra-chars))
      (newline-and-indent)))))

(defun yaml-electric-dash-and-dot (arg)
  "Insert the bound key and possibly de-dent line.
Inserts the bound key.  If inserting the bound key causes the current
line to match a document delimiter, de-dent the line to the left
margin."
  (interactive "*P")
  (self-insert-command (prefix-numeric-value arg))
  (save-excursion
    (beginning-of-line)
    (if (and (not arg) (looking-at yaml-document-delimiter-re))
        (delete-horizontal-space))))

(defun yaml-narrow-to-block-literal ()
  "Narrow the buffer to block literal if the point is in it,
otherwise do nothing."
  (interactive)
  (save-excursion
    (goto-char (point-at-bol))
    (while (and (looking-at-p yaml-blank-line-re) (not (bobp)))
      (forward-line -1))
    (let ((nlines yaml-block-literal-search-lines)
	  (min-level (current-indentation))
	  beg)
      (forward-line -1)
      (while (and (/= nlines 0)
		  (/= min-level 0)
		  (not (looking-at-p yaml-block-literal-re))
		  (not (bobp)))
	(set 'nlines (1- nlines))
	(unless (looking-at-p yaml-blank-line-re)
	  (set 'min-level (min min-level (current-indentation))))
	(forward-line -1))
      (when (and (< (current-indentation) min-level)
		  (looking-at-p yaml-block-literal-re))
	(set 'min-level (current-indentation))
	(forward-line)
	(setq beg (point))
	(while (and (not (eobp))
		    (or (looking-at-p yaml-blank-line-re)
			(> (current-indentation) min-level)))
	  (forward-line))
	(narrow-to-region beg (point))))))

(defun yaml-fill-paragraph (&optional justify region)
  "Fill paragraph.
This behaves as `fill-paragraph' except that filling does not
cross boundaries of block literals."
  (interactive "*P")
  (save-restriction
    (yaml-narrow-to-block-literal)
    (let ((fill-paragraph-function nil))
      (fill-paragraph justify region))))

(defun yaml-set-imenu-generic-expression ()
  (make-local-variable 'imenu-generic-expression)
  (make-local-variable 'imenu-create-index-function)
  (setq imenu-create-index-function 'imenu-default-create-index-function)
  (setq imenu-generic-expression yaml-imenu-generic-expression))

(add-hook 'yaml-mode-hook 'yaml-set-imenu-generic-expression)


(defun yaml-mode-version ()
  "Diplay version of `yaml-mode'."
  (interactive)
  (message "yaml-mode %s" yaml-mode-version)
  yaml-mode-version)

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.e?ya?ml$" . yaml-mode))

(provide 'yaml-mode)

;;; yaml-mode.el ends here
