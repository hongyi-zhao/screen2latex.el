;;; screen2latex.el --- Convert equations to LaTeX code

;; Author: Davide Magrin <magrin.davide@gmail.com>
;; Version: 0.1.0
;; Package-Version: 0.1.0
;; Package-Requires: ((request "0.3.2") (emacs "25.1"))
;; Keywords: convenience, languages, multimedia, tex
;; URL: https://github.com/DvdMgr/screen2latex.el

;;; Commentary:\frac{d}{d t} \iint_{\Sigma} \mathbf{B} \cdot \mathrm{d} \mathbf{S}=\iint_{\Sigma} \frac{\partial \mathbf{B}}{\partial t} \cdot \mathrm{d} \mathbf{S}
;; This package allows you to select an area of the screen containing an
;; equation, and get the corresponding LaTeX code inserted in the current buffer
;; at point. To use it, simply M-x screen2latex.

;;; Code:

(defun screen2latex-get-screenshot (filename)
  "Get a screenshot, and save it at FILENAME."

  ;; Use the appropriate program to take the screenshot, based on the os
  (cond
   ((string-equal system-type "darwin") ; Mac OS X
    (progn
      (call-process "screencapture" nil nil nil "-i" filename)))
   ((string-equal system-type "gnu/linux") ; Linux
    ;; (progn
    ;;   (call-process "gnome-screenshot" nil nil nil "-a" "-f" filename))
    (progn
      ;sudo apt install scrot
      (call-process "scrot" nil nil nil "-s" filename))
    )))


;https://emacs.stackexchange.com/questions/9554/function-that-returns-parent-directory-absolute-path
(defun parent-directory (dir)
  (unless (equal "/" dir)
    (file-name-directory (directory-file-name dir))))

;https://mail.google.com/mail/u/0?ik=7b73d6af10&view=pt&search=all&permmsgid=msg-a%3Ar-5725215334712845105&simpl=msg-a%3Ar-5725215334712845105
;https://www.gnu.org/software/emacs/manual/html_node/elisp/File-Name-Expansion.html#File-Name-Expansion
;https://emacs.stackexchange.com/questions/29027/print-absolute-path-of-symlink
;https://github.com/raxod502/straight.el/issues/797#issuecomment-861143412
(setq script-directory (file-name-directory (file-truename load-file-name)))
(setq script-parent-directory (parent-directory script-directory))


(defun screen2latex ()
  "Get a screenshot for a mathematical formula and insert the corresponding LaTeX at point."

  (interactive)

  (require 'request) ;; We need request to call the Mathpix API

  ;; Load secrets
   (load-file (expand-file-name "auth.el.gpg" script-directory))
;or    
;  https://mail.google.com/mail/u/0/?ogbl#sent/KtbxLwGvXzlLMTCXRpJQRpXVSZBTwDcDmL
;  (load-file
;  (concat
;    (file-name-as-directory script-directory)
;    "auth.el.gpg"))

    
  ;; Temporary file where to save the screenshot
  (setq filename "/tmp/screentemp.png")

  ;; Get the screnshot
  (screen2latex-get-screenshot filename)

  ;; Convert the image to base64
  (setq image-buffer (find-file-noselect filename t t))
  (setq image (with-current-buffer image-buffer
                (base64-encode-string (buffer-string) t)))

  ;; Convert the image to LaTeX using Mathpix's OCR service
  (message "Converting...")
  (setq r (request
           "https://api.mathpix.com/v3/latex"
           :type "POST"
           :headers `(("app_id" . ,mathpix_app_id)
                      ("app_key" . ,mathpix_app_key)
                      ("Content-type" . "application/json"))
           :data (json-encode-alist
                  `(("src" . ,(concat "data:image/png;base64," image))
                    ("formats" . ,(list "latex_styled"))
                    ("format_options" .
                     ,`(("latex_styled" .
                         ,`(("transforms" .
                             (cons "rm_spaces" '()))))))))
           :parser 'json-read
           :sync t
           :complete (cl-function
                      (lambda (&key response &allow-other-keys)
                        (insert (alist-get 'latex_styled (request-response-data response)))))))

  ;; Clean up
  (delete-file filename)
  (kill-buffer image-buffer))

(provide 'screen2latex)

;;; screen2latex.el ends here
