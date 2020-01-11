;;; scratch-log.el --- Save and restore the scratch buffer  -*- lexical-binding: t -*-

;; Copyright (C) 2010 by kmori

;; Author: kmori <morihenotegami@gmail.com>
;; Prefix: sl-

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; Put this file into load-path'ed directory, and byte compile it if
;; desired.  And put the following expression into your ~/.emacs.
;;
;; (require 'scratch-log)

;;; Change Log:

;; 0.0.1: scratch-log.el 0.0.1 released.

;;; Code
;;; Options
(defgroup scratch-log nil
  "Save and restore the scratch buffer."
  :group 'convenience
  :prefix "sl-")

(defcustom sl-scratch-log-file
  (locate-user-emacs-file ".scratch-log")
  "File for saving scratch buffer contents."
  :type 'file
  :group 'scratch-log)

(defcustom sl-scratch-prev-file
  (locate-user-emacs-file ".scratch-log-prev")
  "File for the last session's scratch buffer."
  :type 'file
  :group 'scratch-log)

(defcustom sl-restore-scratch-p t
  "Non-nil means scratch buffer is restored
from log file when emacs is started."
  :type 'boolean
  :group 'scratch-log)

(defcustom sl-prohibit-kill-scratch-buffer-p t
  "Non-nil means killing scratch buffer is prohibited."
  :type 'boolean
  :group 'scratch-log)

(defcustom sl-use-timer t
  "Non-nil means scratch buffer is saved at the interval specified by `sl-timer-interval'."
  :type 'boolean
  :group 'scratch-log)

(defcustom sl-timer-interval 30
  "The interval between auto-saving *scratch* buffer."
  :type 'integer
  :group 'scratch-log)

;;; Utilities
(defmacro sl-aif (test-form then-form &rest else-forms)
  "Anaphoric if."
  (declare (indent 2))
  `(let ((it ,test-form))
     (if it ,then-form ,@else-forms)))

(defmacro sl-awhen (test-form &rest body)
  "Anaphoric when."
  (declare (indent 1))
  `(sl-aif ,test-form
       (progn ,@body)))

;;; Main
(defun sl-dump-scratch-when-kill-buf ()
  (interactive)
  (when (string= "*scratch*" (buffer-name))
    (sl-make-prev-scratch-string-file)
    (sl-append-scratch-log-file)))

(defun sl-dump-scratch-when-kill-emacs ()
  (interactive)
  (sl-awhen (get-buffer "*scratch*")
    (with-current-buffer it
      (sl-make-prev-scratch-string-file)
      (sl-append-scratch-log-file))))

(defun sl-dump-scratch-for-timer ()
  (interactive)
  (if (sl-need-to-save)
      (sl-awhen (get-buffer "*scratch*")
        (with-current-buffer it
          (sl-make-prev-scratch-string-file)))))

(defun sl-need-to-save ()
  (sl-awhen (get-buffer "*scratch*")
    (let ((scratch-point-max (with-current-buffer it (point-max))))
      (with-temp-buffer
        (insert-file-contents sl-scratch-prev-file)
        (or (not (eq (point-max) scratch-point-max))
            (not (eq (compare-buffer-substrings
                      nil 1 (point-max)
                      it 1 scratch-point-max)
                     0)))))))

(defun sl-make-prev-scratch-string-file ()
  (write-region (point-min) (point-max) sl-scratch-prev-file nil 'nomsg))

(defun sl-append-scratch-log-file ()
  (let* ((time (format-time-string "* %Y/%m/%d-%H:%m" (current-time)))
         (buf-str (buffer-substring-no-properties (point-min) (point-max)))
         (contents (concat "\n" time "\n" buf-str)))
    (with-temp-buffer
      (insert contents)
      (write-region (point-min) (point-max) sl-scratch-log-file t 'nomsg))))

(defun sl-restore-scratch ()
  (interactive)
  (when (and sl-restore-scratch-p
             (file-exists-p sl-scratch-prev-file))
    (with-current-buffer "*scratch*"
      (buffer-disable-undo)
      (erase-buffer)
      (insert-file-contents sl-scratch-prev-file)
      (buffer-enable-undo))))

(defun sl-scratch-buffer-p ()
  (if (string= "*scratch*" (buffer-name)) nil t))

(add-hook 'kill-buffer-hook 'sl-dump-scratch-when-kill-buf)
(add-hook 'kill-emacs-hook 'sl-dump-scratch-when-kill-emacs)
(add-hook 'emacs-startup-hook 'sl-restore-scratch)
(when sl-prohibit-kill-scratch-buffer-p
  (add-hook 'kill-buffer-query-functions 'sl-scratch-buffer-p))
(when sl-use-timer
  (run-with-idle-timer sl-timer-interval t 'sl-dump-scratch-for-timer))

;;; Bug report
(defvar scratch-log-maintainer-mail-address
  (concat "morihen" "otegami@gm" "ail.com"))

(defvar scratch-log-bug-report-salutation
  "Describe bug below, using a precise recipe.

When I executed M-x ...

How to send a bug report:
  1) Be sure to use the LATEST version of scratch-log.el.
  2) Enable debugger. M-x toggle-debug-on-error or (setq debug-on-error t)
  3) Use Lisp version instead of compiled one: (load \"scratch-log.el\")
  4) If you got an error, please paste *Backtrace* buffer.
  5) Type C-c C-c to send.
# If you are a Japanese, please write in Japanese:-)")

(defun scratch-log-send-bug-report ()
  (interactive)
  (reporter-submit-bug-report
   scratch-log-maintainer-mail-address
   "scratch-log.el"
   (apropos-internal "^eldoc-" 'boundp)
   nil nil
   scratch-log-bug-report-salutation))

(provide 'scratch-log)

;;; scratch-log.el ends here
