(load "../faster-miniKanren/mk-vicare.scm")
(load "../faster-miniKanren/mk.scm")
(load "../faster-miniKanren/test-check.scm")

(define lookupo
  (lambda (x env val)
    (fresh (y v env^)
      (== `((,y . ,v) . ,env^) env)
      (symbolo x)
      (symbolo y)
      (conde
        ((== x y) (== v val))
        ((=/= x y)
         (lookupo x env^ val))))))

(define eval-expro
  (lambda (expr env val)
    (conde
      ((== #f expr) (== #f val))
      ((== #t expr) (== #t val))
      ((numbero expr) (== expr val))
      ((== `(quote ,val) expr)
       (absento 'closure val)
       (absento 'N val))
      ((fresh (x body)
         (== `(lambda (,x) ,body) expr)
         (== `(closure (,x) ,body ,env) val)
         (symbolo x)))
      ((symbolo expr) (lookupo expr env val))
      ((fresh (e v)
         (== `(car ,e) expr)
         (eval-expro e env v)
         (eval-caro v val)))
      ((fresh (e v)
         (== `(cdr ,e) expr)
         (eval-expro e env v)
         (eval-cdro v val)))      
      ((fresh (e1 e2 v1 v2)
         (== `(cons ,e1 ,e2) expr)
         (== `(,v1 . ,v2) val)
         (eval-expro e1 env v1)
         (eval-expro e2 env v2)))
      ((fresh (e1 e2 f v)
         (== `(,e1 ,e2) expr)
         (eval-expro e1 env f)
         (eval-expro e2 env v)
         (apply-expro f v val))))))

(define eval-caro
  (lambda (v val)
    (conde
      ((fresh (v1 v2)
         (== `(,v1 . ,v2) v)
         (== v1 val)
         (=/= 'closure v1)
         (=/= 'N v1)))
      ((fresh (n)
         (== `(N ,n) v)
         (== `(N (NCar ,n)) val))))))

(define eval-cdro
  (lambda (v val)
    (conde
      ((fresh (v1 v2)
         (== `(,v1 . ,v2) v)
         (== v2 val)
         (=/= 'closure v1)
         (=/= 'N v1)))
      ((fresh (n)
         (== `(N ,n) v)
         (== `(N (NCdr ,n)) val))))))

(define apply-expro
  (lambda (f v val)
    (conde
      ((fresh (n)
         (== `(N ,n) f)
         (== `(N (NApp ,n ,v)) val)))
      ((fresh (x body env)
         (== `(closure (,x) ,body ,env) f)
         (symbolo x)
         (eval-expro body `((,x . ,v) . ,env) val))))))

;; Fast and simple fresho definition (written with Michael Ballantyne)
;; Rather than compute a renamed variable, we just describe the constraints.
(define fresho
  (lambda (xs x^)
    (fresh ()
      (symbolo x^)
      (absento x^ xs))))

(define quoted-or-self-quotingo
  (lambda (expr datum)
    (conde
      ((== #f expr) (== expr datum))
      ((== #t expr) (== expr datum))
      ((numbero expr) (== expr datum))
      ((== `(quote ,datum) expr)))))

(define not-quoted-and-not-self-quotingo
  (lambda (expr)
    (conde
      ((symbolo expr))
      ((fresh (a d)
         (== `(,a . ,d) expr)
         (=/= 'quote a))))))

(define uneval-valueo
  (lambda (xs v expr)
    (conde
      ((== #f v) (== #f expr))
      ((== #t v) (== #t expr))
      ((numbero v) (== v expr))
      ((symbolo v)
       (== `(quote ,v) expr)
       (=/= 'closure v)
       (=/= 'N v))
      ((== '() v) (== '(quote ()) expr))
      ((fresh (n)
         (== `(N ,n) v)
         (uneval-neutralo xs n expr)))
      ((fresh (x body env x^ body^ bv)
         (== `(closure (,x) ,body ,env) v)
         (== `(lambda (,x^) ,body^) expr)
         (symbolo x)
         (symbolo x^)
         (fresho xs x^)
         (eval-expro body `((,x . (N (NVar ,x^))) . ,env) bv)
         (uneval-valueo `(,x^ . ,xs) bv body^)))
      ((fresh (v1 v2 e1 e2)
         (== `(,v1 . ,v2) v)
         (=/= 'closure v1)
         (=/= 'N v1)
         (absento 'closure expr)
         (absento 'N expr)
         (conde
           ((fresh (d1 d2)
              (== `(quote (,d1 . ,d2)) expr)
              (quoted-or-self-quotingo e1 d1)
              (quoted-or-self-quotingo e2 d2)))
           ((== `(cons ,e1 ,e2) expr)
            (conde
              ((not-quoted-and-not-self-quotingo e1))
              ((fresh (d1)
                 (quoted-or-self-quotingo e1 d1)
                 (not-quoted-and-not-self-quotingo e2))))))
         (uneval-valueo xs v1 e1)
         (uneval-valueo xs v2 e2))))))

(define uneval-neutralo
  (lambda (xs n expr)
    (conde
      ((== `(NVar ,expr) n)
       (symbolo expr))
      ((fresh (n1 e1)
         (== `(NCar ,n1) n)
         (== `(car ,e1) expr)
         (uneval-neutralo xs n1 e1)))
      ((fresh (n1 e1)
         (== `(NCdr ,n1) n)
         (== `(cdr ,e1) expr)
         (uneval-neutralo xs n1 e1)))
      ((fresh (n^ v ne ve)
         (== `(NApp ,n^ ,v) n)
         (== `(,ne ,ve) expr)
         (uneval-neutralo xs n^ ne)
         (uneval-valueo xs v ve))))))

(define nfo
  (lambda (t env expr)
    (fresh (v)
      (eval-expro t env v)
      (uneval-valueo '() v expr))))

(define main
  (lambda ()
    (run* (result)
      (fresh (id_ const_)
        (eval-expro '(lambda (x) x) '() id_)
        (eval-expro '(lambda (x) (lambda (y) x)) '() const_)
        (eval-expro '(const id) `((id . ,id_) (const . ,const_)) result)))))


(test "main"
  (main)
  '((closure (y) x ((x . (closure (x) x ()))))))

;; nf [] (Lam "x" (App (Lam "y" (App (Var "x") (Var "y"))) (Lam "x" (Var "x"))))
;; =>
;; Lam "x" (App (Var "x") (Lam "x'" (Var "x'")))
(test "nf-0"
  (run* (expr)
    (nfo '(lambda (x) ((lambda (y) (x y)) (lambda (x) x))) '() expr))
  '(((lambda (_.0) (_.0 (lambda (_.1) _.1)))
     (=/= ((_.0 _.1)))
     (sym _.0 _.1))))
