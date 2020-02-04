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

(defpackage :pfds.shcl.io/interface/list
  (:use :common-lisp)
  (:import-from :pfds.shcl.io/interface/common
   #:is-empty #:empty)
  (:import-from :pfds.shcl.io/utility
   #:define-interface)
  (:export
   #:with-head #:head #:tail #:is-empty #:empty))
(in-package :pfds.shcl.io/interface/list)

(define-interface list
  (defgeneric with-head (item list))
  (defgeneric head (list))
  (defgeneric tail (list))
  is-empty
  empty)
