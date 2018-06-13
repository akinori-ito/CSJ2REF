package require csv

tk::Megawidget create ComposedWidget tk::SimpleWidget {
    variable w hull options forwardlist
    method Create {} {
        set forwardlist {}
    }
    method GetSpecs {} {
        next
    }
    method configure {optsw val} {
        foreach {widget optionlist} $forwardlist {
            if {[lsearch $optionlist $optsw] >= 0} {
                $widget configure $optsw $val
            }
        }
    }
    method forwardoption {} {
        # optlist: {widget optionlist widget optionlist ... }
        foreach {optsw val} [array get options] {
            $w configure $optsw $val
        }
   }
   method forward {parts cmd arg} {
      return [eval [concat $hull.$parts $cmd $arg]]
   }
}

tk::Megawidget create FileEntry ComposedWidget {
    variable w options hull hook forwardlist
    method Create {} {
        variable opt_entry opt_all opt_label opt_org
        set opt_all {-background -borderwidth -cursor -font -foreground -justify -takefocus}
        set opt_entry {-disabledbackground -disabledforeground -exportselection -highlightbackground
                       -highlightcolor -highlightthickness -insertbackground -relief 
                       -insertborderwidth -insertofftime -insertontime -insertwidth -invalidcommand 
                       -readonlybackground -selectbackground -selectborderwidth -selectforeground
                       -show -state -textvariable -validate -validatecommand -width -xscrollcommand}
        set opt_org {-hook}
        set opt_label {-text}
        label $hull.l
        entry $hull.ent
        button $hull.b -command "$w setfile" -text "..." -relief raise
        set forwardlist [list \
                         $hull.l [concat $opt_all $opt_label]\
                         $hull.b $opt_all \
                         $hull.ent [concat $opt_all $opt_entry] \
                         $w $opt_org]
        $w forwardoption
        pack $hull.l $hull.ent $hull.b -side left
    }
    method configure {optsw val} {
        if {$optsw eq "-hook"} {
            set hook $val
        } else {
            next $optsw $val
        }
    
    }
    method setfile {} {
        set file [tk_getOpenFile -defaultextension .csv -filetypes {{"Text CSV" .csv}}]
        if {$file ne ""} {
            $hull.ent delete 0 end
            $hull.ent insert end $file
            if {$hook ne {}} {
                eval $hook
            }
        }
    }
    method get {} {
        return [$hull.ent get]
    }
    method insert args {
        $hull.ent insert {*}$args
    }
    method delete args {
        $hull.ent delete {*}$args
    }
    method GetSpecs {} {
      return {
        {-text text Text {} {}}
        {-width width Width 20 20}
        {-hook hook Hook {} {}}
        {-borderwidth borderWidth BorderWidth 1 1}
        {-cursor cursor Cursor xterm xterm}
        {-disabledbackground disabledBackground DisabledBackground SystemButtonFace SystemButtonFace}
        {-disabledforeground disabledForeground DisabledForeground SystemDisabledText SystemDisabledText}
        {-exportselection exportSelection ExportSelection 1 1}
        {-font font Font TkTextFont TkTextFont}
        {-foreground foreground Foreground SystemWindowText SystemWindowText}
        {-highlightbackground highlightBackground HighlightBackground SystemButtonFace SystemButtonFace}
        {-highlightcolor highlightColor HighlightColor SystemWindowFrame SystemWindowFrame}
        {-highlightthickness highlightThickness HighlightThickness 0 0}
        {-insertbackground insertBackground Foreground SystemWindowText SystemWindowText}
        {-insertborderwidth insertBorderWidth BorderWidth 0 0}
        {-insertofftime insertOffTime OffTime 300 300}
        {-insertontime insertOnTime OnTime 600 600}
        {-insertwidth insertWidth InsertWidth 2 2}
        {-invalidcommand invalidCommand InvalidCommand {} {}}
        {-justify justify Justify left left}
        {-readonlybackground readonlyBackground ReadonlyBackground SystemButtonFace SystemButtonFace}
        {-relief relief Relief sunken sunken}
        {-selectbackground selectBackground Foreground SystemHighlight SystemHighlight}
        {-selectborderwidth selectBorderWidth BorderWidth 0 0}
        {-selectforeground selectForeground Background SystemHighlightText SystemHighlightText}
        {-show show Show {} {}}
        {-state state State normal normal}
        {-takefocus takeFocus TakeFocus {} {}}
        {-textvariable textVariable Variable {} {}}
        {-validate validate Validate none none}
        {-validatecommand validateCommand ValidateCommand {} {}}
        {-width width Width 20 20}
        {-xscrollcommand xScrollCommand ScrollCommand {} {}}
      }
    }
}

array set itemindex {}
set reference {}

proc read_data {filename} {
    global itemindex reference
    array set itemindex {}
    set reference {}
    set f [open $filename r]
    # the first line
    gets $f line
    set x [::csv::split -alternate $line , {"}]
    for {set i 0} {$i < [llength $x]} {incr i} {
        set itemindex([lindex $x $i]) $i
    }
    
    while 1 {
        gets $f line
        if {[eof $f]} {
            break
        }
        lappend reference [::csv::split -alternate $line]
    }
    close $f
}

proc getitem {xlist indexname} {
    global itemindex
    return [lindex $xlist $itemindex($indexname)]
}

proc getentry {xlist} {
    set vol {}
    set no {}
    set startpage {}
    set endpage {}
    set author [getitem $xlist {著者(日本語)}]
    if {$author eq {}} {
        set author [getitem $xlist {著者(英語)}]
    }
    set n_and [regexp -all {[, ]and } $author]
    if {$n_and > 1} {
        # X and Y and Z and...
        # replace "and" excluding the last one with ","
        for {set i 1} {$i < $n_and} {incr i} {
            regsub {[, ]*and} $author "," author 
        }
    }
    regsub -all {,([^ ])} $author {, \1} author
    set title [getitem $xlist {タイトル(日本語)}]
    if {$title eq {}} {
        set title [getitem $xlist {タイトル(英語)}]
    }
    set type [getitem $xlist {掲載種別}]
    set journal [getitem $xlist {誌名(日本語)}]
    set vol [getitem $xlist {巻}]
    set no [getitem $xlist {号}]
    set year [string range [getitem $xlist {出版年月}] 0 3]
    set startpage [getitem $xlist {開始ページ}]
    set endpage [getitem $xlist {終了ページ}]
    set res {not precessed}
    switch $type {
        # 論文, book chapter
        5 -
        1 {
            set res "$author, “$title,” $journal,"
            if {$vol ne {}} {
                set res "$res vol. $vol,"
            }
            if {$no ne {}} {
                set res "$res no. $no,"
            }
            if {$startpage ne {} && $endpage ne {}} {
                set res "$res pp. $startpage-$endpage,"
            }
            set res "$res $year."
        }
        # 国際会議
        2 {
            if {![regexp {^[Pp]roc} $journal]} {
                set journal "Proceedings of $journal"
            }
            set res "$author, “$title,” $journal,"
            if {$vol ne {}} {
                set res "$res vol. $vol,"
            }
            if {$no ne {}} {
                set res "$res no. $no,"
            }
            if {$startpage ne {} && $endpage ne {}} {
                set res "$res pp. $startpage-$endpage,"
            }
            set res "$res $year."            
        }
    }
    return $res
}

proc proc_file {} {
    global reference sel_language
    read_data [.f.fe get]
    foreach ref $reference {
      set lang [getitem $ref 記述言語]
      if {$lang eq "ja" && $sel_language eq {英語のみ}} {
         continue
      } elseif {$lang eq "en" && $sel_language eq {日本語のみ}} {
         continue
      }
      .t.ext insert end [getentry $ref]
      .t.ext insert end "\n"
    }    
}

frame .f
pack .f
FileEntry .f.fe -text FILE:
button .f.do -text DO -command proc_file
button .f.clear -text CLEAR -command {.t.ext delete 1.0 end}
ttk::combobox .f.sel -values {英語のみ 日本語のみ 両方} -textvariable sel_language -state readonly
pack .f.fe .f.do .f.clear .f.sel -side left
.f.sel current 2
frame .t
pack .t -side top
text .t.ext -yscrollcommand ".t.scr set"
scrollbar .t.scr -command ".t.ext yview"
grid .t.ext -row 0 -column 0 -sticky news
grid .t.scr -row 0 -column 1 -sticky ns




