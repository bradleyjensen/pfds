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

(uiop:define-package :pfds.shcl.io/utility/tree
  (:use :common-lisp)
  (:use :pfds.shcl.io/utility/interface)
  (:use :pfds.shcl.io/implementation/interface)
  (:import-from :pfds.shcl.io/utility/iterator-tools
   #:list-iterator #:singleton-iterator
   #:empty-iterator #:compare-ordered-sets
   #:compare-ordered-maps)
  (:import-from :pfds.shcl.io/utility/compare
   #:compare)
  (:import-from :pfds.shcl.io/utility/specialization
   #:define-specializable-function
   #:mutually-recursive-specializable-functions)
  (:import-from :pfds.shcl.io/utility/impure-list-builder
   #:make-impure-list-builder #:impure-list-builder-add
   #:impure-list-builder-extract)
  (:import-from :pfds.shcl.io/utility/immutable-structure
   #:define-adt #:structure-convert #:define-immutable-structure)
  (:import-from :pfds.shcl.io/utility/misc
   #:intern-conc #:cassert)
  (:import-from :pfds.shcl.io/utility/list
   #:list-set-with #:list-set-without #:list-set #:list-set-is-member
   #:list-set-mutate
   #:list-map-with #:list-map-without #:list-map #:list-map-lookup
   #:list-map-map-entries #:list-map-mutate)
  (:export
   #:<<base-tree>>

   #:nil-type-p
   #:i-nil-type-p
   #:node-1-type-p
   #:i-node-1-type-p
   #:node-n-type-p
   #:i-node-n-type-p
   #:node-type-p
   #:i-node-type-p

   #:node-1-key
   #:i-node-1-key
   #:node-1-value
   #:i-node-1-value
   #:node-n-values
   #:i-node-n-values
   #:node-left
   #:i-node-left
   #:node-right
   #:i-node-right

   #:node-1-copy
   #:i-node-1-copy
   #:node-n-copy
   #:i-node-n-copy
   #:convert-1-to-n
   #:i-convert-1-to-n
   #:convert-n-to-1
   #:i-convert-n-to-1

   #:make-node-1
   #:i-make-node-1
   #:make-nil
   #:i-make-nil

   #:map-p
   #:i-map-p

   #:prepare-graphviz-properties
   #:i-prepare-graphviz-properties

   #:<<tree>>
   #:remove-left-balancer
   #:i-remove-left-balancer
   #:remove-right-balancer
   #:i-remove-right-balancer
   #:insert-left-balancer
   #:i-insert-left-balancer
   #:insert-right-balancer
   #:i-insert-right-balancer
   #:mutate
   #:i-mutate

   #:<<rotations>>
   #:rotate-left
   #:i-rotate-left
   #:rotate-right
   #:i-rotate-right
   #:rotate-double-left
   #:i-rotate-double-left
   #:rotate-double-right
   #:i-rotate-double-right

   #:<<tree-wrapper>>
   #:size
   #:i-size
   #:comparator
   #:i-comparator
   #:tree
   #:i-tree
   #:make-wrapper
   #:i-make-wrapper
   #:copy-wrapper
   #:i-copy-wrapper

   #:define-tree-type

   #:representative-key
   #:node-copy
   #:node-with-left
   #:node-with-right
   #:remove-min-node
   #:node-with-the-value-content-of-node
   #:tree-append-children
   #:node-n-copy-with-values
   #:tree-mutate
   #:tree-insert
   #:tree-emplace
   #:make-map-tree
   #:make-set-tree
   #:tree-lookup
   #:tree-remove
   #:tree-decompose
   #:tree-for-each
   #:tree-to-list
   #:tree-map-members
   #:tree-map-entries
   #:tree-iterator
   #:tree-print-graphviz
   #:check-tree-order
   #:check-tree-count
   #:tree-rotate-left
   #:tree-rotate-right
   #:tree-rotate-double-left
   #:tree-rotate-double-right

   #:wrapper-make-set
   #:wrapper-make-map
   #:wrapper-to-list
   #:wrapper-for-each
   #:wrapper-map-members
   #:wrapper-iterator
   #:wrapper-set-compare
   #:wrapper-map-compare
   #:wrapper-is-empty
   #:wrapper-empty
   #:wrapper-check-invariants
   #:wrapper-with-member
   #:wrapper-decompose
   #:wrapper-without-member
   #:wrapper-is-member
   #:wrapper-print-graphviz
   #:wrapper-with-entry
   #:wrapper-without-entry
   #:wrapper-lookup-entry
   #:wrapper-for-each-entry
   #:wrapper-map-entries))
(in-package :pfds.shcl.io/utility/tree)

(declaim (inline always-t))
(defun always-t (&rest args)
  (declare (ignore args))
  t)

(define-compiler-macro always-t (&rest args)
  (declare (ignore args))
  t)

(declaim (inline always-nil))
(defun always-nil (&rest args)
  (declare (ignore args))
  nil)

(define-compiler-macro always-nil (&rest args)
  (declare (ignore args))
  nil)

(declaim (inline default-node-1-value))
(defun default-node-1-value (node)
  (declare (ignore node))
  t)

(define-compiler-macro default-node-1-value (node)
  (declare (ignore node))
  t)

(declaim (inline default-prepare-graphviz-properties))
(defun default-prepare-graphviz-properties (tree properties)
  (declare (ignore tree properties))
  nil)

(define-compiler-macro default-prepare-graphviz-properties (tree properties)
  (declare (ignore tree properties))
  nil)

(defun unsupported-operation (&rest args)
  (declare (ignore args))
  (error "Whoops!  Operations on N-type nodes isn't allowed!"))

;; Instances of this can be easily generated by a macro
(define-interface <<base-tree>> ()
  nil-type-p
  node-1-type-p
  node-n-type-p
  node-type-p

  node-1-key
  (:optional node-1-value default-node-1-value)
  node-n-values
  node-left
  node-right

  node-1-copy
  node-n-copy
  convert-1-to-n
  convert-n-to-1

  make-node-1
  make-nil

  map-p

  (:optional prepare-graphviz-properties default-prepare-graphviz-properties))

(define-interface-function nil-type-p (object)
  :define-generic nil)
(define-interface-function node-1-type-p (object)
  :define-generic nil)
(define-interface-function node-n-type-p (object)
  :define-generic nil)
(define-interface-function node-type-p (object)
  :define-generic nil)

(define-interface-function node-1-key (node)
  :define-generic nil)
(define-interface-function node-1-value (node)
  :define-generic nil)
(define-interface-function node-n-values (node)
  :define-generic nil)
(define-interface-function node-left (node)
  :define-generic nil)
(define-interface-function node-right (node)
  :define-generic nil)

(define-interface-function node-1-copy (node &key left right key value)
  :define-generic nil)
(define-interface-function node-n-copy (node &key left right values)
  :define-generic nil)
(define-interface-function convert-1-to-n (node-1 values)
  :define-generic nil)
(define-interface-function convert-n-to-1 (node-n key &optional value)
  :define-generic nil)

(define-interface-function make-node-1 (&key key value)
  :define-generic nil)
(define-interface-function make-nil ()
  :define-generic nil)

(define-interface-function map-p ()
  :define-generic nil)

(define-interface-function prepare-graphviz-properties (tree properties)
  :define-generic nil)

;; Instances of this require special knowledge about the tree's
;; invariants
(define-interface <<tree>> (<<base-tree>>)
  remove-left-balancer
  remove-right-balancer
  insert-left-balancer
  insert-right-balancer

  mutate)

(define-interface-function remove-left-balancer (node left right)
  :define-generic nil)
(define-interface-function remove-right-balancer (node left right)
  :define-generic nil)

(define-interface-function insert-left-balancer (node left right)
  :define-generic nil)
(define-interface-function insert-right-balancer (node left right)
  :define-generic nil)

(define-interface-function mutate (tree comparator key action-function)
  :define-generic nil)

(define-interface <<rotations>> ()
  rotate-left
  rotate-right
  rotate-double-left
  rotate-double-right)

(define-interface-function rotate-left (node &optional left right)
  :define-generic nil)
(define-interface-function rotate-right (node &optional left right)
  :define-generic nil)

(define-interface-function rotate-double-left (node &optional left right)
  :define-generic nil)
(define-interface-function rotate-double-right (node &optional left right)
  :define-generic nil)

(define-interface <<tree-wrapper>> ()
  tree
  size
  comparator
  make-wrapper
  copy-wrapper)

(define-interface-function tree (wrapper)
  :define-generic nil)

(define-interface-function make-wrapper (&key comparator tree size)
  :define-generic nil)

(define-interface-function copy-wrapper (wrapper &key comparator tree size)
  :define-generic nil)

(defmacro define-tree-type (name-and-options &rest extra-node-slots)
  (when (symbolp name-and-options)
    (setf name-and-options (list name-and-options)))

  (destructuring-bind (base-name &key map-p (enable-n-type t))
      name-and-options
    (let* ((package *package*)

           (nil-type (intern-conc package base-name "-NIL"))
           (nil-instance (intern-conc package "*" nil-type "*"))
           (make-nil (intern-conc package "MAKE-" nil-type))
           (secret-nil-maker (intern-conc package "%" make-nil))
           (nil-type-p (intern-conc package nil-type "-P"))

           (node-base-type (intern-conc package base-name "-NODE"))
           (node-type-p (intern-conc package node-base-type "-P"))
           (node-left (intern-conc package node-base-type "-LEFT"))
           (node-right (intern-conc package node-base-type "-RIGHT"))

           (node-1-type (intern-conc package node-base-type "-1"))
           (make-node-1 (intern-conc package "MAKE-" node-1-type))
           (node-1-copy (intern-conc package "COPY-" node-1-type))
           (node-1-type-p (intern-conc package node-1-type "-P"))
           (node-1-key (intern-conc package node-1-type "-KEY"))
           (node-1-value (when map-p
                           (intern-conc package node-1-type "-VALUE")))

           (node-n-type (when enable-n-type
                          (intern-conc package node-base-type "-N")))
           (node-n-copy (if enable-n-type
                            (intern-conc package "COPY-" node-n-type)
                            'unsupported-operation))
           (node-n-values (if enable-n-type
                              (intern-conc package node-n-type "-VALUES")
                              'unsupported-operation))
           (node-n-type-p (if enable-n-type
                              (intern-conc package node-n-type "-P")
                              'always-nil))

           (convert-1-to-n (if enable-n-type
                               (intern-conc package "CONVERT-" node-base-type "-1-TO-N")
                               'unsupported-operation))
           (convert-n-to-1 (if enable-n-type
                               (intern-conc package "CONVERT-" node-base-type "-N-TO-1")
                               'unsupported-operation))

           (interface-name (intern-conc package "<<BASE-" base-name ">>"))

           (node-copy (if enable-n-type
                          (intern-conc package "COPY-" node-base-type)
                          node-1-copy))

           (key (make-symbol "KEY"))
           (value (make-symbol "VALUE"))
           (values (make-symbol "VALUES"))
           (tree (make-symbol "TREE"))
           (left (make-symbol "LEFT"))
           (right (make-symbol "RIGHT")))
      `(progn
         (defvar ,nil-instance)

         (defun ,make-nil ()
           ,nil-instance)

         (define-adt ,base-name
             ()
           ((,nil-type (:copier nil)
                       (:constructor ,secret-nil-maker)))
           ((,node-base-type (:copier nil)
                             (:constructor nil))
            (left (,make-nil) :type ,base-name)
            (right (,make-nil) :type ,base-name)
            ,@extra-node-slots))

         (define-immutable-structure (,node-1-type (:include ,node-base-type))
           (key (error "required"))
           ,@(when map-p
               `((value (error "required")))))

         ,@(when enable-n-type
             `((define-immutable-structure (,node-n-type (:include ,node-base-type))
                 (values (error "required")))))

         (defvar ,nil-instance (,secret-nil-maker))

         ,@(when enable-n-type
             `((defun ,convert-1-to-n (,tree ,values)
                 (structure-convert (,node-n-type ,node-1-type) ,tree :values ,values))

               (defun ,convert-n-to-1 (,tree ,key &optional ,value)
                 (declare (ignore ,@(unless map-p `(,value))))
                 (structure-convert (,node-1-type ,node-n-type) ,tree
                                    :key ,key
                                    ,@(when map-p `(:value ,value))))

               (defun ,node-copy (,tree ,left ,right)
                 (etypecase ,tree
                   (,node-1-type
                    (,node-1-copy ,tree :left ,left :right ,right))
                   (,node-n-type
                    (,node-n-copy ,tree :left ,left :right ,right))))))

         (define-interface ,interface-name (<<tree>>)
           (:optional nil-type-p ,nil-type-p)
           (:optional node-1-type-p ,node-1-type-p)
           (:optional node-n-type-p ,node-n-type-p)
           (:optional node-type-p ,node-type-p)

           (:optional node-1-key ,node-1-key)
           ,@(when map-p
               `((:optional node-1-value ,node-1-value)))
           (:optional node-n-values ,node-n-values)
           (:optional node-left ,node-left)
           (:optional node-right ,node-right)

           (:optional node-1-copy ,node-1-copy)
           (:optional node-n-copy ,node-n-copy)
           (:optional convert-1-to-n ,convert-1-to-n)
           (:optional convert-n-to-1 ,convert-n-to-1)

           (:optional make-node-1 ,make-node-1)
           (:optional make-nil ,make-nil)

           (:optional map-p ,(if map-p 'always-t 'always-nil))

           (:optional insert-left-balancer ,node-copy)
           (:optional insert-right-balancer ,node-copy)
           (:optional remove-left-balancer ,node-copy)
           (:optional remove-right-balancer ,node-copy))

         ',base-name))))

(define-specializable-function representative-key (<tree>) (node)
  (cond
    ((i-node-1-type-p <tree> node)
     (values (i-node-1-key <tree> node)
             (i-node-1-value <tree> node)))

    ((i-node-n-type-p <tree> node)
     (let ((value (car (i-node-n-values <tree> node))))
       (if (i-map-p <tree>)
           (values (car value) (cdr value))
           (values value t))))

    (t
     (error "Argument isn't a node: ~W" node))))

(define-specializable-function node-copy (<tree>) (node left right)
  (cond
    ((i-node-1-type-p <tree> node)
     (i-node-1-copy <tree> node :left left :right right))

    ((i-node-n-type-p <tree> node)
     (i-node-n-copy <tree> node :left left :right right))

    (t
     (error "Invalid node type: ~W" node))))

(define-specializable-function node-with-left (<tree>) (node left)
  (cond
    ((i-node-1-type-p <tree> node)
     (i-node-1-copy <tree> node :left left))

    ((i-node-n-type-p <tree> node)
     (i-node-n-copy <tree> node :left left))

    (t
     (error "Invalid node type: ~W" node))))

(define-specializable-function node-with-right (<tree>) (node right)
  (cond
    ((i-node-1-type-p <tree> node)
     (i-node-1-copy <tree> node :right right))

    ((i-node-n-type-p <tree> node)
     (i-node-n-copy <tree> node :right right))

    (t
     (error "Invalid node type: ~W" node))))

(define-specializable-function remove-min-node (<tree>) (tree)
  (cond
    ((i-nil-type-p <tree> tree)
     (error "nil tree has no min"))

    ((i-node-type-p <tree> tree)
     (if (i-nil-type-p <tree> (i-node-left <tree> tree))
         (values tree (i-node-right <tree> tree))
         (multiple-value-bind (result value) (remove-min-node <tree> (i-node-left <tree> tree))
           (values result (i-remove-left-balancer <tree> tree value (i-node-right <tree> tree))))))))

(define-specializable-function node-with-the-value-content-of-node
    (<tree>)
    (tree value-provider)
  (if (i-node-1-type-p <tree> tree)
      (if (i-node-1-type-p <tree> value-provider)
          (if (i-map-p <tree>)
              (i-node-1-copy <tree> tree :key (i-node-1-key <tree> value-provider)
                                         :value (i-node-1-value <tree> value-provider))
              (i-node-1-copy <tree> tree :key (i-node-1-key <tree> value-provider)))
          (i-convert-1-to-n <tree> tree (i-node-n-values <tree> value-provider)))
      (if (i-node-1-type-p <tree> value-provider)
          (if (i-map-p <tree>)
              (i-convert-n-to-1 <tree> tree
                                (i-node-1-key <tree> value-provider)
                                (i-node-1-value <tree> value-provider))
              (i-convert-n-to-1 <tree> tree
                                (i-node-1-key <tree> value-provider)))
          (i-node-n-copy <tree> tree :values (i-node-n-values <tree> value-provider)))))

(define-specializable-function tree-append-children (<tree>) (tree)
  (when (i-nil-type-p <tree> (i-node-left <tree> tree))
    (return-from tree-append-children
      (i-node-right <tree> tree)))
  (when (i-nil-type-p <tree> (i-node-right <tree> tree))
    (return-from tree-append-children
      (i-node-left <tree> tree)))

  (multiple-value-bind (min without-min) (remove-min-node <tree> (i-node-right <tree> tree))
    (i-remove-right-balancer <tree>
                             (node-with-the-value-content-of-node
                              <tree>
                              tree
                              min)
                             (i-node-left <tree> tree)
                             without-min)))

(define-specializable-function node-n-copy-with-values (<tree>) (tree values)
  (if (cdr values)
      (i-node-n-copy <tree> tree :values values)
      (if (i-map-p <tree>)
          (i-convert-n-to-1 <tree> tree
                            (car (car values))
                            (cdr (car values)))
          (i-convert-n-to-1 <tree> tree
                            (car values)))))

(mutually-recursive-specializable-functions
  (define-specializable-function tree-mutate-missing (<tree>) (tree key action-function)
    (multiple-value-bind (action value) (funcall action-function)
      (ecase action
        (:insert
         (cond
           ((i-nil-type-p <tree> tree)
            (values (if (i-map-p <tree>)
                        (i-make-node-1 <tree> :key key :value value)
                        (i-make-node-1 <tree> :key key))
                    1
                    t))

           ((i-node-1-type-p <tree> tree)
            (values (i-convert-1-to-n <tree> tree
                                      (if (i-map-p <tree>)
                                          (list
                                           (cons (i-node-1-key <tree> tree) (i-node-1-value <tree> tree))
                                           (cons key value))
                                          (list
                                           (i-node-1-key <tree> tree)
                                           key)))
                    1
                    nil))

           ((i-node-n-type-p <tree> tree)
            (values (i-node-n-copy <tree> tree :values (cons
                                                        (if (i-map-p <tree>)
                                                            (cons key value)
                                                            key)
                                                        (i-node-n-values <tree> tree)))
                    1
                    nil))

           (t
            (error "Unrecognized tree object: ~W" tree))))

        ((:remove nil)
         (values tree 0 nil)))))

  (define-specializable-function tree-mutate-equal (<tree>) (tree action-function extracted-key extracted-value)
    (multiple-value-bind
          (action value)
        (if (i-map-p <tree>)
            (funcall action-function extracted-key extracted-value)
            (funcall action-function extracted-key))

      (ecase action
        ((nil)
         (values tree 0 nil))

        (:remove
         (cond
           ((i-node-1-type-p <tree> tree)
            (values (tree-append-children <tree> tree)
                    -1
                    t))
           ((i-node-n-type-p <tree> tree)
            (values (node-n-copy-with-values <tree> tree (cdr (i-node-n-values <tree> tree)))
                    -1
                    nil))
           (t
            (error "Invalid tree object: ~W" tree))))

        (:insert
         (if (i-map-p <tree>)
             (cond
               ((i-node-1-type-p <tree> tree)
                (values (i-node-1-copy <tree> tree :value value)
                        0
                        nil))
               ((i-node-n-type-p <tree> tree)
                (if (eql value extracted-value)
                    (values tree 0 nil)
                    (values (i-node-n-copy <tree> tree :values (cons (cons extracted-key value)
                                                                     (cdr (i-node-n-values <tree> tree))))
                            0
                            nil)))
               (t
                (error "Invalid tree object: ~W" tree)))
             (values tree 0 nil))))))

  (define-specializable-function tree-mutate-unequal (<tree>) (tree comparator key action-function)
    (cond
      ((i-node-1-type-p <tree> tree)
       (tree-mutate-missing <tree> tree key action-function))

      ((i-node-n-type-p <tree> tree)
       (multiple-value-bind
             (result count-change balance-needed-p)
           (if (i-map-p <tree>)
               ;; We don't need to check the first node -- we already know its unequal
               (list-map-mutate comparator (cdr (i-node-n-values <tree> tree)) key action-function)
               (list-set-mutate comparator (cdr (i-node-n-values <tree> tree)) key action-function))
         (cassert (null balance-needed-p))

         (when (eql result (cdr (i-node-n-values <tree> tree)))
           (cassert (equal count-change 0))
           (return-from tree-mutate-unequal
             (values tree count-change balance-needed-p)))

         (values
          (node-n-copy-with-values <tree> tree
                                   (cons (car (i-node-n-values <tree> tree))
                                         result))
          count-change
          balance-needed-p)))

      (t
       (error "Invalid tree object: ~W" tree))))

  (define-specializable-function tree-mutate-less (<tree>) (tree comparator key action-function)
    (multiple-value-bind
          (result count-change balance-needed-p)
        (tree-mutate <tree> (i-node-left <tree> tree) comparator key action-function)
      (values
       (if balance-needed-p
           (if (plusp count-change)
               (i-insert-left-balancer <tree> tree result (i-node-right <tree> tree))
               (i-remove-left-balancer <tree> tree result (i-node-right <tree> tree)))
           (node-with-left <tree> tree result))
       count-change
       balance-needed-p)))

  (define-specializable-function tree-mutate-greater (<tree>) (tree comparator key action-function)
    (multiple-value-bind
          (result count-change balance-needed-p)
        (tree-mutate <tree> (i-node-right <tree> tree) comparator key action-function)
      (values
       (if balance-needed-p
           (if (plusp count-change)
               (i-insert-right-balancer <tree> tree (i-node-left <tree> tree) result)
               (i-remove-right-balancer <tree> tree (i-node-left <tree> tree) result))
           (node-with-right <tree> tree result))
       count-change
       balance-needed-p)))

  (define-specializable-function tree-mutate (<tree>) (tree comparator key action-function)
    (cond
      ((i-nil-type-p <tree> tree)
       (tree-mutate-missing <tree> tree key action-function))

      ((i-node-type-p <tree> tree)
       (multiple-value-bind (extracted-key extracted-value) (representative-key <tree> tree)
         (let ((comparison (funcall comparator key extracted-key)))
           (ecase comparison
             (:less
              (tree-mutate-less <tree> tree comparator key action-function))
             (:greater
              (tree-mutate-greater <tree> tree comparator key action-function))
             (:unequal
              (tree-mutate-unequal <tree> tree comparator key action-function))
             (:equal
              (tree-mutate-equal <tree> tree action-function extracted-key extracted-value))))))

      (t
       (error "Invalid tree object: ~W" tree)))))

(define-specializable-function tree-insert (<tree>) (tree comparator key value)
  (i-mutate
   <tree>
   tree
   comparator
   key
   (if (i-map-p <tree>)
       (lambda (&optional extracted-key extracted-value)
         (declare (ignore extracted-key extracted-value))
         (values :insert value))
       (lambda (&optional extracted-key)
         (declare (ignore extracted-key))
         :insert))))

(define-specializable-function tree-emplace (<tree>) (tree comparator key value)
  (i-mutate
   <tree>
   tree
   comparator
   key
   (if (i-map-p <tree>)
       (lambda (&optional (extracted-key nil value-p) extracted-value)
         (declare (ignore extracted-key extracted-value))
         (unless value-p
           (values :insert value)))
       (lambda (&optional extracted-key)
         (declare (ignore extracted-key))
         :insert))))

(define-specializable-function make-map-tree (<tree>) (comparator &key alist plist)
  (unless (i-map-p <tree>)
    (error "make-map-tree only works for maps"))

  (let ((tree (i-make-nil <tree>))
        (count 0))
    (labels
        ((add (key value)
           (multiple-value-bind
                 (result count-change balance-needed-p)
               (tree-emplace <tree> tree comparator key value)
             (declare (ignore balance-needed-p))
             (setf tree result)
             (incf count count-change))))
      (loop :with remaining-plist = plist :while remaining-plist
            :for key = (pop remaining-plist)
            :for value = (if remaining-plist
                             (pop remaining-plist)
                             (error "Odd number of items in plist"))
            :do (add key value))
      (loop :for pair :in alist
            :for key = (car pair)
            :for value = (cdr pair)
            :do (add key value)))
    (values tree count)))

(define-specializable-function make-set-tree (<tree>) (comparator &key items)
  (when (i-map-p <tree>)
    (error "make-set-tree only works for sets"))

  (let ((tree (i-make-nil <tree>))
        (count 0))
    (labels
        ((add (key)
           (multiple-value-bind
                 (result count-change balance-needed-p)
               (tree-emplace <tree> tree comparator key t)
             (declare (ignore balance-needed-p))
             (setf tree result)
             (incf count count-change))))
      (loop :for key :in items
            :do (add key)))
    (values tree count)))

(define-specializable-function tree-lookup (<tree>) (tree comparator key)
  ;; Is it actually faster to have a redundant copy of the
  ;; traversal logic that can't mutate rather than using the
  ;; mutator function w/ a mutator action that does a
  ;; non-local return to quickly unwind the stack?  Maaaaybe.
  ;; Hypothetically, the less and greater paths below could
  ;; be TCO'd out and we could avoid introducing stack frames
  ;; as we traverse.
  (cond
    ((i-nil-type-p <tree> tree)
     (values nil nil))
    ((i-node-type-p <tree> tree)
     (multiple-value-bind (here-key here-value) (representative-key <tree> tree)
       (ecase (funcall comparator key here-key)
         (:less
          (tree-lookup <tree> (i-node-left <tree> tree) comparator key))
         (:greater
          (tree-lookup <tree> (i-node-right <tree> tree) comparator key))
         (:equal
          (values here-value t))
         (:unequal
          (if (i-node-1-type-p <tree> tree)
              (values nil nil)
              (if (i-map-p <tree>)
                  ;; We have already looked at the first element!
                  (list-map-lookup comparator (cdr (i-node-n-values <tree> tree)) key)
                  (let ((member-p (list-set-is-member comparator (cdr (i-node-n-values <tree> tree)) key)))
                    (values member-p member-p))))))))))

(define-specializable-function tree-remove (<tree>) (tree comparator key)
  (let (value value-p)
    (multiple-value-bind
          (new-tree count-change)
        (i-mutate <tree> tree comparator key
                  (lambda (&optional (extracted-key nil found-p)
                             (extracted-value (if (i-map-p <tree>) nil t)))
                    (declare (ignore extracted-key))
                    (setf value extracted-value)
                    (setf value-p found-p)
                    :remove))
      (cassert (or (and (zerop count-change) (null value-p))
                   (and (equal -1 count-change) (not (null value-p)))))
      (values new-tree value value-p count-change))))

(define-specializable-function tree-decompose (<tree>) (tree)
  (when (i-nil-type-p <tree> tree)
    (return-from tree-decompose (values tree nil nil)))

  (labels
      ((visit (tree)
         (unless (i-nil-type-p <tree> (i-node-left <tree> tree))
           (multiple-value-bind
                 (new-tree value valid-p balance-needed-p)
               (visit (i-node-left <tree> tree))
             (return-from visit
               (values (if balance-needed-p
                           (i-remove-left-balancer <tree> tree new-tree (i-node-right <tree> tree))
                           (node-with-left <tree> tree new-tree))
                       value
                       valid-p
                       balance-needed-p))))

         (let (extracted-key
               extracted-value)
           (multiple-value-bind
                 (new-tree count-change balance-needed-p)
               (i-mutate <tree> tree (constantly :equal) nil
                         (lambda (key &optional (value t))
                           (setf extracted-key key)
                           (setf extracted-value value)
                           :remove))
             (assert (equal -1 count-change))
             (values new-tree
                     (if (i-map-p <tree>)
                         (cons extracted-key extracted-value)
                         extracted-key)
                     t
                     balance-needed-p)))))
    (visit tree)))

(define-specializable-function tree-for-each-entry (<tree>) (tree function)
  (when (i-nil-type-p <tree> tree)
    (return-from tree-for-each-entry))

  (tree-for-each-entry <tree> (i-node-left <tree> tree) function)
  (cond
    ((i-node-1-type-p <tree> tree)
     (funcall function (i-node-1-key <tree> tree) (i-node-1-value <tree> tree)))
    ((i-node-n-type-p <tree> tree)
     (dolist (pair (i-node-n-values <tree> tree))
       (funcall function (car pair) (cdr pair))))
    (t
     (error "Invalid tree node: ~W" tree)))
  (tree-for-each-entry <tree> (i-node-right <tree> tree) function))

(define-specializable-function tree-for-each (<tree>) (tree function)
  (when (i-nil-type-p <tree> tree)
    (return-from tree-for-each))

  (tree-for-each <tree> (i-node-left <tree> tree) function)
  (cond
    ((i-node-1-type-p <tree> tree)
     (if (i-map-p <tree>)
         (funcall function (cons (i-node-1-key <tree> tree) (i-node-1-value <tree> tree)))
         (funcall function (i-node-1-key <tree> tree))))
    ((i-node-n-type-p <tree> tree)
     (dolist (value (i-node-n-values <tree> tree))
       (if (i-map-p <tree>)
           (funcall function (cons (car value) (cdr value)))
           (funcall function value))))

    (t
     (error "Invalid tree node: ~W" tree)))
  (tree-for-each <tree> (i-node-right <tree> tree) function))

(define-specializable-function tree-to-list (<tree>) (tree)
  (let ((builder (make-impure-list-builder)))
    (tree-for-each
     <tree> tree
     (lambda (object) (impure-list-builder-add builder object)))
    (impure-list-builder-extract builder)))

(define-specializable-function tree-map-members (<tree>) (tree comparator function)
  (let ((builder (make-impure-list-builder)))
    (tree-for-each
     <tree> tree
     (lambda (item)
       (impure-list-builder-add builder (funcall function item))))
    (if (i-map-p <tree>)
        (make-map-tree <tree> comparator :alist (impure-list-builder-extract builder))
        (make-set-tree <tree> comparator :items (impure-list-builder-extract builder)))))

(define-specializable-function tree-map-entries (<tree>) (tree function)
  (unless (i-map-p <tree>)
    (error "TREE-MAP-ENTRIES only works on maps"))

  (cond
    ((i-nil-type-p <tree> tree)
     tree)

    ((i-node-1-type-p <tree> tree)
     (i-node-1-copy <tree> tree
                    :left (tree-map-entries <tree> (i-node-left <tree> tree) function)
                    :right (tree-map-entries <tree> (i-node-right <tree> tree) function)
                    :value (funcall function
                                    (i-node-1-key <tree> tree)
                                    (i-node-1-value <tree> tree))))

    ((i-node-n-type-p <tree> tree)
     (i-node-n-copy <tree> tree
                    :left (tree-map-entries <tree> (i-node-left <tree> tree) function)
                    :right (tree-map-entries <tree> (i-node-right <tree> tree) function)
                    :values (list-map-map-entries (i-node-n-values <tree> tree) function)))

    (t
     (error "Invalid tree: ~W" tree))))

(define-specializable-function tree-node-value-iterator (<tree>) (tree)
  (cond
    ((i-node-1-type-p <tree> tree)
     (singleton-iterator
      (if (i-map-p <tree>)
          (cons (i-node-1-key <tree> tree) (i-node-1-value <tree> tree))
          (i-node-1-key <tree> tree))))

    ((i-node-n-type-p <tree> tree)
     (list-iterator (i-node-n-values <tree> tree)))

    (t
     (error "Invalid tree node: ~W" tree))))

(define-specializable-function tree-iterator (<tree>) (tree)
  (when (i-nil-type-p <tree> tree)
    (return-from tree-iterator
      (empty-iterator)))

  (let (stack)
    (labels
        ((push-node (node)
           (unless (i-nil-type-p <tree> node)
             (push (list (i-node-left <tree> node)
                         (tree-node-value-iterator <tree> node)
                         (i-node-right <tree> node))
                   stack))))
      (push-node tree)
      (lambda ()
        (loop
          (unless stack
            (return (values nil nil)))

          (let ((tip (car stack)))
            (destructuring-bind (tip-left tip-node-iter tip-right) tip
              (cond
                (tip-left
                 (push-node tip-left)
                 (setf (first tip) nil))

                (tip-node-iter
                 (multiple-value-bind (value valid-p) (funcall tip-node-iter)
                   (if valid-p
                       (return (values value valid-p))
                       (setf (second tip) nil))))

                (t
                 (assert tip-right)
                 ;; Instead of setting this element to nil, let's
                 ;; just drop the whole frame.  We don't need it
                 ;; any more!
                 (pop stack)
                 (push-node tip-right))))))))))

(define-specializable-function tree-print-graphviz (<tree>) (tree stream id-vendor)
  (let ((id (next-graphviz-id id-vendor))
        (properties (make-hash-table :test #'equal)))

    (format stream "ID~A [" id)

    (setf (gethash "shape" properties) "box")
    (cond
      ((i-nil-type-p <tree> tree)
       (setf (gethash "label" properties) nil)
       (setf (gethash "shape" properties) "diamond"))

      ((i-node-1-type-p <tree> tree)
       (setf (gethash "label" properties)
             (if (i-map-p <tree>)
                 (cons (i-node-1-key <tree> tree) (i-node-1-value <tree> tree))
                 (i-node-1-key <tree> tree))))

      ((i-node-n-type-p <tree> tree)
       (setf (gethash "label" properties) (i-node-n-values <tree> tree)))

      (t
       (error "Invalid tree: ~W" tree)))

    (i-prepare-graphviz-properties <tree> tree properties)

    (loop :for key :being :the :hash-keys :of properties
            :using (:hash-value value) :do
              (format stream " ~A=~A" (graphviz-quote key) (graphviz-quote value)))

    (format stream " ]~%")

    (unless (i-nil-type-p <tree> tree)
      (let ((child-id (tree-print-graphviz <tree> (i-node-left <tree> tree) stream id-vendor)))
        (format stream "ID~A -> ID~A~%" id child-id))
      (let ((child-id (tree-print-graphviz <tree> (i-node-right <tree> tree) stream id-vendor)))
        (format stream "ID~A -> ID~A~%" id child-id)))
    id))

(define-specializable-function check-tree-order (<tree>) (tree comparator)
  (when (i-nil-type-p <tree> tree)
    (return-from check-tree-order))

  (let ((left (i-node-left <tree> tree))
        (right (i-node-right <tree> tree))
        (here-key (representative-key <tree> tree)))
    (unless (i-nil-type-p <tree> left)
      (cassert (eq :less (funcall comparator
                                  (representative-key <tree> left)
                                  here-key))
               nil "Left child must be less than its parent"))
    (unless (i-nil-type-p <tree> right)
      (cassert (eq :greater (funcall comparator
                                     (representative-key <tree> right)
                                     here-key))
               nil "Right child must be less than its parent"))

    (check-tree-order <tree> left comparator)
    (check-tree-order <tree> right comparator)))

(define-specializable-function check-tree-count (<tree>) (tree)
  (when (i-nil-type-p <tree> tree)
    (return-from check-tree-count 0))

  (let* ((left (i-node-left <tree> tree))
         (left-count (check-tree-count <tree> left))
         (right (i-node-right <tree> tree))
         (right-count (check-tree-count <tree> right))
         (children-count (+ left-count right-count)))
    (cond
      ((i-node-1-type-p <tree> tree)
       (+ 1 children-count))

      ((i-node-n-type-p <tree> tree)
       (cassert (cdr (i-node-n-values <tree> tree))
                nil "n-type nodes must have multiple values")
       (+ (length (i-node-n-values <tree> tree))
          children-count))

      (t
       (error "Invalid tree: ~W" tree)))))

(define-specializable-function tree-rotate-left
    (<tree>)
    (tree &optional
          (left (i-node-left <tree> tree))
          (right (i-node-right <tree> tree)))
  (node-with-left <tree> right
                  (node-copy <tree> tree
                             left
                             (i-node-left <tree> right))))

(define-specializable-function tree-rotate-right
    (<tree>)
    (tree &optional
          (left (i-node-left <tree> tree))
          (right (i-node-right <tree> tree)))
  (node-with-right <tree> left
                   (node-copy <tree> tree
                              (i-node-right <tree> left)
                              right)))

(define-specializable-function tree-rotate-double-left
    (<tree>)
    (tree &optional
          (left (i-node-left <tree> tree))
          (right (i-node-right <tree> tree)))
  (let* ((right-left (i-node-left <tree> right))
         (right-left-left (i-node-left <tree> right-left))
         (right-left-right (i-node-right <tree> right-left)))
    (node-copy <tree> right-left
               (node-copy <tree> tree
                          left
                          right-left-left)
               (node-with-left <tree> right
                               right-left-right))))

(define-specializable-function tree-rotate-double-right
    (<tree>)
    (tree &optional
          (left (i-node-left <tree> tree))
          (right (i-node-right <tree> tree)))
  (let* ((left-right (i-node-right <tree> left))
         (left-right-left (i-node-left <tree> left-right))
         (left-right-right (i-node-right <tree> left-right)))
    (node-copy <tree> left-right
               (node-with-right <tree> left left-right-left)
               (node-copy <tree> tree left-right-right right))))

(define-specializable-function wrapper-make-set (<wrapper> <tree>) (&key (comparator 'compare) items)
  (multiple-value-bind (tree size) (make-set-tree <tree> comparator :items items)
    (i-make-wrapper <wrapper> :comparator comparator :tree tree :size size)))

(define-specializable-function wrapper-make-map (<wrapper> <tree>) (&key (comparator 'compare) plist alist)
  (multiple-value-bind (tree size) (make-map-tree <tree> comparator :plist plist :alist alist)
    (i-make-wrapper <wrapper> :comparator comparator :tree tree :size size)))

(define-specializable-function wrapper-to-list (<wrapper> <tree>) (collection)
  (tree-to-list <tree> (i-tree <wrapper> collection)))

(define-specializable-function wrapper-for-each (<wrapper> <tree>) (collection function)
  (tree-for-each <tree> (i-tree <wrapper> collection) function))

(define-specializable-function wrapper-map-members (<wrapper> <tree>) (collection function)
  (multiple-value-bind (tree size) (tree-map-members <tree>
                                                     (i-tree <wrapper> collection)
                                                     (i-comparator <wrapper> collection)
                                                     function)
    (i-copy-wrapper <wrapper> collection :tree tree :size size)))

(define-specializable-function wrapper-iterator (<wrapper> <tree>) (collection)
  (tree-iterator <tree> (i-tree <wrapper> collection)))

(define-specializable-function wrapper-set-compare (<wrapper>) (left right)
  (compare-ordered-sets <wrapper> left right))

(define-specializable-function wrapper-map-compare (<wrapper>) (left right)
  (compare-ordered-maps <wrapper> left right))

(define-specializable-function wrapper-is-empty (<wrapper> <tree>) (collection)
  (i-nil-type-p <tree> (i-tree <wrapper> collection)))

(define-specializable-function wrapper-empty (<wrapper> <tree>) (collection)
  (i-copy-wrapper <wrapper> collection :tree (i-make-nil <tree>) :size 0))

(define-specializable-function wrapper-check-invariants (<wrapper> <tree>) (collection)
  (cassert (equal (check-tree-count <tree> (i-tree <wrapper> collection))
                  (i-size <wrapper> collection))
           (collection) "Collection size must be accurate")
  (check-tree-order <tree> (i-tree <wrapper> collection) (i-comparator <wrapper> collection)))

(define-specializable-function wrapper-with-member (<wrapper> <tree>) (collection item)
  (multiple-value-bind
        (tree count-change)
      (if (i-map-p <tree>)
          (tree-insert <tree>
                       (i-tree <wrapper> collection)
                       (i-comparator <wrapper> collection)
                       (car item)
                       (cdr item))
          (tree-insert <tree>
                       (i-tree <wrapper> collection)
                       (i-comparator <wrapper> collection)
                       item
                       t))
    (i-copy-wrapper <wrapper> collection
                    :tree tree
                    :size (+ count-change (i-size <wrapper> collection)))))

(define-specializable-function wrapper-decompose (<wrapper> <tree>) (collection)
  (tree-decompose <tree> (i-tree <wrapper> collection)))

(define-specializable-function wrapper-without-member (<wrapper> <tree>) (collection item)
  (multiple-value-bind
        (tree count-change)
      (tree-remove <tree>
                   (i-tree <wrapper> collection)
                   (i-comparator <wrapper> collection)
                   item)
    (values
     (i-copy-wrapper <wrapper> collection
                     :tree tree
                     :size (+ count-change (i-size <wrapper> collection)))
     t)))

(define-specializable-function wrapper-is-member (<wrapper> <tree>) (collection item)
  (tree-lookup <tree>
               (i-tree <wrapper> collection)
               (i-comparator <wrapper> collection)
               item))

(define-specializable-function wrapper-with-entry (<wrapper> <tree>) (collection key value)
  (multiple-value-bind
        (tree count-change)
      (tree-insert <tree>
                   (i-tree <wrapper> collection)
                   (i-comparator <wrapper> collection)
                   key
                   value)
    (i-copy-wrapper <wrapper> collection
                    :tree tree
                    :size (+ count-change (i-size <wrapper> collection)))))

(define-specializable-function wrapper-lookup-entry (<wrapper> <tree>) (collection key)
  (tree-lookup <tree>
               (i-tree <wrapper> collection)
               (i-comparator <wrapper> collection)
               key))

(define-specializable-function wrapper-without-entry (<wrapper> <tree>) (collection key)
  (multiple-value-bind
        (tree count-change)
      (tree-remove <tree>
                   (i-tree <wrapper> collection)
                   (i-comparator <wrapper> collection)
                   key)
    (i-copy-wrapper <wrapper> collection
                    :tree tree
                    :size (+ count-change (i-size <wrapper> collection)))))

(define-specializable-function wrapper-for-each-entry (<wrapper> <tree>) (collection function)
  (tree-for-each-entry <tree> (i-tree <wrapper> collection) function))

(define-specializable-function wrapper-map-entries (<wrapper> <tree>) (collection function)
  (i-copy-wrapper <wrapper> collection
                  :tree (tree-map-entries <tree> (i-tree <wrapper> collection) function)))

(define-specializable-function wrapper-print-graphviz (<wrapper> <tree>) (collection stream id-vendor)
  (tree-print-graphviz <tree> (i-tree <wrapper> collection) stream id-vendor))
