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

(defpackage :pfds.shcl.io/implementation/red-black-tree
  (:use :common-lisp)
  (:use :pfds.shcl.io/interface)
  (:import-from :pfds.shcl.io/utility/iterator-tools
   #:compare-sets #:compare-maps)
  (:import-from :pfds.shcl.io/utility/printer
   #:print-map #:print-set)
  (:import-from :pfds.shcl.io/utility/compare
   #:compare-objects #:compare)
  (:import-from :pfds.shcl.io/utility/immutable-structure
   #:define-immutable-structure)
  (:import-from :pfds.shcl.io/utility/misc
   #:intern-conc #:cassert)
  (:import-from :pfds.shcl.io/utility/tree
   #:define-tree #:print-tree-node-properties
   #:node-left #:node-right #:nil-tree-p)
  (:export
   #:red-black-set
   #:red-black-set-p
   #:make-red-black-set
   #:red-black-map
   #:red-black-map-p
   #:make-red-black-map))
(in-package :pfds.shcl.io/implementation/red-black-tree)

;; See "Purely Functional Data Structures" by Chris Okasaki, and
;; Stefan Kahrs' red black tree untyped haskell implementation at
;; https://www.cs.kent.ac.uk/people/staff/smk/redblack/Untyped.hs

(deftype color ()
  '(member :red :black))

(defmacro with-tree-path (base-name &body body)
  (let ((l-or-r (gensym "L-OR-R"))
        (rest (gensym "REST"))
        (%path (gensym "PATH")))
    `(macrolet
         ((,%path (,l-or-r &rest ,rest)
            (if ,rest
                (ecase ,l-or-r
                  (l `(,',(intern-conc (symbol-package base-name) base-name "-NODE-LEFT")
                       (,',%path ,@,rest)))
                  (r `(,',(intern-conc (symbol-package base-name) base-name "-NODE-RIGHT")
                       (,',%path ,@,rest))))
                (ecase ,l-or-r
                  (l 'left)
                  (r 'right))))
          (path (&rest ,rest)
            (if ,rest
                `(,',%path ,@(reverse ,rest))
                'tree)))
       ,@body)))

(defmacro define-balancers (base-name)
  ;; This is only intended for use within this package, so we're going
  ;; to be lazy about gensyms.
  (let ((red-p (intern-conc *package* base-name "-RED-P"))
        (black-p (intern-conc *package* base-name "-BLACK-P"))
        (copy-node (intern-conc *package* "COPY-" base-name "-NODE"))
        (node-color (intern-conc *package* base-name "-NODE-COLOR"))
        (node-left (intern-conc *package* base-name "-NODE-LEFT"))
        (node-right (intern-conc *package* base-name "-NODE-RIGHT"))
        (node-p (intern-conc *package* base-name "-NODE-P"))
        (insert-balance-right (intern-conc *package* base-name "-INSERT-BALANCE-RIGHT"))
        (insert-balance-left (intern-conc *package* base-name "-INSERT-BALANCE-LEFT"))
        (remove-balance-right (intern-conc *package* base-name "-REMOVE-BALANCE-RIGHT"))
        (remove-balance-left (intern-conc *package* base-name "-REMOVE-BALANCE-LEFT")))
    `(progn

       (declaim (inline ,red-p))
       (defun ,red-p (tree)
         (and (,node-p tree) (eq (,node-color tree) :red)))

       (declaim (inline ,black-p))
       (defun ,black-p (tree)
         (and (,node-p tree) (eq (,node-color tree) :black)))

       (defun ,insert-balance-right (tree &key (left (,node-left tree)) (right (,node-right tree)))
         (assert (not (and (eq left (,node-left tree))
                           (eq right (,node-right tree))))
                 (left right tree)
                 "Something must have changed!")

         (when (eq :red (,node-color tree))
           (return-from ,insert-balance-right
             (,copy-node tree :left left :right right)))

         (with-tree-path ,base-name
           (labels
               ((result (a x b y c z d)
                  (return-from ,insert-balance-right
                    (,copy-node
                     y
                     :left (,copy-node
                            x
                            :left a
                            :right b
                            :color :black)
                     :right (,copy-node
                             z
                             :left c
                             :right d
                             :color :black)
                     :color :red))))

             (when (,red-p (path r))
               (cond
                 ((,red-p (path l))
                  (result (path l l)
                          (path l) ; left
                          (path l r)
                          (path) ; top
                          (path r l)
                          (path r) ; right
                          (path r r)))

                 ((,red-p (path r l))
                  (result (path l)
                          (path) ; left
                          (path r l l)
                          (path r l) ; top
                          (path r l r)
                          (path r) ; right
                          (path r r)))

                 ((,red-p (path r r))
                  (result (path l)
                          (path) ; left
                          (path r l)
                          (path r) ; top
                          (path r r l)
                          (path r r) ; right
                          (path r r r))))))

           (,copy-node tree :left left :right right :color :black)))

       (defun ,insert-balance-left (tree &key (left (,node-left tree)) (right (,node-right tree)))
         (assert (not (and (eq left (,node-left tree))
                           (eq right (,node-right tree))))
                 (left right tree)
                 "Something must have changed!")

         (when (eq :red (,node-color tree))
           (return-from ,insert-balance-left
             (,copy-node tree :left left :right right)))

         (with-tree-path ,base-name
           (labels
               ((result (a x b y c z d)
                  (return-from ,insert-balance-left
                    (,copy-node
                     y
                     :left (,copy-node
                            x
                            :left a
                            :right b
                            :color :black)
                     :right (,copy-node
                             z
                             :left c
                             :right d
                             :color :black)
                     :color :red))))

             (when (,red-p (path l))
               (cond
                 ((,red-p (path r))
                  (result (path l l)
                          (path l) ; left
                          (path l r)
                          (path) ; top
                          (path r l)
                          (path r) ; right
                          (path r r)))

                 ((,red-p (path l l))
                  (result (path l l l)
                          (path l l) ; left
                          (path l l r)
                          (path l) ; top
                          (path l r)
                          (path) ; right
                          (path r)))

                 ((,red-p (path l r))
                  (result (path l l)
                          (path l) ; left
                          (path l r l)
                          (path l r) ; top
                          (path l r r)
                          (path) ; right
                          (path r))))))

           (,copy-node tree :left left :right right :color :black)))

       (defun ,remove-balance-left (tree &key (left (,node-left tree)) (right (,node-right tree)))
         (assert (not (and (eq left (,node-left tree))
                           (eq right (,node-right tree))))
                 (left right tree)
                 "Something must have changed!")

         (unless (,black-p (,node-left tree)) ;; Yes, we're looking at the old left!
           (return-from ,remove-balance-left
             (,copy-node tree :left left :right right :color :red)))

         (with-tree-path ,base-name
           (cond
             ((,red-p (path l))
              (,copy-node tree
                          :left (,copy-node (path l) :color :black)
                          :right (path r)
                          :color :red))

             ((,black-p (path r))
              (,insert-balance-right (,copy-node tree :color :black)
                                     :left (path l)
                                     :right (,copy-node (path r) :color :red)))

             ((and (,red-p (path r))
                   (,black-p (path r l)))
              (,copy-node (path r l)
                          :left (,copy-node (path)
                                            :left (path l)
                                            :right (path r l l)
                                            :color :black)
                          :right (,insert-balance-right (,copy-node (path r) :color :black)
                                                        :left (path r l r)
                                                        :right (,copy-node (path r r) :color :red))
                          :color :red))

             (t
              (assert nil nil "This should be impossible")))))

       (defun ,remove-balance-right (tree &key (left (,node-left tree)) (right (,node-right tree)))
         (assert (not (and (eq left (,node-left tree))
                           (eq right (,node-right tree))))
                 (left right tree)
                 "Something must have changed!")

         (unless (,black-p (,node-right tree)) ;; Yes, we're looking at the old right!
           (return-from ,remove-balance-right
             (,copy-node tree :left left :right right :color :red)))

         (with-tree-path ,base-name
           (cond
             ((,red-p (path r))
              (,copy-node tree
                          :left (path l)
                          :right (,copy-node (path r) :color :black)
                          :color :red))

             ((,black-p (path l))
              (,insert-balance-left (,copy-node tree :color :black)
                                    :left (,copy-node (path l) :color :red)
                                    :right (path r)))

             ((and (,red-p (path l))
                   (,black-p (path l r)))
              (,copy-node (path l r)
                          :left (,insert-balance-left (,copy-node (path l) :color :black)
                                                      :left (,copy-node (path l l) :color :red)
                                                      :right (path l r l))
                          :right (,copy-node (path)
                                             :left (path l r r)
                                             :right (path r)
                                             :color :black)
                          :color :red))

             (t
              (assert nil nil "This should be impossible"))))))))

(defmacro define-red-black-tree (base-name (&key map-p))
  (let* ((package (symbol-package base-name))
         (maker (intern-conc package "MAKE-" base-name))
         (insert-left (intern-conc package base-name "-INSERT-BALANCE-LEFT"))
         (insert-right (intern-conc package base-name "-INSERT-BALANCE-RIGHT"))
         (remove-left (intern-conc package base-name "-REMOVE-BALANCE-LEFT"))
         (remove-right (intern-conc package base-name "-REMOVE-BALANCE-RIGHT")))
    `(progn
       (define-tree ,base-name (:map-p ,map-p
                                :define-maker-p nil
                                :maker ,maker
                                :insert-left-balancer ,insert-left
                                :insert-right-balancer ,insert-right
                                :remove-left-balancer ,remove-left
                                :remove-right-balancer ,remove-right)
         (color :red :type color))
       (define-balancers ,base-name))))

(define-red-black-tree rb-set (:map-p nil))

(declaim (inline rb-set-blacken))
(defun rb-set-blacken (tree)
  (if (rb-set-node-p tree)
      (copy-rb-set-node tree :color :black)
      tree))

(defun rb-set-insert-from-root (comparator tree key)
  (multiple-value-bind
        (tree count-change)
      (rb-set-insert comparator tree key)
    (values (rb-set-blacken tree) count-change)))

(defun rb-set-remove-from-root (comparator tree key)
  (multiple-value-bind
        (tree value valid-p count-change)
      (rb-set-remove comparator tree key)
    (values
     (rb-set-blacken tree)
     value
     valid-p
     count-change)))

(defun make-rb-set (comparator &key items)
  (let ((tree (rb-set-nil))
        (count 0))
    (dolist (item items)
      (multiple-value-bind (new-tree count-change) (rb-set-insert-from-root comparator tree item)
        (setf tree new-tree)
        (incf count count-change)))
    (values tree count)))

(define-red-black-tree rb-map (:map-p t))

(declaim (inline rb-map-blacken))
(defun rb-map-blacken (tree)
  (if (rb-map-node-p tree)
      (copy-rb-map-node tree :color :black)
      tree))

(defun rb-map-insert-from-root (comparator tree key value)
  (multiple-value-bind
        (tree count-change)
      (rb-map-insert comparator tree key value)
    (values (rb-map-blacken tree) count-change)))

(defun rb-map-emplace-from-root (comparator tree key value)
  (multiple-value-bind
        (tree count-change)
      (rb-map-emplace comparator tree key value)
    (values (rb-map-blacken tree) count-change)))

(defun rb-map-remove-from-root (comparator tree key)
  (multiple-value-bind
        (tree value valid-p count-change)
      (rb-map-remove comparator tree key)
    (values
     (rb-map-blacken tree)
     value
     valid-p
     count-change)))

(defun make-rb-map (comparator &key alist plist)
  (let ((tree (rb-map-nil))
        (count 0))
    (loop :while plist
          :for key = (pop plist)
          :for value = (if plist (pop plist) (error "Odd number of items in plist"))
          :do (multiple-value-bind
                    (new-tree count-change)
                  (rb-map-emplace-from-root comparator tree key value)
                (setf tree new-tree)
                (incf count count-change)))
    (dolist (pair alist)
      (multiple-value-bind
            (new-tree count-change)
          (rb-map-emplace-from-root comparator tree (car pair) (cdr pair))
        (setf tree new-tree)
        (incf count count-change)))
    (values tree count)))

(defgeneric node-color (tree))

(defmethod node-color ((tree rb-map-node))
  (rb-map-node-color tree))

(defmethod node-color ((tree rb-set-node))
  (rb-set-node-color tree))

(defmethod print-tree-node-properties ((tree rb-set-node) stream)
  (call-next-method)
  (format stream " color=~A" (if (eq :black (rb-set-node-color tree)) "black" "red")))

(defmethod print-tree-node-properties ((tree rb-map-node) stream)
  (call-next-method)
  (format stream " color=~A" (if (eq :black (rb-map-node-color tree)) "black" "red")))

(defun black-depth (tree)
  (if (nil-tree-p tree)
      1
      (if (eq :black (node-color tree))
          (1+ (black-depth (node-left tree)))
          (black-depth (node-left tree)))))

(defun check-black-depth (tree expected)
  (if (nil-tree-p tree)
      (cassert (equal expected 1) nil "Black depth violation")
      (let ((new-expected (if (eq :black (node-color tree))
                              (1- expected)
                              expected)))
        (check-black-depth (node-left tree) new-expected)
        (check-black-depth (node-right tree) new-expected))))

(defun node-red-p (tree)
  (and (not (nil-tree-p tree))
       (eq :red (node-color tree))))

(defun check-red-invariant (tree)
  (unless (nil-tree-p tree)
    (cassert (or (not (node-red-p tree))
                 (and (not (node-red-p (node-left tree)))
                      (not (node-red-p (node-right tree)))))
             nil "red-red violation")

    (check-red-invariant (node-left tree))
    (check-red-invariant (node-right tree))))

(defun check-balance (tree)
  (check-red-invariant tree)
  (check-black-depth tree (black-depth tree)))

(define-immutable-structure (red-black-set (:constructor %make-red-black-set))
  (tree (rb-set-nil) :type rb-set)
  (size 0 :type (integer 0))
  (comparator (error "required")))

(declare-interface-conformance red-black-set ordered-set)

(defmethod comparator ((set red-black-set))
  (red-black-set-comparator set))

(defmethod check-invariants ((set red-black-set))
  (cassert (equal (red-black-set-size set)
                  (check-rb-set (red-black-set-tree set) (red-black-set-comparator set))))
  (check-balance (red-black-set-tree set)))

(defmethod to-list ((set red-black-set))
  (rb-set-to-list (red-black-set-tree set)))

(defmethod for-each ((set red-black-set) function)
  (do-rb-set (key (red-black-set-tree set))
    (funcall function key)))

(defmethod map-members ((set red-black-set) function)
  (multiple-value-bind (new-tree count) (rb-set-map-members (red-black-set-comparator set)
                                                            (red-black-set-tree set)
                                                            function)
    (copy-red-black-set set :size count :tree new-tree)))

(defmethod iterator ((set red-black-set))
  (iterator (red-black-set-tree set)))

(defmethod compare-objects ((left red-black-set) (right red-black-set))
  (compare-sets left (red-black-set-comparator left)
                right (red-black-set-comparator right)
                #'compare))

(defmethod print-object ((set red-black-set) stream)
  (if *print-readably*
      (call-next-method)
      (print-set set stream)))

(defmethod print-graphviz ((tree red-black-set) stream id-vendor)
  (print-graphviz (red-black-set-tree tree) stream id-vendor))

(defmethod is-empty ((set red-black-set))
  (rb-set-nil-p (red-black-set-tree set)))

(defmethod empty ((set red-black-set))
  (copy-red-black-set set :tree (rb-set-nil) :size 0))

(defmethod size ((set red-black-set))
  (red-black-set-size set))

(defmethod with-member ((set red-black-set) item)
  (multiple-value-bind
        (new-tree count-change)
      (rb-set-insert-from-root
       (red-black-set-comparator set)
       (red-black-set-tree set)
       item)

    (copy-red-black-set set :tree new-tree :size (+ count-change (red-black-set-size set)))))

(defmethod decompose ((set red-black-set))
  (multiple-value-bind
        (new-tree value valid-p)
      (rb-set-decompose (red-black-set-tree set))
    (values (copy-red-black-set set :tree (rb-set-blacken new-tree)
                                    :size (+ (if valid-p -1 0) (red-black-set-size set)))
            value
            valid-p)))

(defmethod without-member ((set red-black-set) item)
  (multiple-value-bind
        (new-tree value valid-p count-change)
      (rb-set-remove-from-root
       (red-black-set-comparator set)
       (red-black-set-tree set)
       item)
    (declare (ignore value))

    (values (copy-red-black-set set :tree new-tree :size (+ count-change (red-black-set-size set)))
            valid-p)))

(defmethod is-member ((set red-black-set) item)
  (nth-value 1 (rb-set-lookup (red-black-set-comparator set)
                              (red-black-set-tree set)
                              item)))

(defun make-red-black-set (comparator &key items)
  (multiple-value-bind (tree count) (make-rb-set comparator :items items)
    (%make-red-black-set
     :tree tree
     :size count
     :comparator comparator)))

(defun red-black-set (comparator &rest items)
  (make-red-black-set comparator :items items))

(define-immutable-structure (red-black-map (:constructor %make-red-black-map))
  (tree (rb-map-nil) :type rb-map)
  (size 0 :type (integer 0))
  (comparator (error "required")))

(declare-interface-conformance red-black-map ordered-map)

(defmethod comparator ((map red-black-map))
  (red-black-map-comparator map))

(defmethod with-member ((map red-black-map) pair)
  (check-type pair cons)
  (red-black-map-with-entry map (car pair) (cdr pair)))

(defmethod member-type ((map red-black-map))
  '(cons t t))

(defmethod decompose ((map red-black-map))
  (multiple-value-bind
        (new-tree value valid-p)
      (rb-map-decompose (red-black-map-tree map))
    (values (copy-red-black-map map :tree (rb-map-blacken new-tree)
                                    :size (+ (if valid-p -1 0) (red-black-map-size map)))
            value
            valid-p)))

(defmethod check-invariants ((map red-black-map))
  (cassert (equal (red-black-map-size map)
                  (check-rb-map (red-black-map-tree map) (red-black-map-comparator map))))
  (check-balance (red-black-map-tree map)))

(defmethod for-each ((map red-black-map) function)
  (do-rb-map (key value (red-black-map-tree map))
    (funcall function (cons key value))))

(defmethod for-each-entry ((map red-black-map) function)
  (do-rb-map (key value (red-black-map-tree map))
    (funcall function key value)))

(defmethod map-entries ((map red-black-map) function)
  (copy-red-black-map map :tree (rb-map-map-entries (red-black-map-tree map) function)))

(defmethod map-members ((map red-black-map) function)
  (multiple-value-bind (new-tree count) (rb-map-map-members (red-black-map-comparator map)
                                                            (red-black-map-tree map)
                                                            function)
    (copy-red-black-map map :size count :tree new-tree)))

(defmethod iterator ((map red-black-map))
  (iterator (red-black-map-tree map)))

(defmethod compare-objects ((left red-black-map) (right red-black-map))
  (compare-maps left (red-black-map-comparator left)
                right (red-black-map-comparator right)
                #'compare #'compare))

(defmethod to-list ((map red-black-map))
  (rb-map-to-list (red-black-map-tree map)))

(defmethod print-object ((map red-black-map) stream)
  (if *print-readably*
      (call-next-method)
      (print-map map stream)))

(defmethod print-graphviz ((tree red-black-map) stream id-vendor)
  (print-graphviz (red-black-map-tree tree) stream id-vendor))

(defmethod is-empty ((map red-black-map))
  (rb-map-nil-p (red-black-map-tree map)))

(defmethod empty ((map red-black-map))
  (copy-red-black-map map :tree (rb-map-nil) :size 0))

(defmethod size ((map red-black-map))
  (red-black-map-size map))

(defun red-black-map-with-entry (map key value)
  (multiple-value-bind
        (new-tree count-change)
      (rb-map-insert-from-root
       (red-black-map-comparator map)
       (red-black-map-tree map)
       key
       value)
    (copy-red-black-map map :size (+ (red-black-map-size map) count-change)
                        :tree new-tree)))

(defmethod with-entry ((map red-black-map) key value)
  (red-black-map-with-entry map key value))

(defmethod without-entry ((map red-black-map) key)
  (multiple-value-bind
        (new-tree value valid-p count-change)
      (rb-map-remove-from-root
       (red-black-map-comparator map)
       (red-black-map-tree map)
       key)
    (values
     (copy-red-black-map map :size (+ count-change (red-black-map-size map))
                         :tree new-tree)
     value
     valid-p)))

(defmethod lookup-entry ((tree red-black-map) key)
  (rb-map-lookup (red-black-map-comparator tree)
                 (red-black-map-tree tree)
                 key))

(defun make-red-black-map (comparator &key alist plist)
  (multiple-value-bind (tree count) (make-rb-map comparator :alist alist :plist plist)
    (%make-red-black-map
     :tree tree
     :size count
     :comparator comparator)))

(defun red-black-map (comparator &rest plist)
  (make-red-black-map comparator :plist plist))
