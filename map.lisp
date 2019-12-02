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

(defpackage :pfds.shcl.io/map
  (:use :common-lisp)
  (:import-from :pfds.shcl.io/common
   #:define-interface #:is-empty #:empty)
  (:export
   #:is-empty
   #:empty
   #:with-entry
   #:without-entry
   #:lookup-entry))
(in-package :pfds.shcl.io/map)

(define-interface map
  is-empty
  empty
  (defgeneric with-entry (container key value))
  (defgeneric without-entry (container key))
  (defgeneric lookup-entry (container key)))
