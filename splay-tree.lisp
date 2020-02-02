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

(defpackage :pfds.shcl.io/splay-tree
  (:use :common-lisp)
  (:import-from :pfds.shcl.io/common
   #:to-list #:check-invariants)
  (:import-from :pfds.shcl.io/impure-list-builder
   #:make-impure-list-builder #:impure-list-builder-add
   #:impure-list-builder-extract)
  (:import-from :pfds.shcl.io/tree
   #:define-tree #:print-graphviz)
  (:import-from :pfds.shcl.io/utility
   #:intern-conc #:cassert)
  (:import-from :pfds.shcl.io/list-utility
   #:list-set-is-member #:list-map-lookup)
  (:import-from :pfds.shcl.io/structure-mop
   #:define-struct)
  (:import-from :pfds.shcl.io/immutable-structure
   #:define-immutable-structure)
  (:import-from :pfds.shcl.io/heap
   #:merge-heaps #:heap-top #:without-heap-top
   #:with-member #:is-empty #:empty)
  (:export
   #:impure-splay-set
   #:make-impure-splay-set
   #:make-impure-splay-set*
   #:copy-impure-splay-set
   #:impure-splay-set-p
   #:impure-splay-set-comparator
   #:impure-splay-set-is-empty
   #:impure-splay-set-insert
   #:impure-splay-set-remove
   #:impure-splay-set-remove-all
   #:impure-splay-set-is-member
   #:impure-splay-set-to-list

   #:impure-splay-map
   #:make-impure-splay-map
   #:make-impure-splay-map*
   #:copy-impure-splay-map
   #:impure-splay-map-p
   #:impure-splay-map-comparator
   #:impure-splay-map-is-empty
   #:impure-splay-map-insert
   #:impure-splay-map-remove
   #:impure-splay-map-remove-all
   #:impure-splay-map-lookup
   #:impure-splay-map-to-list

   #:splay-heap
   #:splay-heap-p
   #:make-splay-heap
   #:make-splay-heap*
   #:merge-heaps
   #:heap-top
   #:without-heap-top
   #:with-member
   #:is-empty
   #:empty))
(in-package :pfds.shcl.io/splay-tree)

(define-tree sp-set (:map-p nil
                     :define-insert-p nil
                     :define-remove-p nil
                     :define-maker-p nil
                     :define-lookup-p nil))

(define-tree sp-map (:map-p t
                     :define-insert-p nil
                     :define-remove-p nil
                     :define-maker-p nil
                     :define-lookup-p nil))

(defmacro define-splay-operations (base-name &key map-p)
  (let* ((splay (intern-conc *package* base-name "-SPLAY"))
         (splay-inner (gensym "SPLAY"))
         (nil-p (intern-conc *package* base-name "-NIL-P"))
         (nil-type (intern-conc *package* base-name "-NIL"))
         (representative (intern-conc *package* base-name "-NODE-REPRESENTATIVE"))
         (left (intern-conc *package* base-name "-NODE-LEFT"))
         (right (intern-conc *package* base-name "-NODE-RIGHT"))
         (node-copy (intern-conc *package* "COPY-" base-name "-NODE"))
         (value (when map-p (gensym "VALUE")))
         (value-list (when map-p (list value)))
         (insert (intern-conc *package* base-name "-INSERT"))
         (remove (intern-conc *package* base-name "-REMOVE"))
         (lookup (intern-conc *package* base-name "-LOOKUP"))
         (node-1-type (intern-conc *package* base-name "-NODE-1"))
         (make-node-1 (intern-conc *package* "MAKE-" node-1-type))
         (node-1-value (when map-p (intern-conc *package* node-1-type "-VALUE")))
         (node-n-type (intern-conc *package* base-name "-NODE-N"))
         (node-n-values (intern-conc *package* node-n-type "-VALUES"))
         (with-key (intern-conc *package* base-name "-NODE-WITH-KEY"))
         (without-key (intern-conc *package* base-name "-NODE-WITHOUT-KEY"))
         (join (intern-conc *package* base-name "-JOIN")))
    `(progn
       (defun ,splay (comparator tree pivot)
         (labels
             ;; This function has a slightly convoluted signature.
             ;; You can think of this function as taking a tree to
             ;; operate on and returning two values: the result of
             ;; performing the splay and how the pivot compared
             ;; against the value that has been splayed to the top of
             ;; the tree.  If the pivot wasn't found then this
             ;; function splays up the closest value encountered on
             ;; the search path.

             ;; In reality, this function actually returns a
             ;; description of the resulting tree using 3 separate
             ;; values: the left child, the central node, and the
             ;; right child.  The fourth return value captures the
             ;; comparison result described earlier.

             ;; Unless we happen to be operating on the root node,
             ;; actually consing up the value prior to return is just
             ;; a waste.  The next call to splay-inner on the stack
             ;; will just want to break apart the tree to perform a
             ;; rotation!  By returning the ingredients that would go
             ;; into making the tree, we avoid that unnecessary
             ;; allocation and give the calling function the
             ;; information it conveniently needed anyway.
             ((,splay-inner (tree)
                (assert (not (,nil-p tree)))

                (let ((first-comparison (funcall comparator (,representative tree) pivot)))
                  (ecase first-comparison
                    ((:equal :unequal)
                     (values (,left tree)
                             tree
                             (,right tree)
                             first-comparison))

                    (:less
                     (let ((right (,right tree)))
                       (when (,nil-p right)
                         (return-from ,splay-inner
                           (values (,left tree)
                                   tree
                                   right
                                   first-comparison)))

                       (let ((second-comparison (funcall comparator (,representative right) pivot)))
                         (ecase second-comparison
                           ((:equal :unequal)
                            (values (,node-copy tree :right (,left right))
                                    right
                                    (,right right)
                                    second-comparison))

                           (:less
                            (let ((target (,right right)))
                              (when (,nil-p target)
                                (return-from ,splay-inner
                                  (values (,node-copy tree :right (,left right))
                                          right
                                          (,right right)
                                          second-comparison)))

                              (multiple-value-bind (small center big comparison) (,splay-inner target)
                                (values
                                 (,node-copy right
                                             :left (,node-copy tree :right (,left right))
                                             :right small)
                                 center
                                 big
                                 comparison))))

                           (:greater
                            (let ((target (,left right)))
                              (when (,nil-p target)
                                (return-from ,splay-inner
                                  (values (,node-copy tree :right (,left right))
                                          right
                                          (,right right)
                                          second-comparison)))

                              (multiple-value-bind (small center big comparison) (,splay-inner target)
                                (values
                                 (,node-copy tree :right small)
                                 center
                                 (,node-copy right :left big)
                                 comparison))))))))

                    (:greater
                     (let ((left (,left tree)))
                       (when (,nil-p left)
                         (return-from ,splay-inner
                           (values left
                                   tree
                                   (,right tree)
                                   first-comparison)))

                       (let ((second-comparison (funcall comparator (,representative left) pivot)))
                         (ecase second-comparison
                           ((:unequal :equal)
                            (values (,left left)
                                    left
                                    (,node-copy tree :left (,right left))
                                    second-comparison))

                           (:less
                            (let ((target (,right left)))
                              (when (,nil-p target)
                                (return-from ,splay-inner
                                  (values (,left left)
                                          left
                                          (,node-copy tree :left (,right left))
                                          second-comparison)))

                              (multiple-value-bind (small center big comparison) (,splay-inner target)
                                (values
                                 (,node-copy left :right small)
                                 center
                                 (,node-copy tree :left big)
                                 comparison))))

                           (:greater
                            (let ((target (,left left)))
                              (when (,nil-p target)
                                (return-from ,splay-inner
                                  (values (,left left)
                                          left
                                          (,node-copy tree :left (,right left))
                                          second-comparison)))

                              (multiple-value-bind (small center big comparison) (,splay-inner target)
                                (values
                                 small
                                 center
                                 (,node-copy left
                                             :left big
                                             :right (,node-copy tree :left (,right left)))
                                 comparison))))))))))))
           (declare (dynamic-extent #',splay-inner))

           (when (,nil-p tree)
             (return-from ,splay (values tree nil)))

           (multiple-value-bind (small center big comparison) (,splay-inner tree)
             (values (,node-copy center :left small :right big) comparison))))

       (defun ,insert (comparator tree key ,@value-list)
         (multiple-value-bind (splayed comparison) (,splay comparator tree key)
           (when (or (eq :equal comparison)
                     (eq :unequal comparison))
             (return-from ,insert
               (,with-key comparator tree comparison key ,@value-list)))

           (cond
             ((,nil-p splayed)
              (,make-node-1 :key key ,@(when value `(:value ,value))))
             ((eq comparison :less)
              (,make-node-1 :key key ,@(when value `(:value ,value))
                            :left (,node-copy splayed :right (,nil-type))
                            :right (,right splayed)))
             ((eq comparison :greater)
              (,make-node-1 :key key ,@(when value `(:value ,value))
                            :left (,left splayed)
                            :right (,node-copy splayed :left (,nil-type)))))))

       (defun ,join (left right)
         (cond
           ((,nil-p right)
            left)
           ((,nil-p left)
            right)
           (t
            (let ((splayed-right (,splay (constantly :less) right nil)))
              (assert (,nil-p (,right splayed-right)))
              (,node-copy splayed-right :left left)))))

       (defun ,remove (comparator tree key)
         (multiple-value-bind (splayed comparison) (,splay comparator tree key)
           (unless (or (eq comparison :equal)
                       (eq comparison :unequal))
             (return-from ,remove splayed))

           (etypecase splayed
             (,node-1-type
              (if (eq comparison :equal)
                  (,join (,left splayed) (,right splayed))
                  splayed))
             (,node-n-type
              (,without-key comparator tree comparison key)))))

       (defun ,lookup (comparator tree key)
         (multiple-value-bind (splayed comparison) (,splay comparator tree key)
           (when (or (eq comparison :less)
                     (eq comparison :greater))
             (return-from ,lookup (values splayed nil nil)))
           (etypecase splayed
             (,node-1-type
              (if (eq comparison :equal)
                  (values
                   splayed
                   ,(if map-p
                        `(,node-1-value splayed)
                        t)
                   t)
                  (values splayed nil nil)))
             (,node-n-type
              ,(if map-p
                   `(multiple-value-bind (result found-p) (list-map-lookup comparator (,node-n-values splayed) key)
                      (values splayed result found-p))
                   `(let ((result (list-set-is-member comparator (,node-n-values splayed) key)))
                      (values splayed result result))))))))))

(define-splay-operations sp-set)

(define-splay-operations sp-map :map-p t)

(define-struct (impure-splay-set (:constructor %make-impure-splay-set))
  (tree (sp-set-nil) :type sp-set)
  (comparator (error "comparator is required") :read-only t))

(defmethod check-invariants ((set impure-splay-set))
  (check-sp-set (impure-splay-set-tree set) (impure-splay-set-comparator set)))

(defun impure-splay-set-is-empty (splay-set)
  (sp-set-nil-p (impure-splay-set-tree splay-set)))

(defun impure-splay-set-insert (splay-set item)
  (setf (impure-splay-set-tree splay-set)
        (sp-set-insert (impure-splay-set-comparator splay-set) (impure-splay-set-tree splay-set) item))
  (values))

(defun impure-splay-set-remove (splay-set item)
  (setf (impure-splay-set-tree splay-set)
        (sp-set-remove (impure-splay-set-comparator splay-set) (impure-splay-set-tree splay-set) item))
  (values))

(defun impure-splay-set-remove-all (splay-set)
  (setf (impure-splay-set-tree splay-set) (sp-set-nil))
  (values))

(defun impure-splay-set-is-member (splay-set item)
  (multiple-value-bind
        (new-tree member-p)
      (sp-set-lookup (impure-splay-set-comparator splay-set) (impure-splay-set-tree splay-set) item)
    (setf (impure-splay-set-tree splay-set) new-tree)
    member-p))

(defun make-impure-splay-set* (comparator &key items)
  (let ((set (%make-impure-splay-set :comparator comparator)))
    (dolist (item items)
      (impure-splay-set-insert set item))
    set))

(defun make-impure-splay-set (comparator &rest items)
  (make-impure-splay-set* comparator :items items))

(defun impure-splay-set-to-list (splay-set)
  (sp-set-to-list (impure-splay-set-tree splay-set)))

(defmethod print-object ((splay-set impure-splay-set) stream)
  (write `(make-impure-splay-set* ',(impure-splay-set-comparator splay-set)
                                   :items ',(impure-splay-set-to-list splay-set))
         :stream stream))

(defmethod print-graphviz ((map impure-splay-set) stream)
  (print-graphviz (impure-splay-set-tree map) stream))

(define-struct (impure-splay-map (:constructor %make-impure-splay-map))
  (tree (sp-map-nil) :type sp-map)
  (comparator (error "comparator is required")))

(defmethod check-invariants ((map impure-splay-map))
  (check-sp-map (impure-splay-map-tree map) (impure-splay-map-comparator map)))

(defun impure-splay-map-is-empty (splay-map)
  (sp-map-nil-p (impure-splay-map-tree splay-map)))

(defun impure-splay-map-insert (splay-map key value)
  (setf (impure-splay-map-tree splay-map)
        (sp-map-insert (impure-splay-map-comparator splay-map) (impure-splay-map-tree splay-map) key value))
  (values))

(defun impure-splay-map-remove (splay-map key)
  (setf (impure-splay-map-tree splay-map)
        (sp-map-remove (impure-splay-map-comparator splay-map) (impure-splay-map-tree splay-map) key))
  (values))

(defun impure-splay-map-remove-all (splay-map)
  (setf (impure-splay-map-tree splay-map) (sp-map-nil))
  (values))

(defun impure-splay-map-lookup (splay-map key)
  (multiple-value-bind
        (new-tree value found-p)
      (sp-map-lookup (impure-splay-map-comparator splay-map) (impure-splay-map-tree splay-map) key)
    (setf (impure-splay-map-tree splay-map) new-tree)
    (values value found-p)))

(defun make-impure-splay-map* (comparator &key alist plist)
  (let ((map (%make-impure-splay-map :comparator comparator)))
    (dolist (pair alist)
      (impure-splay-map-insert map (car pair) (cdr pair)))
    (loop :while plist
          :for key = (pop plist)
          :for value = (if plist (pop plist) (error "Odd number of items in plist"))
          :do (impure-splay-map-insert map key value))
    map))

(defun make-impure-splay-map (comparator &rest plist)
  (make-impure-splay-map* comparator :plist plist))

(defun impure-splay-map-to-list (splay-map)
  (sp-map-to-list (impure-splay-map-tree splay-map)))

(defmethod print-object ((splay-map impure-splay-map) stream)
  (write `(make-impure-splay-map* ',(impure-splay-map-comparator splay-map)
                                   :alist ',(impure-splay-map-to-list splay-map))
         :stream stream))

(defmethod print-graphviz ((map impure-splay-map) stream)
  (print-graphviz (impure-splay-map-tree map) stream))

(define-immutable-structure (splay-heap (:constructor %make-splay-heap))
  (tree (sp-set-nil) :type sp-set)
  (comparator (error "comparator is required")))

(defun sp-heap-split (comparator sp-set pivot)
  (when (sp-set-nil-p sp-set)
    (return-from sp-heap-split
      (values (sp-set-nil) (sp-set-nil))))

  (multiple-value-bind (splayed comparison) (sp-set-splay comparator sp-set pivot)
    (ecase comparison
      (:less
       (values (copy-sp-set-node-1 splayed :right (sp-set-nil))
               (sp-set-node-right splayed)))
      ((:greater :equal :unequal)
       (values (sp-set-node-left splayed)
               (copy-sp-set-node-1 splayed :left (sp-set-nil)))))))

(defun sp-heap-top (sp-set)
  (cond
    ((sp-set-nil-p sp-set)
     (values nil nil))
    ((sp-set-nil-p (sp-set-node-left sp-set))
     (values (sp-set-node-1-key sp-set) t))
    (t
     (sp-heap-top (sp-set-node-left sp-set)))))

(defmethod heap-top ((heap splay-heap))
  (sp-heap-top (splay-heap-tree heap)))

(defun sp-heap-with-member (comparator sp-set item)
  (when (sp-set-nil-p sp-set)
    (return-from sp-heap-with-member
      (make-sp-set-node-1 :key item)))

  (multiple-value-bind (lesser greater) (sp-heap-split comparator sp-set item)
    (make-sp-set-node-1 :key item :left lesser :right greater)))

(defmethod with-member ((heap splay-heap) item)
  (copy-splay-heap heap
                   :tree (sp-heap-with-member (splay-heap-comparator heap)
                                              (splay-heap-tree heap)
                                              item)))

(defun sp-heap-without-heap-top (sp-set)
  (when (sp-set-nil-p sp-set)
    (return-from sp-heap-without-heap-top
      (values sp-set nil nil)))

  (let ((splayed (sp-set-splay (constantly :greater) sp-set nil)))
    (assert (sp-set-nil-p (sp-set-node-left splayed)))
    (values
     (sp-set-node-right splayed)
     (sp-set-node-1-key splayed)
     t)))

(defmethod without-heap-top ((heap splay-heap))
  (multiple-value-bind
        (new-tree value valid-p)
      (sp-heap-without-heap-top (splay-heap-tree heap))
    (values (copy-splay-heap heap :tree new-tree)
            value
            valid-p)))

(defun sp-heap-merge (comparator left right)
  (when (sp-set-nil-p left)
    (return-from sp-heap-merge right))
  (when (sp-set-nil-p right)
    (return-from sp-heap-merge left))

  (multiple-value-bind
        (lesser greater)
      (sp-heap-split comparator left (sp-set-node-1-key right))
    (copy-sp-set-node-1 right :left (sp-heap-merge comparator lesser (sp-set-node-left right))
                              :right (sp-heap-merge comparator greater (sp-set-node-right right)))))

(defmethod merge-heaps ((first splay-heap) (second splay-heap))
  (unless (eq (splay-heap-comparator first)
              (splay-heap-comparator second))
    (error "Heaps have different comparators"))

  (%make-splay-heap :tree (sp-heap-merge (splay-heap-comparator first)
                                         (splay-heap-tree first)
                                         (splay-heap-tree second))
                    :comparator (splay-heap-comparator first)))

(defmethod is-empty ((heap splay-heap))
  (sp-set-nil-p (splay-heap-tree heap)))

(defmethod empty ((heap splay-heap))
  (%make-splay-heap :comparator (splay-heap-comparator heap)))

(defmethod to-list ((heap splay-heap))
  (let ((builder (make-impure-list-builder)))
    (do-sp-set (key (splay-heap-tree heap))
      (impure-list-builder-add builder key))
    (impure-list-builder-extract builder)))

(defun check-sp-heap (sp-set comparator)
  (etypecase sp-set
    (sp-set-nil)
    (sp-set-node-1
     (do-sp-set (key (sp-set-node-left sp-set))
       (cassert (not (eq :greater (funcall comparator key (sp-set-node-1-key sp-set))))))
     (do-sp-set (key (sp-set-node-right sp-set))
       (cassert (not (eq :less (funcall comparator key (sp-set-node-1-key sp-set)))))))))

(defmethod check-invariants ((heap splay-heap))
  (check-sp-heap (splay-heap-tree heap) (splay-heap-comparator heap)))

(defun make-splay-heap* (comparator &key items)
  (let ((set (sp-set-nil)))
    (dolist (key items)
      (setf set (sp-heap-with-member comparator set key)))
    (%make-splay-heap :tree set :comparator comparator)))

(defun make-splay-heap (comparator &rest items)
  (make-splay-heap* comparator :items items))

(defmethod print-object ((heap splay-heap) stream)
  (write `(make-splay-heap* ',(splay-heap-comparator heap) :items ',(to-list heap))
         :stream stream))

(defmethod print-graphviz ((heap splay-heap) stream)
  (print-graphviz (splay-heap-tree heap) stream))
