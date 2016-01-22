
# @array
# bla_@array
# [array]
# [bla_@array]

# #===============================================================================    
# # Build packages                                                                    
# #===============================================================================    
# PACKAGES[@build]="autoconf automake bison flex gdb make patch"                      
# RECOMMENDS[@build]="ccache texinfo"                                                 
# #-------------------------------------------------------------------------------    
# PACKAGES[Debian_@build]="build-essential libc6-dev libncurses5-dev libtool manpages"
# #------------------------------------------------------------------------------- 
# PACKAGES[Ubuntu_@build]="[Debian_@build]"                                        
# PACKAGES[Ubuntu-12.04_@build]="g++-multilib"                                     
# #------------------------------------------------------------------------------- 
# PACKAGES[LinuxMint_@build]="[Ubuntu_@build]"                                     
# PACKAGES[LinuxMint-16_@build]="[Ubuntu-12.04_@build]"                            
# #------------------------------------------------------------------------------- 
# PACKAGES[RHEL_@build]="gcc gcc-c++ glibc-devel"                                  
# #------------------------------------------------------------------------------- 
# PACKAGES[LFD211]="@build @common @trace gparted sysstat tcpdump wireshark"
# RECOMMENDS[LFD211]="iptraf-ng gnome-system-monitor ksysguard yelp"        
# PACKAGES[Debian_LFD211]="stress"                                          
# RECOMMENDS[Debian_LFD211]="default-jdk"                                   
# PACKAGES[Ubuntu_LFD211]="[Debian_LFD211]"                                 
# RECOMMENDS[Ubuntu_LFD211]="[Debian_LFD211]"                               
# PACKAGES[LinuxMint_LFD211]="[Debian_LFD211]"                              
# RECOMMENDS[RHEL_LFD211]="kdebase"                                         
# RECOMMENDS[RHEL-6_LFD211]="-iptraf-ng iptraf"                             
# PACKAGES[CentOS_LFD211]="[RHEL_LFD211]"                                   
# RECOMMENDS[CentOS-6_LFD211]="[RHEL-6_LFD211] -ksysguard ksysguardd"       
# PACKAGES[Fedora_LFD211]="[RHEL_LFD211] stress"                            
# RECOMMENDS[openSUSE_LFD211]="kdebase4-workspace -ksysguard"               

# Recursively expand macros in package list                                  
pkg_list_recurse() {                                                         
    local DB=$1; shift                                                       
    local DID=$1; shift                                                      
    local DREL=$1; shift                                                     
    local KEY                                                                
    debug "recurse $DB $DID-$DREL: $*"                                       
    for KEY in $* ; do                                                       
        case $KEY in                                                         
            @*) local PKGS=$(get_db $DB $KEY $DID $DREL)                     
                pkg_list_recurse $DB $DID $DREL $PKGS ;;                     
            [*) local PKGS=$(eval "echo \${$DB$KEY}") #]                     
                debug "lookup macro $DB$KEY -> $PKGS"                        
                [[ $KEY != $PKGS ]] || error "Recursive package list: $KEY"  
                pkg_list_recurse $DB $DID $DREL $PKGS ;;                     
            *) echo $KEY ;;                                                  
        esac                                                                 
    done                                                                     
}                                                                            
# Check package list for obvious problems                                          
pkg_list_check() {                                                                 
    for PKG in ${!PACKAGES[@]} ${!RECOMMENDS[@]}; do                               
        case "$PKG" in                                                             
            @*|*_@*) >/dev/null;;                                                  
            *@*) fail "'$PKG' is likely invalid. I think you meant '${PKG/@/_@}'";;
            *) >/dev/null;;                                                        
        esac                                                                       
    done                                                                           
}                                                                                  
# Do a lookup in DB for NAME, DIST_NAME, DIST-RELEASE_NAME
get_db() {                                                   
    local DB=$1                                              
    local NAME=$2                                            
    local DIST=$3                                            
    local RELEASE=$4                                         
                                                             
    debug "get_db $DB NAME=$NAME DIST=$DIST RELEASE=$RELEASE"
    lookup $DB $NAME                                         
    lookup_fallback $DB "$NAME" "$DIST" ""                   
    lookup_fallback $DB "$NAME" "$DIST" "$RELEASE"           
}                                                            
# Do a lookup in DB of KEY                 
lookup() {                                 
    local DB=$1                            
    local KEY=$2                           
    [[ -n $KEY ]] || return                
    local DATA=$(eval "echo \${$DB[$KEY]}")
    if [[ -n $DATA ]] ; then               
        debug "lookup $DB[$KEY] -> $DATA"  
        echo $DATA                         
        return 0                           
    fi                                     
    return 1                               
}                                          
# Do a lookup in DB for DIST[-RELEASE] and if unfound consult FALLBACK distros
lookup_fallback() {                                                           
    local DB=$1                                                               
    local NAME=$2                                                             
    local DIST=$3                                                             
    local RELEASE=$4                                                          
    #debug "fallback DB=$DB NAME=$NAME DIST=$DIST RELEASE=$RELEASE"           
    DIST+=${RELEASE:+-$RELEASE}                                               
    local KEY                                                                 
    for KEY in $DIST ${FALLBACK[${DIST:-no_distro}]} ; do                     
        KEY+=${NAME:+_$NAME}                                                  
        lookup $DB $KEY && return                                             
    done                                                                      
}                                                                             


# (defun yaml-font-lock-block-literals (bound)
#   "Find lines within block literals.
# Find the next line of the first (if any) block literal after point and
# prior to BOUND.  Returns the beginning and end of the block literal
# line in the match data, as consumed by `font-lock-keywords' matcher
# functions.  The function begins by searching backwards to determine
# whether or not the current line is within a block literal.  This could
# be time-consuming in large buffers, so the number of lines searched is
# artificially limitted to the value of
# `yaml-block-literal-search-lines'."
#   (if (eolp) (goto-char (1+ (point))))
#   (unless (or (eobp) (>= (point) bound))
#     (let ((begin (point))
#           (end (min (1+ (point-at-eol)) bound)))
#       (goto-char (point-at-bol))
#       (while (and (looking-at yaml-blank-line-re) (not (bobp)))
#         (forward-line -1))
#       (let ((nlines yaml-block-literal-search-lines)
#             (min-level (current-indentation)))
#       (forward-line -1)
#       (while (and (/= nlines 0)
#                   (/= min-level 0)
#                   (not (looking-at yaml-block-literal-re))
#                   (not (bobp)))
#         (set 'nlines (1- nlines))
#         (unless (looking-at yaml-blank-line-re)
#           (set 'min-level (min min-level (current-indentation))))
#         (forward-line -1))
#       (cond
#        ((and (< (current-indentation) min-level)
#              (looking-at yaml-block-literal-re))
#           (goto-char end) (set-match-data (list begin end)) t)
#          ((progn
#             (goto-char begin)
#             (re-search-forward (concat yaml-block-literal-re
#                                        " *\\(.*\\)\n")
#                                bound t))
#           (set-match-data (nthcdr 2 (match-data))) t))))))

# (defun yaml-syntactic-block-literals (bound)
#   "Find quote characters within block literals.
# Finds the first quote character within a block literal (if any) after
# point and prior to BOUND.  Returns the position of the quote character
# in the match data, as consumed by matcher functions in
# `font-lock-syntactic-keywords'.  This allows the mode to treat ['\"]
# characters in block literals as punctuation syntax instead of string
# syntax, preventing unmatched quotes in block literals from painting
# the entire buffer in `font-lock-string-face'."
#   (let ((found nil))
#     (while (and (not found)
#                 (/= (point) bound)
#                 (yaml-font-lock-block-literals bound))
#       (let ((begin (match-beginning 0)) (end (match-end 0)))
#         (goto-char begin)
#         (cond
#          ((re-search-forward "['\"]" end t) (setq found t))
#          ((goto-char end)))))
#     found))

# 
# ;; Indentation and electric keys

# (defun yaml-compute-indentation ()
#   "Calculate the maximum sensible indentation for the current line."
#   (save-excursion
#     (beginning-of-line)
#     (if (looking-at yaml-document-delimiter-re) 0
#       (forward-line -1)
#       (while (and (looking-at yaml-blank-line-re)
#                   (> (point) (point-min)))
#         (forward-line -1))
#       (+ (current-indentation)
#          (if (looking-at yaml-nested-map-re) yaml-indent-offset 0)
#          (if (looking-at yaml-nested-sequence-re) yaml-indent-offset 0)
#          (if (looking-at yaml-block-literal-re) yaml-indent-offset 0)))))

# (defun yaml-indent-line ()
#   "Indent the current line.
# The first time this command is used, the line will be indented to the
# maximum sensible indentation.  Each immediately subsequent usage will
# back-dent the line by `yaml-indent-offset' spaces.  On reaching column
# 0, it will cycle back to the maximum sensible indentation."
#   (interactive "*")
#   (let ((ci (current-indentation))
#         (cc (current-column))
#         (need (yaml-compute-indentation)))
#     (save-excursion
#       (beginning-of-line)
#       (delete-horizontal-space)
#       (if (and (equal last-command this-command) (/= ci 0))
#           (indent-to (* (/ (- ci 1) yaml-indent-offset) yaml-indent-offset))
#         (indent-to need)))
#       (if (< (current-column) (current-indentation))
#           (forward-to-indentation 0))))

# (defun yaml-electric-backspace (arg)
#   "Delete characters or back-dent the current line.
# If invoked following only whitespace on a line, will back-dent to the
# immediately previous multiple of `yaml-indent-offset' spaces."
#   (interactive "*p")
#   (if (or (/= (current-indentation) (current-column)) (bolp))
#       (funcall yaml-backspace-function arg)
#     (let ((ci (current-column)))
#       (beginning-of-line)
#       (delete-horizontal-space)
#       (indent-to (* (/ (- ci (* arg yaml-indent-offset))
#                        yaml-indent-offset)
#                     yaml-indent-offset)))))

# (defun yaml-electric-bar-and-angle (arg)
#   "Insert the bound key and possibly begin a block literal.
# Inserts the bound key.  If inserting the bound key causes the current
# line to match the initial line of a block literal, then inserts the
# matching string from `yaml-block-literal-electric-alist', a newline,
# and indents appropriately."
#   (interactive "*P")
#   (self-insert-command (prefix-numeric-value arg))
#   (let ((extra-chars
#          (assoc last-command-event
#                 yaml-block-literal-electric-alist)))
#     (cond
#      ((and extra-chars (not arg) (eolp)
#            (save-excursion
#              (beginning-of-line)
#              (looking-at yaml-block-literal-re)))
#       (insert (cdr extra-chars))
#       (newline-and-indent)))))

# (defun yaml-electric-dash-and-dot (arg)
#   "Insert the bound key and possibly de-dent line.
# Inserts the bound key.  If inserting the bound key causes the current
# line to match a document delimiter, de-dent the line to the left
# margin."
#   (interactive "*P")
#   (self-insert-command (prefix-numeric-value arg))
#   (save-excursion
#     (beginning-of-line)
#     (if (and (not arg) (looking-at yaml-document-delimiter-re))
#         (delete-horizontal-space))))

# (defun yaml-narrow-to-block-literal ()
#   "Narrow the buffer to block literal if the point is in it,
# otherwise do nothing."
#   (interactive)
#   (save-excursion
#     (goto-char (point-at-bol))
#     (while (and (looking-at-p yaml-blank-line-re) (not (bobp)))
#       (forward-line -1))
#     (let ((nlines yaml-block-literal-search-lines)
# 	  (min-level (current-indentation))
# 	  beg)
#       (forward-line -1)
#       (while (and (/= nlines 0)
# 		  (/= min-level 0)
# 		  (not (looking-at-p yaml-block-literal-re))
# 		  (not (bobp)))
# 	(set 'nlines (1- nlines))
# 	(unless (looking-at-p yaml-blank-line-re)
# 	  (set 'min-level (min min-level (current-indentation))))
# 	(forward-line -1))
#       (when (and (< (current-indentation) min-level)
# 		  (looking-at-p yaml-block-literal-re))
# 	(set 'min-level (current-indentation))
# 	(forward-line)
# 	(setq beg (point))
# 	(while (and (not (eobp))
# 		    (or (looking-at-p yaml-blank-line-re)
# 			(> (current-indentation) min-level)))
# 	  (forward-line))
# 	(narrow-to-region beg (point))))))

# (defun yaml-fill-paragraph (&optional justify region)
#   "Fill paragraph.
# This behaves as `fill-paragraph' except that filling does not
# cross boundaries of block literals."
#   (interactive "*P")
#   (save-restriction
#     (yaml-narrow-to-block-literal)
#     (let ((fill-paragraph-function nil))
#       (fill-paragraph justify region))))

# (defun yaml-set-imenu-generic-expression ()
#   (make-local-variable 'imenu-generic-expression)
#   (make-local-variable 'imenu-create-index-function)
#   (setq imenu-create-index-function 'imenu-default-create-index-function)
#   (setq imenu-generic-expression yaml-imenu-generic-expression))

# (add-hook 'yaml-mode-hook 'yaml-set-imenu-generic-expression)


# (defun yaml-mode-version ()
#   "Diplay version of `yaml-mode'."
#   (interactive)
#   (message "yaml-mode %s" yaml-mode-version)
#   yaml-mode-version)

# ;;;###autoload
# (add-to-list 'auto-mode-alist '("\\.e?ya?ml$" . yaml-mode))

# (provide 'yaml-mode)

# ;;; yaml-mode.el ends here
