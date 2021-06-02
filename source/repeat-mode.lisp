;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(uiop:define-package :nyxt/repeat-mode
    (:use :common-lisp :nyxt)
  (:documentation "Mode to infinitely repeat commands."))
(in-package :nyxt/repeat-mode)

(defun initialize-repeat-mode (mode)
  (unless (repetitive-action mode)
    (let ((prompted-action
            (first
             (prompt :prompt "Command to repeat"
                     :sources (list (make-instance 'nyxt:command-source))))))
      (setf (repetitive-action mode)
            #'(lambda (mode)
                (declare (ignore mode))
                (funcall prompted-action)))))
  (nyxt/process-mode::initialize-process-mode mode))

(define-mode repeat-mode (nyxt/process-mode:process-mode)
  "Mode to repeat a simple action/function repetitively until stopped."
  ((nyxt/process-mode:firing-condition
    #'(lambda (path-url mode)
        (declare (ignore path-url))
        (sleep (repeat-interval mode))
        t))
   (nyxt/process-mode:action
    #'(lambda (path-url mode)
        (declare (ignore path-url))
        (when (repetitive-action mode)
          (funcall (repetitive-action mode) mode))))
   (repeat-interval 1
                    :type number
                    :documentation "The interval (in seconds) to repeat `repetitive-action' at.
Defaults to one second.")
   (repetitive-action nil
                      :type (or null (function (repeat-mode)))
                      :documentation "The action to repeat.
Function taking a `repeat-mode' instance.")
   (constructor #'initialize-repeat-mode)))

(define-command-global repeat-every (&optional seconds function)
  "Repeat a FUNCTION every SECONDS (prompts if SECONDS and/or FUNCTION are not provided)."
  (let ((seconds (or seconds
                     (ignore-errors
                      (parse-integer
                       (first (prompt :prompt "Repeat every X seconds"
                                      :input "5"
                                      :sources (list (make-instance 'prompter:raw-source)))))))))
    (when seconds
      (enable-modes 'repeat-mode (current-buffer)
                    (list :repeat-interval seconds :repetitive-action function)))))
