;;; package --- Company mode backend for C/C++ header files with Irony

;;; Commentary:

;;

;;; Code:

(require 'cl-lib)
(require 'irony)

(defvar company-irony-c-headers--compiler-executable "clang-mp-3.6"
  "Compiler executable.")

(defun company-irony-c-headers--include-decl ()
  "Match include syntax."
  (rx
   line-start
   "#" (zero-or-more blank) "include"
   (one-or-more blank)
   (or (and "<" (submatch-n 1 (zero-or-more (not-char ?>))))
       (and "\"" (submatch-n 2 (zero-or-more (not-char ?\")))))))

(defvar company-irony-c-headers--modes
  '(c++-mode c-mode)
  "Mode supported.")

;; TODO use irony
(defun company-irony-c-headers--lang ()
  "Get language."
  '("-x" "c++"))

(defun company-irony-c-headers--default-compiler-options ()
  "Get default compiler options to obtain include paths."
  (append (company-irony-c-headers--lang) '("-v" "-E" "-")))

;; TODO use irony
(defun company-irony-c-headers--user-compiler-options ()
  "Get compiler options."
  '("-iquotedup2" "-Idup"))

;; TODO use irony
(defun company-irony-c-headers--working-dir ()
  "Get working directory."
  "/Users/hotpxl/tmp/has")

(defvar-local company-irony-c-headers--compiler-output nil
  "Compiler generated output for search paths.")

;;;###autoload
(defun company-irony-c-headers-reload-compiler-output ()
  "Call compiler to get search paths."
  (interactive)
  (when company-irony-c-headers--compiler-executable
    (let ((res
           (with-temp-buffer
             (apply 'call-process
                    company-irony-c-headers--compiler-executable nil t nil
                    (append
                     (company-irony-c-headers--user-compiler-options)
                     (company-irony-c-headers--default-compiler-options)))
             (goto-char (point-min))
             (let (quote-directories
                   angle-directories
                   (start "#include \"...\" search starts here:")
                   (second-start "#include <...> search starts here:")
                   (stop "End of search list."))
               (when (search-forward start nil t)
                 (forward-line 1)
                 (while (not (looking-at-p second-start))
                   ;; Skip whitespace at the begining of the line.
                   (skip-chars-forward "[:blank:]" (point-at-eol))
                   (let ((p
                          (replace-regexp-in-string
                           "\\s-+(framework directory)"
                           "" (buffer-substring (point) (point-at-eol)))))
                     (push p quote-directories))
                   (forward-line 1))
                 (forward-line 1)
                 (while (not (or (looking-at-p stop) (eolp)))
                   ;; Skip whitespace at the begining of the line.
                   (skip-chars-forward "[:blank:]" (point-at-eol))
                   (let ((p
                          (replace-regexp-in-string
                           "\\s-+(framework directory)"
                           "" (buffer-substring (point) (point-at-eol)))))
                     (push p quote-directories)
                     (push p angle-directories))
                   (forward-line 1)))
               (list
                (reverse quote-directories)
                (reverse angle-directories))
               ))))
      (setq company-irony-c-headers--compiler-output res)
      )))

(defun company-irony-c-headers--search-paths ()
  "Retrieve compiler search paths."
  (unless company-irony-c-headers--compiler-output
    (company-irony-c-headers-reload-compiler-output))
  company-irony-c-headers--compiler-output)

(defun company-irony-c-headers--resolve-paths (paths)
  "Resolve PATHS relative to working directory."
  (let ((working-dir (company-irony-c-headers--working-dir)))
    (mapcar
     (lambda (i)
       (file-name-as-directory
        (expand-file-name i working-dir))) paths)))

(defun company-irony-c-headers--resolved-search-paths (q)
  "Get resolved paths.  Q indicates whether it is quoted."
  (if q
      (let ((cur-dir
             (if (buffer-file-name)
                 (file-name-directory (buffer-file-name))
               (file-name-as-directory (expand-file-name "")))))
        (cons
         cur-dir
         (company-irony-c-headers--resolve-paths
          (nth 0 (company-irony-c-headers--search-paths)))
         ))
    (company-irony-c-headers--resolve-paths
     (nth 1 (company-irony-c-headers--search-paths)))))

; (company-irony-c-headers--resolved-search-paths t)

(defun company-irony-c-headers--prefix ()
  "Find prefix for matching."
  (if (looking-back
       (company-irony-c-headers--include-decl) (line-beginning-position))
      (if (match-string-no-properties 1)
          (propertize (match-string-no-properties 1) 'quote nil)
        (if (match-string-no-properties 2)
            (propertize (match-string-no-properties 2) 'quote t)))))

(defun company-irony-c-headers--candidates-for (prefix dir)
  "Return a list of candidates for PREFIX in directory DIR."
  (let* ((prefixdir (file-name-directory prefix))
         (subdir (if prefixdir
                     (expand-file-name prefixdir dir)
                   dir))
         (prefixfile (file-name-nondirectory prefix))
         candidates)
    ;; Remove "." and "..".
    (when (file-directory-p subdir)
      (setq candidates
            (cl-remove-if
             (lambda (f)
               (cl-member
                (directory-file-name f) '("." "..") :test 'equal))
             (file-name-all-completions prefixfile subdir)))
      ;; Sort candidates.
      (setq candidates (sort candidates #'string<))
      ;; Add property.
      (mapcar
       (lambda (c)
         (let ((real (if prefixdir
                         (concat prefixdir c)
                       c)))
           (propertize
            real
            'directory subdir))) candidates))))

; (file-directory-p "/Users/hotpxl/tmp/has/o/jcet")

; (company-irony-c-headers--candidates-for "basedir/child" "/Users/hotpxl/tmp/has/")

(defun company-irony-c-headers--candidates (prefix)
  "Return candidates for PREFIX."
  (let* ((quoted (get-text-property 0 'quote prefix))
         (p (company-irony-c-headers--resolved-search-paths quoted))
         candidates)
    (mapc (lambda (i)
            (when (file-directory-p i)
              (setq
               candidates
               (append
                candidates
                (company-irony-c-headers--candidates-for prefix i)))
              ))
          p)
    (cl-delete-duplicates
     candidates
     :test 'string=
     :from-end t)))

; (cl-delete-duplicates (list (propertize "hh" 'a 2) (propertize "hh" 'b 4)) :test 'string= :from-end t)

; (company-irony-c-headers--candidates "vec")
; (company-irony-c-headers--candidates "a/")

(defun company-irony-c-headers--meta (candidate)
  "Return the metadata associated with CANDIDATE.  Just the directory."
  (get-text-property 0 'directory candidate))

(defun company-irony-c-headers--location (candidate)
  "Return the location associated with CANDIDATE."
  (cons (concat (file-name-as-directory (get-text-property 0 'directory candidate))
                (file-name-nondirectory candidate))
        1))

;;;###autoload
(defun company-irony-c-headers (command &optional arg &rest ignored)
  "Company backend for C/C++ header files.  Taking COMMAND ARG IGNORED."
  (interactive (list 'interactive))
  (cl-case command
    (interactive (company-begin-backend 'company-irony-c-headers))
    (prefix
     (if (member major-mode company-irony-c-headers--modes)
         (company-irony-c-headers--prefix)))
    (init (company-irony-c-headers-reload-compiler-output))
    (sorted t)
    (candidates (company-irony-c-headers--candidates arg))
    (location (company-irony-c-headers--location arg))
    (meta (company-irony-c-headers--meta arg))
    (post-completion
     (let ((matched (company-irony-c-headers--prefix)))
       (unless (equal matched (file-name-as-directory matched))
         (if (get-text-property 0 'quote matched)
             (insert "\"")
           (insert ">")))))
     ))

; (add-to-list 'company-backends 'company-irony-c-headers)
; (equal (propertize "hh" 'a 2) (propertize "hh" 'a 3))

(provide 'company-irony-c-headers)

;;; company-irony-c-headers ends here
