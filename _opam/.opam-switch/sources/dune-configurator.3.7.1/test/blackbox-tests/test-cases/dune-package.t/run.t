  $ mkdir a
  $ cp dune dune-project a.opam a

  $ dune build --root=a
  Entering directory 'a'
  Leaving directory 'a'
  $ dune_cmd cat a/_build/install/default/lib/a/dune-package | sed "s/(lang dune .*)/(lang dune <version>)/" | dune_cmd sanitize
  (lang dune <version>)
  (name a)
  (sections (lib .) (libexec .) (share ../../share/a))
  (files
   (lib
    (META
     a$ext_lib
     a.cma
     a.cmi
     a.cmt
     a.cmx
     a.cmxa
     a.ml
     a__X.cmi
     a__X.cmt
     a__X.cmx
     b/c/.private/c__Y.cmi
     b/c/.private/c__Y.cmt
     b/c/.private/c__Y.cmti
     b/c/c$ext_lib
     b/c/c.cma
     b/c/c.cmi
     b/c/c.cmt
     b/c/c.cmx
     b/c/c.cmxa
     b/c/c.ml
     b/c/c__Y.cmx
     b/c/y.ml
     b/c/y.mli
     byte_only/d.cma
     byte_only/d.cmi
     byte_only/d.cmt
     byte_only/d.ml
     byte_only/d__Z.cmi
     byte_only/d__Z.cmt
     byte_only/z.ml
     dune-package
     opam
     x.ml))
   (libexec (a.cmxs b/c/c.cmxs))
   (share (foo.txt)))
  (library
   (name a)
   (kind normal)
   (archives (byte a.cma) (native a.cmxa))
   (plugins (byte a.cma) (native a.cmxs))
   (native_archives a$ext_lib)
   (main_module_name A)
   (modes byte native)
   (modules
    (wrapped
     (group
      (alias
       (obj_name a)
       (visibility public)
       (kind alias)
       (source (path A) (impl (path a.ml-gen))))
      (name A)
      (modules
       (module
        (obj_name a__X)
        (visibility public)
        (source (path X) (impl (path x.ml))))))
     (wrapped true))))
  (library
   (name a.b.c)
   (kind normal)
   (archives (byte b/c/c.cma) (native b/c/c.cmxa))
   (plugins (byte b/c/c.cma) (native b/c/c.cmxs))
   (native_archives b/c/c$ext_lib)
   (main_module_name C)
   (modes byte native)
   (obj_dir (private_dir .private))
   (modules
    (wrapped
     (group
      (alias
       (obj_name c)
       (visibility public)
       (kind alias)
       (source (path C) (impl (path b/c/c.ml-gen))))
      (name C)
      (modules
       (module
        (obj_name c__Y)
        (visibility private)
        (source (path Y) (intf (path b/c/y.mli)) (impl (path b/c/y.ml))))))
     (wrapped true))))
  (library
   (name a.byte_only)
   (kind normal)
   (archives (byte byte_only/d.cma))
   (plugins (byte byte_only/d.cma))
   (main_module_name D)
   (modes byte)
   (modules
    (wrapped
     (group
      (alias
       (obj_name d)
       (visibility public)
       (kind alias)
       (source (path D) (impl (path byte_only/d.ml-gen))))
      (name D)
      (modules
       (module
        (obj_name d__Z)
        (visibility public)
        (source (path Z) (impl (path byte_only/z.ml))))))
     (wrapped true))))

Build with "--store-orig-source-dir" profile
  $ dune build --root=a --store-orig-source-dir
  Entering directory 'a'
  Leaving directory 'a'
  $ dune_cmd cat a/_build/install/default/lib/a/dune-package | grep -A 1 '(orig_src_dir'
   (orig_src_dir
    $TESTCASE_ROOT/a)
  --
   (orig_src_dir
    $TESTCASE_ROOT/a)
  --
   (orig_src_dir
    $TESTCASE_ROOT/a)

Build with "DUNE_STORE_ORIG_SOURCE_DIR=true" profile
  $ DUNE_STORE_ORIG_SOURCE_DIR=true dune build --root=a
  Entering directory 'a'
  Leaving directory 'a'
  $ dune_cmd cat a/_build/install/default/lib/a/dune-package | grep -A 1 '(orig_src_dir'
   (orig_src_dir
    $TESTCASE_ROOT/a)
  --
   (orig_src_dir
    $TESTCASE_ROOT/a)
  --
   (orig_src_dir
    $TESTCASE_ROOT/a)

Install the package directly

  $ dune install "--prefix=$PWD/prefix" --root=a 2>&1 | grep -v "Installing"
  [1]

  $ dune_cmd cat prefix/lib/a/dune-package | grep -e 'lib/a' -e 'share/a'
    $TESTCASE_ROOT/prefix/lib/a)
    $TESTCASE_ROOT/prefix/lib/a)
    $TESTCASE_ROOT/prefix/share/a))


Install as opam does

  $ dune_cmd cat a/a.opam
  # This file is generated by dune, edit dune-project instead
  opam-version: "2.0"
  depends: [
    "dune" {>= "3.0"}
    "odoc" {with-doc}
  ]
  build: [
    ["dune" "subst"] {dev}
    [
      "dune"
      "build"
      "-p"
      name
      "-j"
      jobs
      "@install"
      "@runtest" {with-test}
      "@doc" {with-doc}
    ]
  ]

  $ (cd a; "dune" "build" "-p" a "@install")

  $ dune_cmd cat a/a.install | grep dune-package
    "_build/install/default/lib/a/dune-package"

  $ dune_cmd cat "a/_build/install/default/lib/a/dune-package" | grep -e 'lib [.]' -e 'share [.]'
  (sections (lib .) (libexec .) (share ../../share/a))