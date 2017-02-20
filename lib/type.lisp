(import base (defun let* type# if car cdr when
              and or >= = <= /= # rawget defmacro
              error gensym ! debug))

(import lua/string (format sub))

(defun table? (x) (= (type# x) "table"))
(defun list? (x) (= (type x) "list"))
(defun nil? (x) (and x (list? x) (= (# x) 0)))
(defun string? (x) (= (type x) "string"))
(defun number? (x) (= (type x) "number"))
(defun symbol? (x) (= (type x) "symbol"))
(defun boolean? (x) (= (type x) "boolean"))
(defun function? (x) (= (type x) "function"))
(defun atom? (x)
  (or (boolean? x)
      (string? x)
      (number? x)
      (symbol? x)
      (key? x)))
(defun exists? (x) (! (= (type x) "nil")))
(defun key? (x) (= (type x) "key"))
(defun between? (val min max)
  (and (>= val min) (<= val max)))

(defun type (val)
  (let* [(ty (type# val))]
    (if (= ty "table")
      (let* [(tag (rawget val "tag"))]
        (if tag tag "table"))
      ty)))

(defun eq? (x y)
  (cond
    [(and (symbol? x) (symbol? y))
     (= (rawget x "contents") (rawget y "contents"))]
    [(and (symbol? x) (string? y))
     (= (rawget x "contents") y)]
    [(and (string? x) (symbol? y))
     (= (rawget y "contents") x)]
    [(and (key? x) (key? y))
     (= (rawget x "contents") (rawget y "contents"))]
    [(and (key? x) (string? y))
     (= (sub (rawget x "contents") 2) y)]
    [(and (string? x) (key? y))
     (= (sub (rawget y "contents") 2) x)]
    [(and (nil? x) (nil? y)) true]
    [(and (list? x) (list? y))
     (and (eq? (car x) (car y))
          (eq? (cdr x) (cdr y)))]
    [true (= x y)]))

(defun neq? (x y)
  (! (eq? x y)))

(defmacro assert-type! (arg ty)
  (let* [(sym (gensym))
         (ty (rawget ty "contents"))]
    `(let* [(,sym (type ,arg))]
      (when (/= ,sym ,ty)
        (error (format "bad argment %s (expected %s, got %s)" ,(rawget arg "contents") ,ty ,sym) 2)))))