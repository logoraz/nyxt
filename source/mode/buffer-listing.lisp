;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(nyxt:define-package :nyxt/mode/buffer-listing
  (:documentation "Package for `buffer-listing-mode', mode for buffer listing."))
(in-package :nyxt/mode/buffer-listing)

(define-mode buffer-listing-mode ()
  "Mode for buffer-listing.
Hosts `list-buffers' page."
  ((visible-in-status-p nil))
  (:toggler-command-p nil))

(define-command list-buffers-as-tree ()
  "List buffers in a tree."
  (list-buffers))

(define-command list-buffers-as-list ()
  "List buffers as a list."
  (list-buffers :linear-view-p t))

(define-internal-page-command-global list-buffers (&key (cluster nil)
                                                  linear-view-p) ; TODO: Document `cluster'.
    (listing-buffer "*Buffers*" 'nyxt/mode/buffer-listing:buffer-listing-mode)
  "Show all buffers and their interrelations.

When a buffer is spawned from another one (e.g. by middle-clicking on a link),
we say that a child buffer originates from a parent one. These kind of
relationships define a buffer tree.  When LINEAR-VIEW-P is non-nil, buffers are
shown linearly instead."
  (labels ((cluster-buffers ()
             "Return buffers as hash table, where each value is a cluster (list of documents)."
             (let ((collection (make-instance 'analysis::document-collection)))
               (loop for buffer in (buffer-list)
                     do (with-current-buffer buffer
                          (analysis::add-document
                           collection
                           (make-instance 'analysis::document-cluster
                                          :source buffer
                                          :string-contents (document-get-paragraph-contents)))))
               (analysis::tf-vectorize-documents collection)
               (analysis::generate-document-distance-vectors collection)
               (analysis::dbscan collection :minimum-points 1 :epsilon 0.075)
               (analysis::clusters collection)))
           (buffer-markup (buffer)
             "Present a buffer in HTML."
             (let ((*print-pretty* nil))
               (spinneret:with-html
                 (:p :class "buffer-listing"
                     (:nbutton
                       :text "✕"
                       :title "Delete buffer"
                       `(nyxt::delete-buffer :buffers ,buffer)
                       `(ffi-buffer-reload ,listing-buffer))
                     (:nbutton
                       :class "buffer-button"
                       :text (format nil "~a - ~a" (render-url (url buffer)) (title buffer))
                       :title "Switch to buffer"
                       `(nyxt::switch-buffer :buffer ,buffer))))))
           (buffer-tree->html (root-buffer)
             "Present a single buffer tree in HTML."
             (spinneret:with-html
               (:div (buffer-markup root-buffer))
               (:ul
                (dolist (child-buffer (nyxt::buffer-children root-buffer))
                  (:li (buffer-tree->html child-buffer))))))
           (cluster-markup (cluster-id cluster)
             "Present a cluster in HTML."
             (spinneret:with-html
               (:div (:h2 (format nil "Cluster ~a" cluster-id))
                     (loop for document in cluster
                           collect (buffer-markup (analysis::source document)))))))
    (spinneret:with-html-string
      (render-menu 'nyxt/mode/buffer-listing:buffer-listing-mode listing-buffer)
      (:h1 "Buffers")
      (:nstyle
        '(.buffer-listing
         :display "flex")
        '(.buffer-button
          :text-align "left"
          :flex-grow "1"))
      (:div
       (if cluster
           (loop for cluster-key being the hash-key
                 using (hash-value cluster) of (cluster-buffers)
                 collect (cluster-markup cluster-key cluster))
           (dolist (buffer (buffer-list))
             (if linear-view-p
                 (buffer-markup buffer)
                 (unless (nyxt::buffer-parent buffer)
                   (buffer-tree->html buffer)))))))))
