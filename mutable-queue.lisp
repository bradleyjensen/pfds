;; Copyright 2019 Ada Avery
;;
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;;
;;     http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.

(defpackage :pfds.shcl.io/mutable-queue
  (:use :common-lisp)
  (:import-from :pfds.shcl.io/compare #:define-type-id)
  (:import-from :pfds.shcl.io/common #:is-empty #:empty)
  (:export #:make-mutable-queue #:enqueue #:dequeue #:mutable-queue-count))
(in-package :pfds.shcl.io/mutable-queue)

(defconstant +default-queue-size+ 32)

(defstruct (mutable-queue (:constructor %make-mutable-queue))
  (array (make-array +default-queue-size+) :type vector)
  (front-position 0 :type (integer 0))
  (%count 0 :type (integer 0)))

(define-type-id mutable-queue)

(defun mutable-queue-count (queue)
  (mutable-queue-%count queue))

(defun make-mutable-queue (&key (initial-size +default-queue-size+) initial-contents)
  (check-type initial-size (integer 0))
  (let ((queue (%make-mutable-queue
                :array (make-array initial-size))))
    (dolist (item initial-contents)
      (enqueue queue item))
    queue))

(defun copy-queue-array (old-array old-front-position old-count new-array)
  (loop :for i :below old-count
        :for index = (mod (+ i old-front-position) (length old-array)) :do
          (setf (aref new-array i) (aref old-array index)))
  (values))

(defun enqueue (queue object)
  (when (equal (mutable-queue-%count queue) (length (mutable-queue-array queue)))
    (let ((new-array (make-array (* 2 (length (mutable-queue-array queue)))))
          (old-array (mutable-queue-array queue))
          (old-count (mutable-queue-%count queue))
          (old-front-position (mutable-queue-front-position queue)))
      (copy-queue-array old-array old-front-position old-count new-array)
      (setf (mutable-queue-array queue) new-array)
      (setf (mutable-queue-front-position queue) 0)))

  (let* ((old-count (mutable-queue-%count queue))
         (front-position (mutable-queue-front-position queue))
         (array (mutable-queue-array queue))
         (write-position (mod (+ old-count front-position) (length array)))
         (new-count (1+ old-count)))
    (setf (aref array write-position) object)
    (setf (mutable-queue-%count queue) new-count))

  (values))

(defun dequeue (queue)
  (when (zerop (mutable-queue-%count queue))
    (return-from dequeue
      (values nil nil)))

  (let* ((array (mutable-queue-array queue))
         (old-front-position (mutable-queue-front-position queue))
         (new-front-position (mod (1+ old-front-position) (length array)))
         (old-count (mutable-queue-%count queue))
         (new-count (1- old-count))
         (removed-item (aref array old-front-position)))
    (setf (mutable-queue-%count queue) new-count)
    (setf (mutable-queue-front-position queue) new-front-position)
    (setf (aref array old-front-position) 0)

    (let* ((shorter-length (ceiling (/ (length array) 2)))
           (threshold-length (ceiling (/ shorter-length 4))))
      (when (and (< new-count threshold-length)
                 (>= shorter-length +default-queue-size+))
        (let ((new-array (make-array shorter-length)))
          (copy-queue-array array new-front-position new-count new-array)
          (setf (mutable-queue-array queue) new-array)
          (setf (mutable-queue-front-position queue) 0))))

    (values removed-item t)))