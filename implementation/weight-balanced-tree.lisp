;; Copyright 2020 Ada Avery
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

(defpackage :pfds.shcl.io/implementation/weight-balanced-tree
  (:use :common-lisp)
  (:use :pfds.shcl.io/interface)
  (:import-from :pfds.shcl.io/utility/iterator-tools
   #:compare-sets #:compare-maps #:iterator-flatten #:compare-containers)
  (:import-from :pfds.shcl.io/utility/compare
   #:compare-objects #:compare)
  (:import-from :pfds.shcl.io/utility/immutable-structure
   #:define-immutable-structure #:define-adt)
  (:import-from :pfds.shcl.io/utility/misc
   #:intern-conc #:cassert)
  (:import-from :pfds.shcl.io/utility/printer
   #:print-map #:print-set #:print-sequence)
  (:import-from :pfds.shcl.io/utility/tree
   #:define-tree #:node-left #:node-right #:nil-tree-p)
  (:export
   #:make-weight-balanced-set
   #:weight-balanced-set-p
   #:weight-balanced-set

   #:make-weight-balanced-map
   #:weight-balanced-map-p
   #:weight-balanced-map

   #:make-weight-balanced-sequence
   #:weight-balanced-sequence
   #:weight-balanced-sequence-p))
(in-package :pfds.shcl.io/implementation/weight-balanced-tree)

;; See...
;; - "Implementing Sets Efficiently in a Functional Language" by
;;   Stephen Adams
;; - FSet https://common-lisp.net/project/fset/Site/
;; - Data.Set https://hackage.haskell.org/package/containers-0.6.4.1/docs/src/Data.Set.Internal.html
;; - "Adams' Trees Revisited" by Milan Straka

(declaim (inline omega-balance))
(defun omega-balance ()
  3)

(declaim (inline alpha-balance))
(defun alpha-balance ()
  2)

(defgeneric tree-size (tree))

(defun check-wb-invariants (tree)
  (when (nil-tree-p tree)
    (return-from check-wb-invariants))

  (let* ((left (node-left tree))
         (left-size (tree-size left))
         (right (node-right tree))
         (right-size (tree-size right)))
    (when (<= 2 (+ left-size right-size))
      (cassert (<= right-size (* (omega-balance) left-size)))
      (cassert (<= left-size (* (omega-balance) right-size))))
    (cassert (equal (tree-size tree)
                    (+ 1 left-size right-size)))
    (check-wb-invariants left)
    (check-wb-invariants right)))

(defmacro define-balance-operations (base-name)
  (let ((copy-node-base (intern-conc *package* "COPY-" base-name "-NODE"))
        (nil-type (intern-conc *package* base-name "-NIL"))
        (node-type (intern-conc *package* base-name "-NODE"))
        (node-type-right (intern-conc *package* base-name "-NODE-RIGHT"))
        (node-type-left (intern-conc *package* base-name "-NODE-LEFT"))
        (node-type-size (intern-conc *package* base-name "-NODE-SIZE"))
        (balance (intern-conc *package* base-name "-BALANCE"))
        (rotate-left (gensym "ROTATE-LEFT"))
        (rotate-right (gensym "ROTATE-RIGHT"))
        (rotate-double-left (gensym "ROTATE-DOUBLE-LEFT"))
        (rotate-double-right (gensym "ROTATE-DOUBLE-RIGHT"))
        (size (gensym "SIZE"))
        (copy-node+ (gensym "COPY-NODE+")))
    `(progn
       (declaim (inline ,size))
       (defun ,size (tree)
         (etypecase tree
           (,nil-type
            0)
           (,node-type
            (,node-type-size tree))))

       (declaim (inline ,copy-node+))
       (defun ,copy-node+ (tree &key (left (,node-type-left tree)) (right (,node-type-right tree)))
         (,copy-node-base tree :left left :right right :size (+ 1 (,size left) (,size right))))

       (defun ,rotate-left (tree left right)
         (,copy-node+ right :left (,copy-node+ tree :left left :right (,node-type-left right))))

       (defun ,rotate-right (tree left right)
         (,copy-node+ left :right (,copy-node+ tree :left (,node-type-right left) :right right)))

       (defun ,rotate-double-left (tree left right)
         (let* ((right-left (,node-type-left right))
                (right-left-left (,node-type-left right-left))
                (right-left-right (,node-type-right right-left)))
           (,copy-node+ right-left
                              :left (,copy-node+ tree :left left :right right-left-left)
                              :right (,copy-node+ right :left right-left-right))))

       (defun ,rotate-double-right (tree left right)
         (let* ((left-right (,node-type-right left))
                (left-right-right (,node-type-right left-right))
                (left-right-left (,node-type-left left-right)))
           (,copy-node+ left-right
                              :left (,copy-node+ left :right left-right-left)
                              :right (,copy-node+ tree :left left-right-right :right right))))

       (defun ,balance (tree &key (left (,node-type-left tree)) (right (,node-type-right tree)))
         (let ((left-size (,size left))
               (right-size (,size right)))
           (cond
             ((< (+ left-size right-size) 2)
              (,copy-node+ tree :left left :right right))

             ((> right-size (* (omega-balance) left-size))
              (let ((right-left-size (,size (,node-type-left right)))
                    (right-right-size (,size (,node-type-right right))))
                (if (< right-left-size (* (alpha-balance) right-right-size))
                    (,rotate-left tree left right)
                    (,rotate-double-left tree left right))))

             ((> left-size (* (omega-balance) right-size))
              (let ((left-left-size (,size (,node-type-left left)))
                    (left-right-size (,size (,node-type-right left))))
                (if (< left-right-size (* (alpha-balance) left-left-size))
                    (,rotate-right tree left right)
                    (,rotate-double-right tree left right))))

             (t
              (,copy-node+ tree :left left :right right))))))))

(define-tree wb-set (:map-p nil
                     :insert-left-balancer wb-set-balance
                     :insert-right-balancer wb-set-balance
                     :remove-left-balancer wb-set-balance
                     :remove-right-balancer wb-set-balance)
  (size 1 :type (integer 1)))

(define-balance-operations wb-set)

(define-immutable-structure (weight-balanced-set (:constructor %make-weight-balanced-set))
  (tree (wb-set-nil) :type wb-set)
  ;; The nodes of the tree store the "weight", not that count!  Weight
  ;; is a measure of the size of the tree and ignores multiplicity due
  ;; to unequal items.
  (size 0 :type (integer 0))
  (comparator (error "comparator is required")))

(declare-interface-conformance weight-balanced-set ordered-set)

(defun make-weight-balanced-set (comparator &key items)
  (multiple-value-bind (tree size) (make-wb-set comparator :items items)
    (%make-weight-balanced-set :comparator comparator :tree tree :size size)))

(defun weight-balanced-set (comparator &rest items)
  (make-weight-balanced-set comparator :items items))

(defmethod to-list ((set weight-balanced-set))
  (wb-set-to-list (weight-balanced-set-tree set)))

(defmethod for-each ((set weight-balanced-set) function)
  (do-wb-set (key (weight-balanced-set-tree set))
    (funcall function key)))

(defmethod map-members ((set weight-balanced-set) function)
  (multiple-value-bind (tree size) (wb-set-map-members (weight-balanced-set-comparator set)
                                                       (weight-balanced-set-tree set)
                                                       function)
    (copy-weight-balanced-set set :tree tree :size size)))

(defmethod comparator ((set weight-balanced-set))
  (weight-balanced-set-comparator set))

(defmethod iterator ((set weight-balanced-set))
  (iterator (weight-balanced-set-tree set)))

(defmethod compare-objects ((left weight-balanced-set) (right weight-balanced-set))
  (compare-sets left (weight-balanced-set-comparator left)
                right (weight-balanced-set-comparator right)
                #'compare))

(defmethod is-empty ((set weight-balanced-set))
  (wb-set-nil-p (weight-balanced-set-tree set)))

(defmethod empty ((set weight-balanced-set))
  (copy-weight-balanced-set set :tree (wb-set-nil) :size 0))

(defmethod size ((set weight-balanced-set))
  (weight-balanced-set-size set))

(defmethod tree-size ((empty wb-set-nil))
  0)

(defmethod tree-size ((node wb-set-node))
  (wb-set-node-size node))

(defmethod check-invariants ((set weight-balanced-set))
  (check-wb-set (weight-balanced-set-tree set) (weight-balanced-set-comparator set))
  (check-wb-invariants (weight-balanced-set-tree set)))

(defmethod print-object ((set weight-balanced-set) stream)
  (if *print-readably*
      (call-next-method)
      (print-set set stream)))

(defmethod with-member ((set weight-balanced-set) item)
  (multiple-value-bind
        (tree count-change)
      (wb-set-insert (weight-balanced-set-comparator set) (weight-balanced-set-tree set) item)
    (copy-weight-balanced-set set :tree tree :size (+ count-change (weight-balanced-set-size set)))))

(defmethod decompose ((set weight-balanced-set))
  (multiple-value-bind
        (new-tree value valid-p)
      (wb-set-decompose (weight-balanced-set-tree set))
    (values (copy-weight-balanced-set set :tree new-tree :size (+ (if valid-p -1 0) (weight-balanced-set-size set)))
            value
            valid-p)))

(defmethod without-member ((set weight-balanced-set) item)
  (multiple-value-bind
        (tree value valid-p count-change)
      (wb-set-remove (weight-balanced-set-comparator set) (weight-balanced-set-tree set) item)
    (declare (ignore value))
    (values (copy-weight-balanced-set set :tree tree :size (+ count-change (weight-balanced-set-size set)))
            valid-p)))

(defmethod is-member ((set weight-balanced-set) item)
  (wb-set-lookup (weight-balanced-set-comparator set) (weight-balanced-set-tree set) item))

(defmethod print-graphviz ((set weight-balanced-set) stream id-vendor)
  (print-graphviz (weight-balanced-set-tree set) stream id-vendor))

(define-tree wb-map (:map-p t
                     :insert-left-balancer wb-map-balance
                     :insert-right-balancer wb-map-balance
                     :remove-left-balancer wb-map-balance
                     :remove-right-balancer wb-map-balance)
  (size 1 :type (integer 1)))

(define-balance-operations wb-map)

(define-immutable-structure (weight-balanced-map (:constructor %make-weight-balanced-map))
  (tree (wb-map-nil) :type wb-map)
  (size 0 :type (integer 0))
  (comparator (error "comparator is required")))

(declare-interface-conformance weight-balanced-map ordered-map)

(defun make-weight-balanced-map (comparator &key alist plist)
  (multiple-value-bind (tree size) (make-wb-map comparator :alist alist :plist plist)
    (%make-weight-balanced-map :comparator comparator :tree tree :size size)))

(defun weight-balanced-map (comparator &rest plist)
  (make-weight-balanced-map comparator :plist plist))

(defmethod to-list ((map weight-balanced-map))
  (wb-map-to-list (weight-balanced-map-tree map)))

(defmethod for-each ((map weight-balanced-map) function)
  (do-wb-map (key value (weight-balanced-map-tree map))
    (funcall function (cons key value))))

(defmethod for-each-entry ((map weight-balanced-map) function)
  (do-wb-map (key value (weight-balanced-map-tree map))
    (funcall function key value)))

(defmethod map-entries ((map weight-balanced-map) function)
  (copy-weight-balanced-map map :tree (wb-map-map-entries (weight-balanced-map-tree map) function)))

(defmethod map-members ((map weight-balanced-map) function)
  (multiple-value-bind (tree size) (wb-map-map-members (weight-balanced-map-comparator map)
                                                       (weight-balanced-map-tree map)
                                                       function)
    (copy-weight-balanced-map map :tree tree :size size)))

(defmethod with-member ((map weight-balanced-map) pair)
  (check-type pair cons)
  (multiple-value-bind (tree count-change)
      (wb-map-insert (weight-balanced-map-comparator map)
                     (weight-balanced-map-tree map)
                     (car pair)
                     (cdr pair))
    (copy-weight-balanced-map map :tree tree :size (+ count-change (weight-balanced-map-size map)))))

(defmethod member-type ((map weight-balanced-map))
  '(cons t t))

(defmethod decompose ((map weight-balanced-map))
  (multiple-value-bind
        (new-tree value valid-p)
      (wb-map-decompose (weight-balanced-map-tree map))
    (values (copy-weight-balanced-map map :tree new-tree :size (+ (if valid-p -1 0) (weight-balanced-map-size map)))
            value
            valid-p)))

(defmethod comparator ((map weight-balanced-map))
  (weight-balanced-map-comparator map))

(defmethod iterator ((map weight-balanced-map))
  (iterator (weight-balanced-map-tree map)))

(defmethod compare-objects ((left weight-balanced-map) (right weight-balanced-map))
  (compare-maps left (weight-balanced-map-comparator left)
                right (weight-balanced-map-comparator right)
                #'compare #'compare))

(defmethod is-empty ((map weight-balanced-map))
  (wb-map-nil-p (weight-balanced-map-tree map)))

(defmethod empty ((map weight-balanced-map))
  (copy-weight-balanced-map map :tree (wb-map-nil) :size 0))

(defmethod size ((map weight-balanced-map))
  (weight-balanced-map-size map))

(defmethod tree-size ((empty wb-map-nil))
  0)

(defmethod tree-size ((node wb-map-node))
  (wb-map-node-size node))

(defmethod check-invariants ((map weight-balanced-map))
  (check-wb-map (weight-balanced-map-tree map) (weight-balanced-map-comparator map))
  (check-wb-invariants (weight-balanced-map-tree map)))

(defmethod print-object ((map weight-balanced-map) stream)
  (if *print-readably*
      (call-next-method)
      (print-map map stream)))

(defmethod with-entry ((map weight-balanced-map) key value)
  (multiple-value-bind
        (tree count-change)
      (wb-map-insert (weight-balanced-map-comparator map) (weight-balanced-map-tree map) key value)
    (copy-weight-balanced-map map :tree tree :size (+ count-change (weight-balanced-map-size map)))))

(defmethod without-entry ((map weight-balanced-map) key)
  (multiple-value-bind
        (new-tree value valid-p count-change)
      (wb-map-remove (weight-balanced-map-comparator map) (weight-balanced-map-tree map) key)
    (values (copy-weight-balanced-map map :tree new-tree :size (+ count-change (weight-balanced-map-size map)))
            value
            valid-p)))

(defmethod lookup-entry ((map weight-balanced-map) key)
  (wb-map-lookup (weight-balanced-map-comparator map) (weight-balanced-map-tree map) key))

(defmethod print-graphviz ((map weight-balanced-map) stream id-vendor)
  (print-graphviz (weight-balanced-map-tree map) stream id-vendor))

(defvar *max-array-length* 32)

(deftype wb-seq ()
  '(or null wb-seq-node simple-array string))

(deftype non-empty-wb-seq ()
  '(or wb-seq-node simple-array string))

(define-immutable-structure (wb-seq-node (:constructor %make-wb-seq-node))
  (left nil :type non-empty-wb-seq)
  (right nil :type non-empty-wb-seq)
  (size 1 :type (integer 1)))

(defun wb-seq-size (tree)
  (etypecase tree
    (null
     0)
    (wb-seq-node
     (wb-seq-node-size tree))
    (array
     (length tree))))

(defun make-wb-seq-node (&key left right)
  (%make-wb-seq-node :left left
                     :right right
                     :size (+ (wb-seq-size left)
                              (wb-seq-size right))))

(defun wb-seq-concat-arrays (left right)
  (if (and (or (stringp left) (null left))
           (or (stringp right) (null right)))
      (concatenate 'string left right)
      (concatenate 'vector left right)))

(defun maybe-stringify (array)
  (if (and (not (stringp array))
           (loop :for object :across array
                 :do (unless (characterp object)
                       (return nil))
                 :finally (return t)))
      (coerce array 'string)
      array))

(defun make-wb-seq-node-splitting-arrays (left right)
  (let ((total-items (+ (length left) (length right))))
    (multiple-value-bind (first-length remainder) (floor total-items 2)
      (labels
          ((get-nth (index)
             (if (>= index (length left))
                 (aref right (- index (length left)))
                 (aref left index))))
        (let* ((first-string-p
                 (loop :for i :below first-length
                       :do (unless (characterp (get-nth i))
                             (return nil))
                       :finally (return t)))
               (second-string-p
                 (loop :for i :from first-length :below total-items
                       :do (unless (characterp (get-nth i))
                             (return nil))
                       :finally (return t)))
               (new-left (if first-string-p
                             (make-array first-length :element-type 'character)
                             (make-array first-length)))
               (new-right (if second-string-p
                              (make-array (+ first-length remainder) :element-type 'character)
                              (make-array (+ first-length remainder))))
               (target-offset 0)
               (target-array new-left))
          (labels
              ((store (item)
                 (when (>= target-offset (length target-array))
                   (assert (eq target-array new-left))
                   (setf target-array new-right)
                   (setf target-offset 0))
                 (setf (aref target-array target-offset) item)
                 (incf target-offset)))
            (declare (dynamic-extent #'store))
            (loop :for item :across left :do
              (store item))
            (loop :for item :across right :do
              (store item)))
          (%make-wb-seq-node :left new-left
                             :right new-right
                             :size total-items))))))

(defun wb-seq-rotate-left (left right)
  (make-wb-seq-node :left (make-wb-seq left (wb-seq-node-left right))
                    :right (wb-seq-node-right right)))

(defun wb-seq-rotate-double-left (left right)
  (let* ((right-left (wb-seq-node-left right))
         (right-left (if (arrayp right-left)
                         (make-wb-seq-node-splitting-arrays right-left #())
                         right-left))
         (right-left-left (wb-seq-node-left right-left))
         (right-left-right (wb-seq-node-right right-left)))
    (make-wb-seq-node :left (make-wb-seq left right-left-left)
                      :right (make-wb-seq right-left-right (wb-seq-node-right right)))))

(defun wb-seq-rotate-right (left right)
  (make-wb-seq-node :left (wb-seq-node-left left)
                    :right (make-wb-seq (wb-seq-node-right left) right)))

(defun wb-seq-rotate-double-right (left right)
  (let* ((left-right (wb-seq-node-right left))
         (left-right (if (arrayp left-right)
                         (make-wb-seq-node-splitting-arrays left-right #())
                         left-right))
         (left-right-right (wb-seq-node-right left-right))
         (left-right-left (wb-seq-node-left left-right)))
    (make-wb-seq-node :left (make-wb-seq (wb-seq-node-left left) left-right-left)
                      :right (make-wb-seq left-right-right right))))

(defun make-wb-seq (left right)
  (let* ((left-size (wb-seq-size left))
         (right-size (wb-seq-size right))
         (total-items (+ left-size right-size)))
    (cond
      ((zerop right-size)
       left)
      ((zerop left-size)
       right)

      ((and (arrayp left) (arrayp right))
       (cond
         ((<= total-items *max-array-length*)
          (wb-seq-concat-arrays left right))
         ((or (> right-size (* (omega-balance) left-size))
              (> left-size (* (omega-balance) right-size)))
          (make-wb-seq-node-splitting-arrays left right))
         (t
          (%make-wb-seq-node :left left :right right :size total-items))))

      ((> right-size (* (omega-balance) left-size))
       (let ((right-left-size (wb-seq-size (wb-seq-node-left right)))
             (right-right-size (wb-seq-size (wb-seq-node-right right))))
         (if (< right-left-size (* (alpha-balance) right-right-size))
             (wb-seq-rotate-left left right)
             (wb-seq-rotate-double-left left right))))

      ((> left-size (* (omega-balance) right-size))
       (let ((left-left-size (wb-seq-size (wb-seq-node-left left)))
             (left-right-size (wb-seq-size (wb-seq-node-right left))))
         (if (< left-right-size (* (alpha-balance) left-left-size))
             (wb-seq-rotate-right left right)
             (wb-seq-rotate-double-right left right))))

      (t
       (%make-wb-seq-node :left left :right right :size total-items)))))

(defun wb-seq-left-size (tree)
  (wb-seq-size (wb-seq-node-left tree)))

(defun wb-seq-store (tree index value)
  (cond
    ((null tree)
     (error "Index out of bounds!"))
    ((arrayp tree)
     (cond
       ((eql value (aref tree index))
        tree)
       ((and (stringp tree)
             (characterp value))
        (let ((result (copy-seq tree)))
          (setf (aref result index) value)
          result))
       (t
        (let ((result (if (stringp tree)
                          (coerce tree '(vector t))
                          (copy-seq tree))))
          (setf (aref result index) value)
          (if (characterp value)
              (maybe-stringify result)
              result)))))
    (t
     (let ((left-weight (wb-seq-left-size tree)))
       (cond
         ((< index left-weight)
          (let* ((old-left (wb-seq-node-left tree))
                 (new-left (wb-seq-store old-left index value)))
            (if (eq new-left old-left)
                tree
                (make-wb-seq new-left (wb-seq-node-right tree)))))
         (t
          (let* ((old-right (wb-seq-node-right tree))
                 (new-right (wb-seq-store old-right (- index left-weight) value)))
            (if (eq old-right new-right)
                tree
                (make-wb-seq (wb-seq-node-left tree) new-right)))))))))

(defun wb-seq-concatenate (left right)
  (cond
    ((null left)
     right)
    ((null right)
     left)

    ((and (wb-seq-node-p left)
          (> (wb-seq-size left) (* (omega-balance) (wb-seq-size right))))
     (make-wb-seq (wb-seq-node-left left)
                  (wb-seq-concatenate (wb-seq-node-right left) right)))

    ((and (wb-seq-node-p right)
          (> (wb-seq-size right) (* (omega-balance) (wb-seq-size left))))
     (make-wb-seq (wb-seq-concatenate left (wb-seq-node-left right))
                  (wb-seq-node-right right)))

    (t
     (make-wb-seq left right))))

(defun wb-seq-with-first (sequence object)
  (wb-seq-insert sequence 0 object))

(defun wb-seq-with-last (sequence object)
  (wb-seq-insert sequence (wb-seq-size sequence) object))

(defun wb-seq-remove (tree index)
  (etypecase tree
    (array
     (assert (and (>= index 0)
                  (< index (length tree))))
     (cond
       ((equal 1 (length tree))
        (values nil (aref tree 0)))

       (t
        (let ((new-array (if (stringp tree)
                             (make-array (1- (length tree)) :element-type 'character)
                             (make-array (1- (length tree))))))
          (loop :for i :below index :do
            (setf (aref new-array i) (aref tree i)))
          (loop :for i :from (1+ index) :below (length tree) :do
            (setf (aref new-array (1- i)) (aref tree i)))
          (values (maybe-stringify new-array) (aref tree index))))))

    (wb-seq-node
     (let ((left-size (wb-seq-left-size tree)))
       (if (>= index left-size)
           (multiple-value-bind (new-right removed-value) (wb-seq-remove (wb-seq-node-right tree) (- index left-size))
             (values (make-wb-seq (wb-seq-node-left tree) new-right) removed-value t))
           (multiple-value-bind (new-left removed-value) (wb-seq-remove (wb-seq-node-left tree) index)
             (values (make-wb-seq new-left (wb-seq-node-right tree)) removed-value t)))))))

(defun array-insert (array before-index object)
  (cond
    ((<= (1+ (length array)) *max-array-length*)
     (let ((result (make-array (1+ (length array)) :element-type (if (and (stringp array) (characterp object))
                                                                     'character
                                                                     t))))
       (loop :for i :below before-index :do
         (setf (aref result i) (aref array i)))
       (setf (aref result before-index) object)
       (loop :for i :from before-index :below (length array) :do
         (setf (aref result (1+ i)) (aref array i)))
       result))

    (t
     (assert (equal *max-array-length* (length array)))
     (let* ((split-point (floor *max-array-length* 2))
            (first-half (subseq array 0 split-point))
            (second-half (subseq array split-point)))
       (cond
         ((<= before-index split-point)
          (setf second-half (maybe-stringify second-half))
          (setf first-half (array-insert (if (characterp object)
                                             (maybe-stringify first-half)
                                             first-half)
                                         before-index
                                         object)))
         (t
          (setf first-half (maybe-stringify first-half))
          (setf second-half (array-insert (if (characterp object)
                                              (maybe-stringify second-half)
                                              second-half)
                                          (- before-index split-point)
                                          object))))
       (wb-seq-concatenate first-half second-half)))))

(defun wb-seq-insert (tree before-index object)
  (etypecase tree
    (null
     (assert (zerop before-index))
     (if (characterp object)
         (string object)
         (make-array 1 :initial-element object)))

    (array
     (array-insert tree before-index object))

    (wb-seq-node
     (let ((left-size (wb-seq-left-size tree)))
       (if (>= before-index left-size)
           (make-wb-seq (wb-seq-node-left tree)
                        (wb-seq-insert (wb-seq-node-right tree) (- before-index left-size) object))
           (make-wb-seq (wb-seq-insert (wb-seq-node-left tree) before-index object)
                        (wb-seq-node-right tree)))))))

(defun wb-seq-lookup (tree index)
  (etypecase tree
    (wb-seq-node
     (let ((left-size (wb-seq-left-size tree)))
       (if (>= index left-size)
           (wb-seq-lookup (wb-seq-node-right tree) (- index left-size))
           (wb-seq-lookup (wb-seq-node-left tree) index))))
    (array
     (values (aref tree index) t))))

(defun wb-seq-subseq (tree min max)
  (let ((here-size (wb-seq-size tree)))
    (when (and (equal 0 min)
               (equal here-size max))
      (return-from wb-seq-subseq tree)))

  (etypecase tree
    (wb-seq-node
     (let* ((left-size (wb-seq-left-size tree))
            (left-touched-p (< min left-size))
            (right-touched-p (> max left-size)))
       (cond
         ((and left-touched-p right-touched-p)
          (wb-seq-concatenate (wb-seq-subseq (wb-seq-node-left tree) min left-size)
                              (wb-seq-subseq (wb-seq-node-right tree) 0 (- max left-size))))
         (left-touched-p
          (wb-seq-subseq (wb-seq-node-left tree) min max))
         (right-touched-p
          (wb-seq-subseq (wb-seq-node-right tree) (- min left-size) (- max left-size))))))
    (array
     (subseq tree min max))))

(defun wb-seq-for-each (tree function offset)
  (etypecase tree
    (wb-seq-node
     (let ((left (wb-seq-node-left tree))
           (right (wb-seq-node-right tree)))
       (wb-seq-for-each left function offset)
       (wb-seq-for-each right function (+ offset (wb-seq-size left)))))
    (array
     (loop :for object :across tree
           :for index :from offset
           :do (funcall function index object)))
    (null)))

(defun wb-seq-map-entries (tree function offset)
  (etypecase tree
    (wb-seq-node
     (let* ((left (wb-seq-node-left tree))
            (new-left (wb-seq-map-entries left function offset))
            (right (wb-seq-node-right tree))
            (new-right (wb-seq-map-entries right function (+ offset (wb-seq-size left)))))
       (copy-wb-seq-node tree :left new-left :right new-right)))

    (array
     (let ((new-vector (make-array (length tree)))
           (all-eql t))
       (loop :for object :across tree
             :for index :from offset
             :for vector-index :from 0
             :do (progn
                   (let ((new-value (funcall function index object)))
                     (unless (eql new-value object)
                       (setf all-eql nil))
                     (setf (aref new-vector vector-index) new-value))))
       (if all-eql
           tree
           (maybe-stringify new-vector))))

    (null)))

(define-immutable-structure (weight-balanced-sequence (:constructor %make-weight-balanced-sequnce))
  (tree nil :type wb-seq))

(declare-interface-conformance weight-balanced-sequence sequence)

(defvar *empty-weight-balanced-sequence* (%make-weight-balanced-sequnce))

(defmethod for-each ((seq weight-balanced-sequence) function)
  (wb-seq-for-each (weight-balanced-sequence-tree seq)
                   (lambda (k v)
                     (declare (ignore k))
                     (funcall function v))
                   0))

(defmethod for-each-entry ((seq weight-balanced-sequence) function)
  (wb-seq-for-each (weight-balanced-sequence-tree seq) function 0))

(defmethod map-entries ((seq weight-balanced-sequence) function)
  (copy-weight-balanced-sequence seq :tree (wb-seq-map-entries (weight-balanced-sequence-tree seq) function 0)))

(defmethod map-members ((seq weight-balanced-sequence) function)
  (labels
      ((wrapper (k v)
         (declare (ignore k))
         (funcall function v)))
    (copy-weight-balanced-sequence seq :tree (wb-seq-map-entries (weight-balanced-sequence-tree seq) #'wrapper 0))))

(defmethod size ((seq weight-balanced-sequence))
  (wb-seq-size (weight-balanced-sequence-tree seq)))

(defmethod is-empty ((seq weight-balanced-sequence))
  (null (weight-balanced-sequence-tree seq)))

(defmethod empty ((seq weight-balanced-sequence))
  *empty-weight-balanced-sequence*)

(defmethod with-member ((seq weight-balanced-sequence) item)
  (%make-weight-balanced-sequnce :tree (wb-seq-with-last (weight-balanced-sequence-tree seq) item)))

(defmethod decompose ((seq weight-balanced-sequence))
  (weight-balanced-sequence-remove-entry seq (1- (wb-seq-size (weight-balanced-sequence-tree seq)))))

(defun array-iterator (array)
  (let ((offset 0))
    (lambda ()
      (if (>= offset (length array))
          (values nil nil)
          (let ((object (aref array offset)))
            (incf offset)
            (values object t))))))

(defun %wb-seq-iterator (tree)
  (let ((stack (list (list (wb-seq-node-left tree) (wb-seq-node-right tree)))))
    (lambda ()
      (loop
        (if (null stack)
            (return (values nil nil))
            (let* ((tip (car stack))
                   (left (first tip))
                   (right (second tip)))
              (cond
                (left
                 (setf (first tip) nil)
                 (if (wb-seq-node-p left)
                     (push (list (wb-seq-node-left left) (wb-seq-node-right left))
                           stack)
                     (return (values (array-iterator left) t))))
                (right
                 (pop stack)
                 (if (wb-seq-node-p right)
                     (push (list (wb-seq-node-left right) (wb-seq-node-right right))
                           stack)
                     (return (values (array-iterator right) t))))
                (t
                 (assert nil nil "both left and right can't be nil!")))))))))

(defun wb-seq-iterator (tree)
  (etypecase tree
    (null
     (lambda ()
       (values nil nil)))

    (array
     (array-iterator tree))

    (wb-seq-node
     (iterator-flatten (%wb-seq-iterator tree)))))

(defmethod iterator ((seq weight-balanced-sequence))
  (wb-seq-iterator (weight-balanced-sequence-tree seq)))

(defmethod print-object ((seq weight-balanced-sequence) stream)
  (if *print-readably*
      (call-next-method)
      (print-sequence seq stream)))

(defun make-weight-balanced-sequence (&key items)
  (unless items
    (return-from make-weight-balanced-sequence
      *empty-weight-balanced-sequence*))
  (let (tree
        (wip-node (make-array *max-array-length* :fill-pointer 0))
        (wip-node-string-p t))
    (dolist (item items)
      (when (>= (length wip-node) *max-array-length*)
        (setf tree (wb-seq-concatenate tree (if wip-node-string-p
                                                (coerce wip-node 'string)
                                                (make-array (length wip-node) :initial-contents wip-node))))
        (setf wip-node (make-array *max-array-length* :fill-pointer 0))
        (setf wip-node-string-p t))
      (unless (characterp item)
        (setf wip-node-string-p nil))
      (vector-push item wip-node))

    (setf tree (wb-seq-concatenate tree (if wip-node-string-p
                                            (coerce wip-node 'string)
                                            (make-array (length wip-node) :initial-contents wip-node))))

    (%make-weight-balanced-sequnce :tree tree)))

(defun weight-balanced-sequence (&rest items)
  (make-weight-balanced-sequence :items items))

(defmethod with-entry ((seq weight-balanced-sequence) index value)
  (if (equal index (wb-seq-size (weight-balanced-sequence-tree seq)))
      (%make-weight-balanced-sequnce :tree (wb-seq-with-last (weight-balanced-sequence-tree seq) value))
      (copy-weight-balanced-sequence seq :tree (wb-seq-store (weight-balanced-sequence-tree seq) index value))))

(defun weight-balanced-sequence-remove-entry (seq index)
  (let* ((tree (weight-balanced-sequence-tree seq))
         (size (wb-seq-size tree)))
    (cond
      ((or (< index 0)
           (>= index size))
       (values seq nil nil))

      (t
       (multiple-value-bind (new-tree removed-value) (wb-seq-remove tree index)
         (values
          (if new-tree
              (%make-weight-balanced-sequnce :tree new-tree)
              *empty-weight-balanced-sequence*)
          removed-value
          t))))))

(declaim (inline weight-balanced-sequence-size))
(defun weight-balanced-sequence-size (seq)
  (wb-seq-size (weight-balanced-sequence-tree seq)))

(defun weight-balanced-sequence-lookup-entry (seq index)
  (let* ((tree (weight-balanced-sequence-tree seq))
         (size (wb-seq-size tree)))
    (if (or (> 0 index)
            (>= index size))
        (values nil nil)
        (wb-seq-lookup tree index))))

(defmethod without-entry ((seq weight-balanced-sequence) index)
  (weight-balanced-sequence-remove-entry seq index))

(defmethod lookup-entry ((seq weight-balanced-sequence) index)
  (weight-balanced-sequence-lookup-entry seq index))

(defmethod with-top ((seq weight-balanced-sequence) value)
  (%make-weight-balanced-sequnce :tree (wb-seq-with-last (weight-balanced-sequence-tree seq) value)))

(defmethod peek-top ((seq weight-balanced-sequence))
  (weight-balanced-sequence-lookup-entry seq (1- (weight-balanced-sequence-size seq))))

(defmethod without-top ((seq weight-balanced-sequence))
  (weight-balanced-sequence-remove-entry seq (1- (wb-seq-size (weight-balanced-sequence-tree seq)))))

(defmethod with-first ((seq weight-balanced-sequence) value)
  (%make-weight-balanced-sequnce :tree (wb-seq-with-first (weight-balanced-sequence-tree seq) value)))

(defmethod with-last ((seq weight-balanced-sequence) value)
  (%make-weight-balanced-sequnce :tree (wb-seq-with-last (weight-balanced-sequence-tree seq) value)))

(defmethod without-first ((seq weight-balanced-sequence))
  (weight-balanced-sequence-remove-entry seq 0))

(defmethod without-last ((seq weight-balanced-sequence))
  (weight-balanced-sequence-remove-entry seq (1- (wb-seq-size (weight-balanced-sequence-tree seq)))))

(defmethod peek-first ((seq weight-balanced-sequence))
  (weight-balanced-sequence-lookup-entry seq 0))

(defmethod peek-last ((seq weight-balanced-sequence))
  (weight-balanced-sequence-lookup-entry seq (1- (weight-balanced-sequence-size seq))))

(defmethod compare-objects ((left weight-balanced-sequence) (right weight-balanced-sequence))
  (compare-containers left right #'compare))

(defmethod insert ((seq weight-balanced-sequence) before-index object)
  (check-type before-index (integer 0))
  (let ((tree (weight-balanced-sequence-tree seq)))
    (when (> before-index (wb-seq-size tree))
      (error "before-index is out of bounds: ~A" before-index))
    (%make-weight-balanced-sequnce :tree (wb-seq-insert tree before-index object))))

(defmethod join ((left weight-balanced-sequence) (right weight-balanced-sequence))
  (let ((tree (wb-seq-concatenate (weight-balanced-sequence-tree left)
                                  (weight-balanced-sequence-tree right))))
    (if tree
        (%make-weight-balanced-sequnce :tree tree)
        *empty-weight-balanced-sequence*)))

(defmethod join ((seq weight-balanced-sequence) other)
  (let ((tree (weight-balanced-sequence-tree seq)))
    (do-each (value other)
      (setf tree (wb-seq-with-last tree value)))
    (if tree
        (%make-weight-balanced-sequnce :tree tree)
        *empty-weight-balanced-sequence*)))

(defmethod subsequence ((seq weight-balanced-sequence) min max)
  (check-type min (integer 0))
  (check-type max (or null (integer 0)))
  (let* ((tree (weight-balanced-sequence-tree seq))
         (count (wb-seq-size tree)))
    (unless max
      (setf max count))

    (when (> max count)
      (error "max is out of bounds: ~A" max))

    (when (< max min)
      (error "bounds are invalid: min ~A, max ~A" min max))

    (cond
      ((equal min max)
       *empty-weight-balanced-sequence*)

      ((and (zerop min)
            (equal max count))
       seq)

      (t
       (%make-weight-balanced-sequnce :tree (wb-seq-subseq tree min max))))))

(defmethod with-front ((seq weight-balanced-sequence) value)
  (%make-weight-balanced-sequnce :tree (wb-seq-with-first (weight-balanced-sequence-tree seq) value)))

(defmethod with-back ((seq weight-balanced-sequence) value)
  (%make-weight-balanced-sequnce :tree (wb-seq-with-last (weight-balanced-sequence-tree seq) value)))

(defmethod without-front ((seq weight-balanced-sequence))
  (weight-balanced-sequence-remove-entry seq 0))

(defmethod without-back ((seq weight-balanced-sequence))
  (weight-balanced-sequence-remove-entry seq (1- (wb-seq-size (weight-balanced-sequence-tree seq)))))

(defmethod without-front ((seq weight-balanced-sequence))
  (weight-balanced-sequence-remove-entry seq 0))

(defmethod peek-front ((seq weight-balanced-sequence))
  (weight-balanced-sequence-lookup-entry seq 0))

(defmethod peek-back ((seq weight-balanced-sequence))
  (weight-balanced-sequence-lookup-entry seq (1- (weight-balanced-sequence-size seq))))

(defun wb-seq-print-graphviz (tree stream id-vendor)
  (let ((id (next-graphviz-id id-vendor)))
    (etypecase tree
      (null
       (format stream "ID~A [label=\"~A\"]~%" id nil)
       id)
      (wb-seq-node
       (format stream "ID~A [label=\"~A\"]~%" id (wb-seq-size tree))
       (let ((child-id (wb-seq-print-graphviz (wb-seq-node-left tree) stream id-vendor)))
         (format stream "ID~A -> ID~A~%" id child-id))
       (let ((child-id (wb-seq-print-graphviz (wb-seq-node-right tree) stream id-vendor)))
         (format stream "ID~A -> ID~A~%" id child-id))
       id)
      (array
       (format stream "ID~A [label=\"~A\" shape=box]~%" id tree)
       id))))

(defmethod print-graphviz ((seq weight-balanced-sequence) stream id-vendor)
  (wb-seq-print-graphviz (weight-balanced-sequence-tree seq) stream id-vendor))

(defun check-wb-seq-invariants (tree)
  (etypecase tree
    (null)
    (array
     (cassert (eq tree (maybe-stringify tree))))
    (wb-seq-node
     (let* ((left (wb-seq-node-left tree))
            (left-size (wb-seq-size left))
            (right (wb-seq-node-right tree))
            (right-size (wb-seq-size right)))
       (cassert (<= right-size (* (omega-balance) left-size)))
       (cassert (<= left-size (* (omega-balance) right-size)))
       (cassert (equal (wb-seq-size tree)
                       (+ left-size right-size)))
       (check-wb-seq-invariants left)
       (check-wb-seq-invariants right)))))

(defmethod check-invariants ((seq weight-balanced-sequence))
  (check-wb-seq-invariants (weight-balanced-sequence-tree seq)))
