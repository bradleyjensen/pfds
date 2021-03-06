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

(defpackage :pfds.shcl.io/implementation/binomial-heap
  (:use :common-lisp)
  (:use :pfds.shcl.io/interface)
  (:import-from :pfds.shcl.io/utility/printer
   #:print-container)
  (:import-from :pfds.shcl.io/utility/impure-list-builder
   #:make-impure-list-builder #:impure-list-builder-add
   #:impure-list-builder-extract)
  (:import-from :pfds.shcl.io/utility/iterator-tools
   #:compare-heaps)
  (:import-from :pfds.shcl.io/utility/compare
   #:compare-objects #:compare)
  (:import-from :pfds.shcl.io/utility/immutable-structure
   #:define-adt #:define-immutable-structure)
  (:import-from :pfds.shcl.io/utility/misc
   #:cassert)
  (:export
   #:make-binomial-heap
   #:binomial-heap
   #:binomial-heap-p
   #:binomial-heap-comparator
   #:binomial-heap-size))
(in-package :pfds.shcl.io/implementation/binomial-heap)

;; See "Purely Functional Data Structures" by Chris Okasaki

(define-immutable-structure tree-node
  (value (error "value is required"))
  (children nil :type list))

(defmethod print-graphviz ((heap tree-node) stream id-vendor)
  (let ((id (next-graphviz-id id-vendor)))
    (format stream "ID~A [label=\"~A\" shape=box]~%" id (tree-node-value heap))
    (dolist (child (tree-node-children heap))
      (let ((child-id (print-graphviz child stream id-vendor)))
        (format stream "ID~A -> ID~A~%" id child-id)))
    id))

(defun tree-link (left right comparator)
  (when (eq :greater (funcall comparator (tree-node-value left) (tree-node-value right)))
    (rotatef left right))
  (make-tree-node
   :value (tree-node-value left)
   :children (cons right (tree-node-children left))))

(define-immutable-structure ranked-tree
  (tree (error "required arg") :type tree-node)
  (rank (error "required arg") :type (integer 0)))

(defmethod print-graphviz ((ranked-tree ranked-tree) stream id-vendor)
  (let ((id (next-graphviz-id id-vendor)))
    (format stream "ID~A [label=\"rank ~A\"]~%" id (ranked-tree-rank ranked-tree))
    (let ((child-id (print-graphviz (ranked-tree-tree ranked-tree) stream id-vendor)))
      (format stream "ID~A -> ID~A~%" id child-id))
    id))

(defun ranked-tree-link (left right comparator)
  (assert (equal (ranked-tree-rank left)
                 (ranked-tree-rank right)))
  (make-ranked-tree
   :tree (tree-link (ranked-tree-tree left)
                    (ranked-tree-tree right)
                    comparator)
   :rank (1+ (ranked-tree-rank left))))

(defun insert-tree (ranked-tree ranked-tree-list comparator)
  (unless ranked-tree-list
    (return-from insert-tree
      (list ranked-tree)))

  (let ((first-ranked-tree (car ranked-tree-list)))
    (when (< (ranked-tree-rank ranked-tree) (ranked-tree-rank first-ranked-tree))
      (return-from insert-tree (cons ranked-tree ranked-tree-list)))
    (assert (equal (ranked-tree-rank first-ranked-tree)
                   (ranked-tree-rank ranked-tree)))
    (insert-tree
     (ranked-tree-link ranked-tree first-ranked-tree comparator)
     (cdr ranked-tree-list)
     comparator)))

(defun insert-object (object ranked-tree-list comparator)
  (insert-tree
   (make-ranked-tree
    :tree (make-tree-node :value object)
    :rank 0)
   ranked-tree-list
   comparator))

(defun merge-ranked-tree-lists (first second comparator)
  (unless first
    (return-from merge-ranked-tree-lists second))
  (unless second
    (return-from merge-ranked-tree-lists first))

  (let* ((left-head (car first))
         (left-rank (ranked-tree-rank left-head))
         (right-head (car second))
         (right-rank (ranked-tree-rank right-head)))
    (cond
      ((< left-rank right-rank)
       (cons left-head
             (merge-ranked-tree-lists (cdr first) second comparator)))
      ((> left-rank right-rank)
       (cons right-head
             (merge-ranked-tree-lists first (cdr second) comparator)))
      ((= left-rank right-rank)
       (insert-tree
        (ranked-tree-link left-head right-head comparator)
        (merge-ranked-tree-lists (cdr first) (cdr second) comparator)
        comparator)))))

(defun find-minimum (ranked-tree-list comparator)
  (unless ranked-tree-list
    (return-from find-minimum (values nil nil)))

  (let ((min (tree-node-value (ranked-tree-tree (car ranked-tree-list)))))
    (dolist (ranked-tree (cdr ranked-tree-list))
      (let ((item (tree-node-value (ranked-tree-tree ranked-tree))))
        (when (eq :less (funcall comparator item min))
          (setf min item))))
    (values min t)))

(defun remove-minimum-tree (ranked-tree-list comparator)
  (assert ranked-tree-list)
  (unless (cdr ranked-tree-list)
    (values nil (car ranked-tree-list)))

  (let* ((list-builder (make-impure-list-builder))
         (min-sublist ranked-tree-list)
         (min-tree (car min-sublist))
         (min-value (tree-node-value (ranked-tree-tree min-tree))))
    (loop :for sublist :on (cdr ranked-tree-list)
          :for tree = (car sublist)
          :for value = (tree-node-value (ranked-tree-tree tree))
          :do
             (when (eq :less (funcall comparator value min-value))
               (setf min-sublist sublist)
               (setf min-tree tree)
               (setf min-value value)))
    (let ((remaining ranked-tree-list))
      (loop :until (eq min-sublist remaining) :do
        (progn
          (impure-list-builder-add list-builder (car remaining))
          (pop remaining)))
      (assert (eq min-sublist remaining))
      (pop remaining)
      (values (impure-list-builder-extract list-builder remaining) min-tree))))

(defun remove-minimum (ranked-tree-list comparator)
  (multiple-value-bind (updated-ranked-tree-list minimum-tree) (remove-minimum-tree ranked-tree-list comparator)
    (unless minimum-tree
      (return-from remove-minimum
        (values nil nil nil)))

    (let (inner-ranked-tree-list)
      ;; We need to reverse the tree's children and turn them into
      ;; ranked trees
      (loop :for rank :from (1- (ranked-tree-rank minimum-tree)) :downto 0
            :for tree :in (tree-node-children (ranked-tree-tree minimum-tree)) :do
              (push (make-ranked-tree :rank rank :tree tree) inner-ranked-tree-list))
      (values
       (merge-ranked-tree-lists updated-ranked-tree-list inner-ranked-tree-list comparator)
       (tree-node-value (ranked-tree-tree minimum-tree))
       t))))

(defun do-tree-f (fn tree)
  (funcall fn (tree-node-value tree))
  (dolist (child (tree-node-children tree))
    (do-tree-f fn child)))

(defun make-heap-iterator (tree-list)
  (let ((stack (list (cons nil tree-list))))
    (lambda ()
      (loop
        (unless stack
          (return (values nil nil)))

        (let* ((tip (car stack))
               (tip-node (car tip))
               (tip-children (cdr tip)))
          (cond
            (tip-node
             (setf (car tip) nil)
             (return (values (tree-node-value tip-node) t)))

            (tip-children
             (let ((child (pop (cdr tip))))
               (push (cons child (tree-node-children child)) stack)))

            (t
             (pop stack))))))))

(defmacro do-tree ((value tree &optional result) &body body)
  `(block nil
     (do-tree-f (lambda (,value) ,@body) ,tree)
     ,result))

(define-immutable-structure (binomial-heap (:constructor %make-binomial-heap))
  (comparator (error "comparator is required"))
  (size 0 :type (integer 0))
  (ranked-trees nil :type list))

(declare-interface-conformance binomial-heap priority-queue)

(defmethod print-graphviz ((heap binomial-heap) stream id-vendor)
  (let ((id (next-graphviz-id id-vendor)))
    (format stream "ID~A [label=\"top\"]~%" id)
    (dolist (tree (binomial-heap-ranked-trees heap))
      (let ((child-id (print-graphviz tree stream id-vendor)))
        (format stream "ID~A -> ID~A~%" id child-id)))
    id))

(defmethod for-each ((heap binomial-heap) function)
  (dolist (ranked-tree (binomial-heap-ranked-trees heap))
    (do-tree (item (ranked-tree-tree ranked-tree))
      (funcall function item))))

(defmethod map-members ((heap binomial-heap) function)
  (if (zerop (binomial-heap-size heap))
      heap
      (let (list)
        (for-each heap (lambda (v) (push (funcall function v) list)))
        (make-binomial-heap (binomial-heap-comparator heap)
                            :items list))))

(defmethod iterator ((heap binomial-heap))
  (let ((tree-list (mapcar #'ranked-tree-tree (binomial-heap-ranked-trees heap))))
    (make-heap-iterator tree-list)))

(defmethod comparator ((heap binomial-heap))
  (binomial-heap-comparator heap))

(defmethod print-object ((heap binomial-heap) stream)
  (if *print-readably*
      (call-next-method)
      (print-container heap stream)))

(defun make-binomial-heap (comparator &key items)
  (let (ranked-tree-list
        (count 0))

    ;; Unlike leftist heaps, we can just repeatedly insert the objects
    ;; one by one.  Its O(log(n)) worst case, but O(1) amortized!
    ;; Also, the merging approach seems to be about 3x slower in my
    ;; tests.
    (dolist (item items)
      (incf count)
      (setf ranked-tree-list (insert-object item ranked-tree-list comparator)))

    (%make-binomial-heap
     :comparator comparator
     :size count
     :ranked-trees ranked-tree-list)))

(defun binomial-heap (comparator &rest items)
  (make-binomial-heap comparator :items items))

(defun comparator-min (comparator first second)
  (ecase (funcall comparator first second)
    (:greater
     second)
    ((:less :equal :unequal)
     first)))

(defmethod meld ((first binomial-heap) (second binomial-heap))
  (let ((comparator (binomial-heap-comparator first)))
    (unless (eq comparator (binomial-heap-comparator second))
      (error "Cannot merge heaps with incompatible comparators"))
    (when (zerop (binomial-heap-size first))
      (return-from meld second))
    (when (zerop (binomial-heap-size second))
      (return-from meld first))

    (%make-binomial-heap
     :comparator comparator
     :size (+ (binomial-heap-size first)
              (binomial-heap-size second))
     :ranked-trees (merge-ranked-tree-lists
                    (binomial-heap-ranked-trees first)
                    (binomial-heap-ranked-trees second)
                    comparator))))

(defmethod peek-front ((heap binomial-heap))
  (find-minimum (binomial-heap-ranked-trees heap)
                (binomial-heap-comparator heap)))

(defun binomial-heap-without-front (heap)
  (when (zerop (binomial-heap-size heap))
    (return-from binomial-heap-without-front
      (values heap nil nil)))

  (let ((comparator (binomial-heap-comparator heap)))
    (multiple-value-bind
          (new-ranked-tree-list removed-value success-p)
        (remove-minimum (binomial-heap-ranked-trees heap) comparator)
      (assert success-p nil "Every heap has a minimum")
      (values
       (%make-binomial-heap
        :comparator comparator
        :size (1- (binomial-heap-size heap))
        :ranked-trees new-ranked-tree-list)
       removed-value
       t))))

(defmethod without-front ((heap binomial-heap))
  (binomial-heap-without-front heap))

(defmethod with-member ((heap binomial-heap) item)
  (let ((comparator (binomial-heap-comparator heap)))
    (%make-binomial-heap
     :comparator comparator
     :size (1+ (binomial-heap-size heap))
     :ranked-trees (insert-object item (binomial-heap-ranked-trees heap) comparator))))

(defmethod comparator ((heap binomial-heap))
  (binomial-heap-comparator heap))

(defmethod decompose ((heap binomial-heap))
  (binomial-heap-without-front heap))

(defmethod is-empty ((heap binomial-heap))
  (zerop (binomial-heap-size heap)))

(defmethod empty ((heap binomial-heap))
  (if (zerop (binomial-heap-size heap))
      heap
      (make-binomial-heap (binomial-heap-comparator heap))))

(defun check-rank (tree rank)
  (cassert (equal rank (length (tree-node-children tree)))
           nil "A rank n tree should have n children")
  (loop :for child-rank :from (1- rank) :downto 0
        :for child :in (tree-node-children tree) :do
        (check-rank child child-rank)))

(defun check-order (tree comparator)
  (dolist (child (tree-node-children tree))
    (cassert (not (eq :greater (funcall comparator (tree-node-value tree) (tree-node-value child))))
             nil "Child trees must not be greater than parent trees")))

(defmethod check-invariants ((heap binomial-heap))
  (dolist (ranked-tree (binomial-heap-ranked-trees heap))
    (check-rank (ranked-tree-tree ranked-tree) (ranked-tree-rank ranked-tree))
    (check-order (ranked-tree-tree ranked-tree) (binomial-heap-comparator heap))))

(defmethod size ((heap binomial-heap))
  (binomial-heap-size heap))

(defmethod compare-objects ((left binomial-heap) (right binomial-heap))
  (compare-heaps left (binomial-heap-comparator left)
                 right (binomial-heap-comparator right)
                 #'compare))
