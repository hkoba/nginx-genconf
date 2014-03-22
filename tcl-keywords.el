;; -*- coding: utf-8 -*-

;; ↓こうしておかないと、Tcl-mode が発狂する。
(condition-case nil
    (require 'filladapt)
  (error nil))

(require 'tcl)

(mapcar
 (lambda (word) (add-to-list 'tcl-typeword-list word))
 '("option"
   "bind"
   "style"
   "component"
   "hulltype"
   ;; menu
   "command"
   "separator"
   "cascade"
   ;; geom
   "grid" "pack" "place"
   ))

(mapcar
 (lambda (word) (add-to-list 'tcl-proc-list word))
 '("snit::type"
   "snit::method"
   "snit::macro"
   "snit::widget"
   "snit::widgetadaptor"
   "snit::typemethod"
   "snit::macro"
   "onconfigure"
   "oncget"
   ))
(tcl-set-proc-regexp)

(mapcar
 (lambda (word) (add-to-list 'tcl-keyword-list word))
 '("package" "require"

   "configure" "configurelist" "cget"
   "itemconfigure" "itemcget"

   "insert" "delete" "destroy" "add"
   "create"

   "snit::type"
   "snit::method"
   "snit::widget"
   "snit::widgetadaptor"
   "onconfigure"
   "oncget"
   "typevariable"
   "typeconstructor"
   "typemethod"

   "mymethod"
   "mytypemethod"
   "myvar"
   "myproc"
   "mytypevar"

   "install"
   "installhull"
   "delegate"

   "to" "using" "as" "except" "hull"

   "tag"

   "-public"
   "-cgetmethod"
   "-configuremethod"
   "-default"

   "-command"

   "width" "height"
   ))

(mapcar
 (lambda (word) (add-to-list 'tcl-builtin-list word))
 '(;; std tk
   "button" "menu" "listbox" "canvas" "checkbutton" "radiobutton" "frame"
   "entry" "wm" "title"

   ;; BWidget
   "ScrolledWindow" "Button" "Entry"

   "table"
   

   "ttk::paned" "ttk::notebook"

   ;; new tcl
   "lset" "dict"
   ))
(tcl-set-font-lock-keywords)
