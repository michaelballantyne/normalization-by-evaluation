(load "alphaKanren/alphaKanren.scm")

(define lookupo
  (lambda (a env val)
    (exist (y v env^)
      (== `((,y . ,v) . ,env^) env)
      (conde
        ((== a y) (== v val))
        ((lookupo a env^ val)
         ;; Non-relational warning!  This call to `hash` should come
         ;; after the call to lookupo, since the first argument to
         ;; hash *must* be a ground (a nom, or a unification variable
         ;; bound to nom).  Perhaps fix this using delayed goals.
         ;; Thought: with delayed goals, would it be sound to unify
         ;; the first argument to a hash or tie with a fresh nom, if
         ;; no other goals are left to be run other than the fresh/nom
         ;; calls?
         (hash a y) ;; a =/= y
         )))))

(define eval-expro
  (lambda (env expr val)
    (conde
      ((exist (x)
         (== `(Var ,x) expr)
         (lookupo x env val)))
      ((exist (e1 e2 f v)
         (== `(App ,e1 ,e2) expr)
         (eval-expro env e1 f)
         (eval-expro env e2 v)
         (apply-expro f v val)))
      ((fresh (a)
         (exist (body)
           (hash a env)
           (== `(Lam ,(tie a body)) expr)
           (== `(Closure ,env ,(tie a body)) val)))))))

(define apply-expro
  (lambda (f v val)
    (conde
      ((fresh (a)
         (exist (env body)
           (== `(Closure ,env ,(tie a body)) f)
           (eval-expro `((,a . ,v) . ,env) body val))))
      ((exist (n)
         (== `(N ,n) f)
         (== `(N (NApp ,n ,v)) val))))))

(define uneval-valueo
  (lambda (v expr)
    (conde
      ((fresh (a a^)
         (exist (env body body^ bv)
           (== `(Closure ,env ,(tie a body)) v)
           (== `(Lam ,(tie a^ body^)) expr)
           (eval-expro `((,a . (N (NVar ,a^))) . ,env) body bv)
           (uneval-valueo bv body^))))
      ((exist (n)
         (== `(N ,n) v)
         (uneval-neutralo n expr))))))

(define uneval-neutralo
  (lambda (n expr)
    (conde
      ((exist (x)
         (== `(NVar ,x) n)
         (== `(Var ,x) expr)))
      ((exist (n^ v ne ve)
         (== `(NApp ,n^ ,v) n)
         (== `(App ,ne ,ve) expr)
         (uneval-neutralo n^ ne)
         (uneval-valueo v ve))))))

(define nfo
  (lambda (env t expr)
    (exist (v)
      (eval-expro env t v)
      (uneval-valueo v expr))))

(define main
  (lambda ()
    (run* (result)
      (exist (id_ const_)
        (fresh (a)
          (eval-expro '() `(Lam ,(tie a `(Var ,a))) id_))
        (fresh (a b)
          (eval-expro '() `(Lam ,(tie a `(Lam ,(tie b `(Var ,a))))) const_))
        (fresh (a b)
          (eval-expro `((,a . ,id_) (,b . ,const_)) `(App (Var ,b) (Var ,a)) result))))))

;; (printf "~s\n" (main))
;; ((Closure ((a.0 Closure () (tie-tag a.1 (Var a.1)))) (tie-tag a.2 (Var a.0))))
