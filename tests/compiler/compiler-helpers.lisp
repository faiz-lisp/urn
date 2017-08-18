(import lua/basic (type#))

(import urn/logger/void logger)
(import urn/timer timer)
(import urn/resolve/builtins builtins)
(import urn/resolve/scope scope)

(define start-range
  "The default range for all objects"
  :hidden
  { :name  "init.lisp"
    :lines  '(";; Empty")
    :start  { :line 1 :column 1 }
    :finish { :line 1 :column 1 } })

(defun wrap-node (node)
  "Wraps a NODE, converting it into something usable for resolution."
  (case (type# node)
    ["number" { :tag "number" :value node :range start-range }]
    ["string" { :tag "string" :value node :range start-range }]
    ["table"
     (.<! node :range start-range)
     (when (list? node)
       (for i 1 (n node) 1
         (.<! node i (wrap-node (nth node i)))))
     node]))

(defun create-compiler ()
  "Create a new compilation state, with some basic variables already defined."
  (let* [(scope (builtins/create-scope))
         (compiler { :log           logger/void
                     :timer         (timer/create (lambda ()))

                     :lib-meta      { :+       { :tag "expr" :contents '(1 " + " 2)   :count 2 :fold "l" :prec 9 :pure true :value + }
                                      :-       { :tag "expr" :contents '(1 " - " 2)   :count 2 :fold "l" :prec 9 :pure true :value - }
                                      :..      { :tag "expr" :contents '(1 " .. " 2)  :count 2 :fold "r" :prec 8 :pure true :value .. }
                                      :get-idx { :tag "expr" :contents '(1 "[" 2 "]") :count 2 :precs '(100 0) :value (cut .> <> <>) }
                                      :print   { :tag "var"  :contents "print" } }

                     :root-scope    scope
                     :variables     {}
                     :states        {}
                     :compile-state { :mappings {} }

                     :loader        (lambda (name) (fail! $"Cannot load external module '${name}'")) })]

    (for-each var '("foo" "bar" "baz" "qux" "+" "-" ".." "get-idx" "print")
      (scope/add! scope var "native"))

    (for-pairs (_ var) (.> scope :parent :variables) (.<! compiler :variables (tostring var) var))
    (for-pairs (_ var) (.> scope :variables) (.<! compiler :variables (tostring var) var))

    compiler))