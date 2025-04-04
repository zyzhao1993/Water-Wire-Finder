package provide waterwire
#package require tooltip
source [file join [file dirname [info script]] bigdcd.tcl]

namespace eval ::WaterWire:: {
    variable w
    variable mollistmenu {}
    foreach t [molinfo list] {
	lappend mollistmenu [list [molinfo $t get id] {:} [molinfo $t get name]]
    }

}

proc WaterWire::waterwire {} {
    variable w

    if { [winfo exists .waterwire] } {
	wm deiconify $w
	return
    }

    set w [toplevel ".waterwire"]
    wm title $w "Water Wire Finder"
    wm resizable $w 1 1
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 4 -weight 1

    variable ::WaterWire::readfromfile 0
    variable ::WaterWire::selectedmol ""
    if {[llength [molinfo list]]!=0} {
        set selectedmol [list [molinfo top get id] {:} [molinfo top get name]]
    }
    variable ::WaterWire::psffile ""
    variable ::WaterWire::pdbfile ""
    variable ::WaterWire::firstframe 0
    variable ::WaterWire::lastframe -1
    variable ::WaterWire::stepframe 1
    variable ::WaterWire::allselstr
    variable ::WaterWire::startselstr
    variable ::WaterWire::endselstr
    if {![info exists ::WaterWire::allselstr]} {set ::WaterWire::allselstr "same residue as (water and within 3 of protein)"}
    if {![info exists ::WaterWire::startselstr]} {set ::WaterWire::startselstr "z>20"}
    if {![info exists ::WaterWire::endselstr]} {set ::WaterWire::endselstr "z<-20"}
    variable ::WaterWire::hbonddiscutoff 3.0
    variable ::WaterWire::hbondanglecutoff 20
    variable ::WaterWire::searchtype 0
    variable ::WaterWire::about 0

    #menu bar
    frame $w.menubar -relief raised -bd 2
    grid columnconfigure $w.menubar 0 -weight 1

    menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu
    menu $w.menubar.help.menu -tearoff no
    $w.menubar.help.menu add command -label "About" -underline 0 -command WaterWire::about
    $w.menubar.help.menu add command -label "How to use" -underline 0 -command WaterWire::howToUse
    $w.menubar.help config -width 5
    grid $w.menubar.help -row 1 -column 1 -sticky w -padx 2 -pady 0

    #molecule
    frame $w.mol -relief ridge -bd 2
    grid columnconfigure $w.mol 0 -weight 1

    #mol.input
    frame $w.mol.input 
    label $w.mol.input.label -text "Input Molecule:" -anchor nw
    checkbutton $w.mol.input.fileinput -text "Read from files" -onvalue 1 -offvalue 0 -variable ::WaterWire::readfromfile -command ::WaterWire::switchInput
    $w.mol.input.fileinput deselect
    grid $w.mol.input.label -row 0 -column 0 -sticky w -padx 2 -pady 2 
    grid $w.mol.input.fileinput -row 0 -column 1 -columnspan 2 -sticky e -padx 2 -pady 2 

    #mol.molID
    frame $w.mol.molID
    label $w.mol.molID.label -text "Mol ID :" -anchor e -width 10
    global vmd_initialize_structure
    trace add variable vmd_initialize_structure write ::WaterWire::updateMolMenu
    ttk::combobox $w.mol.molID.select -values $::WaterWire::mollistmenu -textvariable ::WaterWire::selectedmol -width 80
    grid $w.mol.molID.label -row 1 -column 0 -sticky w -padx 2 -pady 2 
    grid $w.mol.molID.select -row 1 -column 1 -columnspan 2 -sticky new   
    grid columnconfigure $w.mol.molID 1 -weight 1 

    #mol.read
    frame $w.mol.read
    label $w.mol.read.psflabel -text "PSF: " -anchor e -width 10
    entry $w.mol.read.psfpath -width 75 -text " " -textvariable ::WaterWire::psffile -validate focus -validatecommand {::WaterWire::isFile %P .waterwire.mol.read.psfpath}
    button $w.mol.read.psfbutton -text "Browse" \
	-command {
	    set tempfile [tk_getOpenFile -filetypes {{{psf} {.psf}} {{All} *}}]
	    if {![string equal $tempfile ""]} {set ::WaterWire::psffile $tempfile}
	}
    label $w.mol.read.pdblabel -text "PDB/DCD: " -anchor e -width 10
    entry $w.mol.read.pdbpath -width 75 -text " " -textvariable ::WaterWire::pdbfile -validate focus -validatecommand {::WaterWire::isFile %P .waterwire.mol.read.pdbpath}
    button $w.mol.read.pdbbutton -text "Browse" \
	-command {
	    set tempfile [tk_getOpenFile -filetypes {{{dcd} {.dcd}} {{pdb} {.pdb}} {{All} *} }]
	    if {![string equal $tempfile ""]} {set ::WaterWire::pdbfile $tempfile}
	}
    $w.mol.read.psfpath config -state disabled
    $w.mol.read.pdbpath config -state disabled
    $w.mol.read.psfbutton config -state disabled
    $w.mol.read.pdbbutton config -state disabled
    grid $w.mol.read.psflabel -row 0 -column 0 -sticky w -padx 2 -pady 2 
    grid $w.mol.read.psfpath -row 0 -column 1 -sticky we 
    grid $w.mol.read.psfbutton -row 0 -column 2 -sticky e 
    grid $w.mol.read.pdblabel -row 1 -column 0 -sticky w  -padx 2 -pady 2
    grid $w.mol.read.pdbpath -row 1 -column 1 -sticky we
    grid $w.mol.read.pdbbutton -row 1 -column 2 -sticky e 
    grid columnconfigure $w.mol.read 1 -weight 1

    #mol.frames
    frame $w.mol.frames 
    label $w.mol.frames.firstlabel -text "First: " -anchor e -width 10
    entry $w.mol.frames.first -textvariable ::WaterWire::firstframe -validate all -validatecommand {expr {[string is int %P]}}
    label $w.mol.frames.lastlabel -text "Last: " -anchor e -width 10
    entry $w.mol.frames.last -textvariable ::WaterWire::lastframe -validate all -validatecommand {expr {[string is int %P]}}
    label $w.mol.frames.steplabel -text "Step: " -anchor e -width 10
    entry $w.mol.frames.step -textvariable ::WaterWire::stepframe -validate all -validatecommand {expr {[string is int %P]}}

    grid $w.mol.frames.firstlabel -column 0 -row 0 -sticky w -padx 2 -pady 2
    grid $w.mol.frames.first -column 1 -row 0 -sticky we
    grid $w.mol.frames.lastlabel -column 2 -row 0 -sticky w -padx 2 -pady 2
    grid $w.mol.frames.last -column 3 -row 0 -sticky we
    grid $w.mol.frames.steplabel -column 4 -row 0 -sticky w -padx 2 -pady 2
    grid $w.mol.frames.step -column 5 -row 0 -sticky we
    grid columnconfigure $w.mol.frames 1 -weight 1 -minsize 15
    grid columnconfigure $w.mol.frames 3 -weight 1 -minsize 15
    grid columnconfigure $w.mol.frames 5 -weight 1 -minsize 15

    #grid mol
    grid $w.mol.input -column 0 -row 0 -sticky nsew -padx 2 -pady 2
    grid $w.mol.molID -column 0 -row 1 -sticky nsew -padx 2 -pady 2
    #grid $w.mol.read -column 0 -row 2 -sticky nsew -padx 2 -pady 2
    grid $w.mol.frames -column 0 -row 2 -sticky nsew -padx 2 -pady 2
    grid columnconfigure $w.mol 0 -weight 1 
    grid rowconfigure $w.mol 1 -weight 1 

    #parameters
    frame $w.para -relief ridge -bd 2 
    grid columnconfigure $w.para 0 -weight 1
    label $w.para.sellabel -text "Atom selections:" -anchor w
    
    #para.sel
    frame $w.para.sel 
    label $w.para.sel.allsellabel -text "Water wire atom restriction: " -width 23 -anchor e  
    label $w.para.sel.startsellabel -text "Atom group 1: " -width 23  -anchor e
    label $w.para.sel.endsellabel -text "Atom group 2: " -width 23  -anchor e
    tooltip::tooltip $w.para.sel.allsellabel "Atomselection of atoms the waterwire goes through"
    tooltip::tooltip $w.para.sel.startsellabel "Atomselection of atoms the waterwire starts from"
    tooltip::tooltip $w.para.sel.endsellabel "Atomselection of atoms the waterwire goes to"
    entry $w.para.sel.allselstr -textvariable ::WaterWire::allselstr -width 50
    entry $w.para.sel.startselstr -textvariable ::WaterWire::startselstr -width 50
    entry $w.para.sel.endselstr -textvariable ::WaterWire::endselstr -width 50
    grid $w.para.sel.startsellabel -row 0 -column 0 -sticky w
    grid $w.para.sel.startselstr -row 0 -column 1 -sticky we
    grid $w.para.sel.endsellabel -row 1 -column 0 -sticky w
    grid $w.para.sel.endselstr -row 1 -column 1 -sticky we
    grid $w.para.sel.allsellabel -row 2 -column 0 -sticky w
    grid $w.para.sel.allselstr -row 2 -column 1 -sticky we
    grid columnconfigure $w.para.sel 1 -weight 1

    #para.type
    frame $w.para.type
    label $w.para.type.label -text "Search type:" -anchor w -width 10
    radiobutton $w.para.type.type0 -text "Least number of bonds (covalent bonds + H-bonds)" -variable WaterWire::searchtype -value 0 -anchor w
    radiobutton $w.para.type.type1 -text "Shortest physical length" -variable WaterWire::searchtype -value 1 -anchor w
    $w.para.type.type0 select
    
    grid $w.para.type.label -row 0 -column 0 -sticky w
    grid $w.para.type.type0 -row 1 -column 1 -sticky we
    grid $w.para.type.type1 -row 2 -column 1 -sticky we

    #para.hbond
    frame $w.para.hbond
    label $w.para.hbond.label -text "H-bonds cutoff:" -anchor w -width 20
    label $w.para.hbond.dislabel -text "Distance (angstrom) : " -anchor e
    label $w.para.hbond.anglelabel -text "Angle (degree) : " -anchor w
    entry $w.para.hbond.dis -textvariable ::WaterWire::hbonddiscutoff 
    entry $w.para.hbond.angle -textvariable ::WaterWire::hbondanglecutoff 
    grid $w.para.hbond.label -row 0 -column 0 -padx 2 -pady 2 -sticky w
    grid $w.para.hbond.dislabel -row 1 -column 0 -padx 2 -pady 2 -sticky e
    grid $w.para.hbond.dis -row 1 -column 1 -padx 2 -pady 2 -sticky we
    grid $w.para.hbond.anglelabel -row 1 -column 2 -padx 2 -pady 2 -sticky w
    grid $w.para.hbond.angle -row 1 -column 3 -padx 2 -pady 2 -sticky we
    grid columnconfigure $w.para.hbond 1 -weight 1
    grid columnconfigure $w.para.hbond 3 -weight 1

    grid $w.para.sellabel -row 0 -column 0 -padx 2 -pady 2 -sticky w
    grid $w.para.sel -row 1 -column 0 -padx 2 -pady 2 -sticky we
    grid $w.para.type -row 2 -column 0 -padx 2 -pady 2 -sticky we
    grid $w.para.hbond -row 3 -column 0 -sticky we

    #RUN button
    frame $w.run -relief ridge -bd 2
    button $w.run.button -text "RUN NOW!" -state normal -command ::WaterWire::run
    label $w.run.status -text "Idle"
    button $w.run.abortbutton -text "Abort" -state normal -width 5 -command {set ::WaterWire::abort 1}
    set ::WaterWire::abort 0
    grid $w.run.button -row 0 -column 0  -sticky we
    grid $w.run.abortbutton -row 0 -column 1 -sticky e
    grid $w.run.status -row 1 -column 0 -columnspan 2 -sticky we
    grid columnconfigure $w.run 0 -weight 1

    #output
    frame $w.output -relief ridge -bd 2
    #tablelist::tablelist $w.output.results -columns {0 "first" 0 "second"} -stretch all -background white -xscrollcommand "$w.output.srl_x set" -yscrollcommand "$w.output.srl_y set" -labelcommand tablelist::sortByColumn
    tablelist::tablelist $w.output.results -stretch all -background white -xscrollcommand "$w.output.srl_x set" -yscrollcommand "$w.output.srl_y set" -labelcommand tablelist::sortByColumn -showseparators true -background white 
    scrollbar $w.output.srl_y -command "$w.output.results yview" -orient v
    scrollbar $w.output.srl_x -command "$w.output.results xview" -orient h
    bind $w.output.results <<TablelistSelect>> [list WaterWire::frameSelected %W]
    grid $w.output.results -row 0 -column 0 -sticky wens
    grid $w.output.srl_y -row 0 -column 1 -sticky ns
    grid $w.output.srl_x -row 1 -column 0 -sticky we
    grid columnconfigure $w.output 0 -weight 1
    grid rowconfigure $w.output 0 -weight 1

    #output control
    frame $w.opcntl 
    checkbutton $w.opcntl.showonlycon -text "Show only connected frames" -onvalue 1 -offvalue 0 -variable ::WaterWire::soc -state disabled -command ::WaterWire::showOnlyConnected
    $w.opcntl.showonlycon deselect
    button $w.opcntl.refresh -text "Refresh" -command ::WaterWire::refresh
    button $w.opcntl.save -text "Save to file" -command WaterWire::save
    grid $w.opcntl.showonlycon -row 0 -column 0 -sticky nw
    grid $w.opcntl.refresh -row 0 -column 1 -sticky ne
    grid $w.opcntl.save -row 0 -column 2 -sticky ne
    grid columnconfigure $w.opcntl 0 -weight 1

    grid $w.menubar -row 0 -column 0 -sticky e -padx 2 -pady 0
    grid $w.mol -row 1 -column 0 -columnspan 3 -sticky we -padx 2 -pady 2
    grid $w.para -row 2 -column 0 -columnspan 3 -sticky we -padx 2 -pady 2
    grid $w.run -row 3 -column 0 -sticky we
    grid $w.output -row 4 -column 0 -sticky nswe
    grid $w.opcntl -row 5 -column 0 -sticky we
}

proc WaterWire::save {} {
    variable results
    variable w
    if {![info exists results]} {
	tk_messageBox -icon error -message "no results yet"
	return
    }
    if {[llength $results]==0} {
	tk_messageBox -icon error -message "no results yet"
	return
    }
    set filename [tk_getSaveFile -title "Save log to file" -parent $w]
    if {$filename==""} {return}
    if {[file exists $filename]} {
	tk_messageBox -icon error -message "file already exists"
    }
    set f [open $filename w]
    foreach result $results {
	puts $f $result
    }
    close $f
}

proc WaterWire::run {} {
    if {[::WaterWire::checkInput]==-1} {return}
    #$w.output.results config -columns {0 "first" 0 "second"}
    variable w
    $w.output.results delete 0 end
    $w.opcntl.showonlycon deselect
    $w.opcntl.showonlycon configure -state disabled
    variable abort
    set abort 0
    update
    #bind $w.output.results <<TablelistSelect>> [list WaterWire::frameSelected %W]
    WaterWire::waterwire_core
    update
    $w.output.results columnconfigure 0 -sortmode integer
    $w.output.results columnconfigure 1 -sortmode integer
    $w.output.results columnconfigure 2 -sortmode real
    $w.opcntl.showonlycon configure -state normal
    #$w.run.abortbutton configure -state disabled

    if {$abort==0} {
	updateStatusText "Done!"
    } else {
	updateStatusText "Aborted!"
	set abort 0
    }
    return
}

proc WaterWire::refresh {} {
    variable w
    $w.output.results delete 0 end
    set ::WaterWire::allselstr ""
    set ::WaterWire::startselstr ""
    set ::WaterWire::endselstr ""
    variable results
    set results {}
}

proc WaterWire::frameSelected {w} {
#adapted from cispeptide
    set row [$w curselection] 
    if {$row==""} {return}
    variable results
    set result [lindex $results [lsearch $results [$w getcells $row,0]*]]
    #if {[lindex $result 1]==Inf} {return}
    set atomlist [lindex $result 2]
    set frame [lindex $result 0]
    variable molid
    variable waterwireReps
    variable readfromfile
    mol top $molid
    foreach id [molinfo list] {mol off $id}
    mol on $molid
    if {!$readfromfile} {
	animate goto $frame	
    } else {
	animate delete all
	variable pdbfile 
	mol addfile $pdbfile first $frame last $frame waitfor all
    }
    waterwire_reset_reps
    #for {set i 0} {$i<[molinfo $molid get numreps]} {incr i} {
    #    mol showrep $molid $i off
    #}

    variable allselstr

    mol color Name
    mol representation Lines 
    mol material Opaque
    mol selection $allselstr
    mol addrep $molid
    set repid [expr [molinfo $molid get numreps] - 1]
    set repname [mol repname $molid $repid]
    lappend waterwireReps $molid
    lappend waterwireReps $repname

    if {[lindex $result 1]!=Inf} {
    mol color Name
    mol representation VDW 0.5
    mol material Opaque
    mol selection "index $atomlist"
    mol addrep $molid
    set repid [expr [molinfo $molid get numreps] - 1]
    set repname [mol repname $molid $repid]
    lappend waterwireReps $molid
    lappend waterwireReps $repname

    #variable hbonddiscutoff 
    #variable hbondanglecutoff
    #mol color Name
    #mol representation HBonds $hbonddiscutoff $hbondanglecutoff 3 
    #mol material Opaque
    #mol selection "same residue as (index $atomlist)"
    #mol addrep $molid
    #set repid [expr [molinfo $molid get numreps] - 1]
    #set repname [mol repname $molid $repid]
    #lappend waterwireReps $molid
    #lappend waterwireReps $repname
    variable waterwireDraws
    set waterwireDraws {}
    for {set i 0} {$i<[expr [llength $atomlist]-1]} {incr i} {
	set atm1 [lindex $atomlist $i]
	set atm2 [lindex $atomlist [expr $i+1]]
	set sel1 [atomselect $molid "index $atm1"]
	set sel2 [atomselect $molid "index $atm2"]
	set xyz1 [lindex [$sel1 get {x y z}]]
	set xyz2 [lindex [$sel2 get {x y z}]]
	$sel1 delete
	$sel2 delete
	lappend waterwireDraws [draw cylinder {*}$xyz1 {*}$xyz2 radius 0.2 filled yes]
    }
    

    set sel [atomselect $molid "index $atomlist"]
    set center [measure center $sel]
    $sel delete
    foreach mol [molinfo list] {
	molinfo $mol set center [list $center]
    }
    }
    scale to 0.1
    translate to 0 0 0
    display update

}

proc WaterWire::waterwire_reset_reps {} {
    variable waterwireReps
    variable waterwireDraws
    if {![info exists waterwireReps]} {return}
    foreach {molid repname} $waterwireReps {
	if { [lsearch [molinfo list] $molid] != -1} {
	    set repid [mol repindex $molid $repname]
	    mol delrep $repid $molid
	}
    }
    set waterwireReps {}
    if {![info exists waterwireDraws]} {return}
    foreach id $waterwireDraws {
	draw delete $id
    }
    set waterwireDraws {}
}



proc WaterWire::checkInput {} {
    variable readfromfile
    if {!$readfromfile} {
	variable selectedmol
	if {$selectedmol==""} {
	    tk_messageBox -icon error -message "No molecule selected!"
	    return -1
	} 
	if {[lsearch [molinfo list] [lindex $selectedmol 0]]<0} {
	    tk_messageBox -icon error -message "Selected molecule doesn't exist!"
	    return -1
	}
	if {[molinfo [lindex $selectedmol 0] get numframes]==0} {
	    tk_messageBox -icon error -message "Empty molecule!"
	    return -1
	}
    } else {
	variable psffile
	variable pdbfile
	if {$psffile==""} {
	    tk_messageBox -icon error -message "No input psf file!"
	    return -1
	}
	if {$pdbfile==""} {
	    tk_messageBox -icon error -message "No input pdb/dcd file!"
	    return -1
	}
	if {![file exists $psffile] || ![file isfile $psffile]} {
	    tk_messageBox -icon error -message "Can't find the psf file!"
	    return -1
	}
	if {![file exists $pdbfile] || ![file isfile $pdbfile]} {
	    tk_messageBox -icon error -message "Can't find the pdb/dcd file!"
	    return -1
	}
    }
    variable allselstr
    variable startselstr
    variable endselstr
    if {$allselstr=="" || $startselstr=="" || $endselstr==""} {
	tk_messageBox -icon error -message "Missing atomselection string!"
	return -1
    }
    variable stepframe
    if {$stepframe<=0} {
	tk_messageBox -icon error -message "Step must be a positive integer"
	return -1
    }
    return 1
}

proc WaterWire::isFile {f w} {
    if {[file exists $f] && [file isfile $f]} {
	$w configure -fg black
	return 1
    } else {
	$w configure -fg red
	return 0
    }
}

proc WaterWire::about {} {
    tk_messageBox -type ok -title "Copyright: " -message "written by ZZ"
}

proc WaterWire::howToUse {} {
    tk_messageBox -type ok -title "Usage: " -message "how to use?"
}

proc WaterWire::switchInput {} {
    variable ::WaterWire::readfromfile
    variable w
    if {!$::WaterWire::readfromfile} {
	$w.mol.molID.select config -state normal
	$w.mol.read.psfpath config -state disabled
	$w.mol.read.pdbpath config -state disabled
	$w.mol.read.psfbutton config -state disabled
	$w.mol.read.pdbbutton config -state disabled
	grid forget $w.mol.read
	grid $w.mol.molID -column 0 -row 1 -sticky ew -padx 2 -pady 2
	grid $w.mol.frames -column 0 -row 2 -sticky nsew -padx 2 -pady 2
    } else {
	$w.mol.molID.select config -state disabled
	$w.mol.read.psfpath config -state normal
	$w.mol.read.pdbpath config -state normal
	$w.mol.read.psfbutton config -state normal 
	$w.mol.read.pdbbutton config -state normal 
	grid forget $w.mol.molID
	grid forget $w.mol.frames
	grid $w.mol.read -column 0 -row 1 -sticky ew -padx 2 -pady 2
    }

}

proc WaterWire::showOnlyConnected {} {
    variable soc
    variable w
    variable results
    variable searchtype
    if {![info exists results]} {return}
    if {[llength $results]==0} {return}
    $w.output.results delete 0 end
    if {$soc==1} {
	foreach result $results {
	    lassign $result frame dis rout
	    if {$dis!=Inf} {
		if {$searchtype==1} {
		    set dis [format "%.3f" $dis]
		}
		$w.output.results insert end [list $frame 1 $dis]
	    }
	}
    }
    if {$soc==0} {
	foreach result $results {
	    lassign $result frame dis rout
	    if {$dis!=Inf} {
		if {$searchtype==1} {
		    set dis [format "%.3f" $dis]
		}
		$w.output.results insert end [list $frame 1 $dis]
	    }
	    if {$dis==Inf} {
		$w.output.results insert end [list $frame 0 Inf]
	    }
	}

    }
}

proc WaterWire::updateStatusText { statusText } {
    variable w
    $w.run.status configure -text $statusText
    update
}

proc WaterWire::updateMolMenu {args} {
    variable mollistmenu
    set mollistmenu {}
    foreach t [molinfo list] {
	lappend mollistmenu [list [molinfo $t get id] {:} [molinfo $t get name]]
    }
    .waterwire.mol.molID.select configure -values $::WaterWire::mollistmenu
}

#WaterWire::waterwire

proc WaterWire::enQueue {q i} {
#add item to the end of the queue
    upvar 1 $q myq 
    lappend myq $i
}

proc WaterWire::enSortedQueue {q W i w} {
#insert an item(i) with weight(w) to a queue(q) with weight(W)
#bsearch
#small weight means higher priority
    upvar 1 $q myq
    upvar 1 $W myW
    
    set left 0
    set right [llength $myq]
    if {$right==0} {
	lappend myq $i
	lappend myW $w
	return
    }
    while {$left < $right} {
	set idx [expr int(floor(($left + $right)/2))]
	set dat [lindex $myW $idx]
	if {$dat==$w} {
	    set myq [linsert $myq $idx $i]
	    set myW [linsert $myW $idx $w]
	    return
	}
	if {$dat<$w} {set left [expr $idx+1]}
	if {$dat>$w} {set right $idx}
    }
    set myq [linsert $myq $left $i]
    set myW [linsert $myW $left $w]
    return
}

proc WaterWire::deSortedQueue {q W} {
    upvar 1 $q myq
    upvar 1 $W myW
    set myq [lassign $myq item]
    set myW [lassign $myW w]
    return $item
}

proc WaterWire::deQueue {q} {
#take 0th item
    upvar 1 $q myq
    set myq [lassign $myq item]
    return $item 
}
proc WaterWire::addEdge {g u v l} {
#g: graph, u: node from, v: node to, l: length
    upvar 1 $g myg
    lappend myg($u) [list $v $l]
    if {$v!=$u} {lappend myg($v) [list $u $l] }
}
proc WaterWire::isReachable {g s d} {
    set verbose 3
    upvar 1 $g myg
    array set visited {}
    array set distance {}
    array set parent {}
    foreach {id edge} [array get myg] {
	set visited($id) False
	set distance($id) INF
	set parent($id) NONE
    }

    set Q [list]    

    WaterWire::enQueue Q $s
    set visited($s) True
    set distance($s) 0
   
    while {[llength $Q]} {
	set n [WaterWire::deQueue Q]
	if {$n==$d} {
	    #finish
	    if {$verbose == 0} {return True}
	    if {$verbose != 0} {
		set cn "end"
		set wireNodeList {}
		while {$parent($cn)!="start"} {
		    set cn $parent($cn)
		    set wireNodeList [linsert $wireNodeList 0 $cn]
		}
		return [list $distance(end) $wireNodeList]
	    }
	}
	if {$myg($n)!={}} {
	    foreach edge $myg($n) {
		lassign $edge neighbor length
	        if {$visited($neighbor)==False} {
		    WaterWire::enQueue Q $neighbor
		    set visited($neighbor) True
		    set distance($neighbor) [expr $distance($n)+$length]
		    set parent($neighbor) $n
	        }
	    }
	}
    }
    if {$verbose == 0} {return False}
    if {$verbose == 1} {return False}
    if {$verbose == 2} {return False}
    if {$verbose == 3} {return [list Inf {}]}
    unset visited
}

proc WaterWire::Dijkstra {g s d} {
    set verbose 3
    upvar 1 $g myg
    array set visited {}
    array set distance {}
    array set parent {}
    set idList {}
    foreach {id edge} [array get myg] {
	lappend idList $id
	set visited($id) False
	set distance($id) Inf
	set parent($id) NONE
    }

    set visited($s) True
    set distance($s) 0
    set parent($s) $s

   
    while {[lsearch [array get visited] False]!=-1} {
	
	#disList contains distances for the unvisited nodes
	set disList {}
	foreach id $idList {
	    lappend disList $distance($id)
	}
	#set minDis [::tcl::mathfunc::min {*}$disList]
	#set minDisID [lsearch $disList $minDis]
	set sortIndices [lsort -indices -real -increasing $disList]
	set minDisID [lindex $sortIndices 0]
	set n [lindex $idList $minDisID]
    
	set idList [lreplace $idList $minDisID $minDisID]
	set visited($n) True
	#puts "$n || [array get distance]"

	if {$myg($n)!={}} {
	    foreach edge $myg($n) {
		lassign $edge neighbor length
		set newDis [expr $distance($n)+$length]
		if {$distance($neighbor)>$newDis} {
		    set distance($neighbor) $newDis
		    set parent($neighbor) $n
		}
	    }
	}
    }
    if {$verbose == 0} {
	if {$distance($d)=="Inf"} {
	    return False
	} else {
	    return True
	}
    }
    if {$verbose != 0} {
	if {$distance($d)=="Inf"} {
	    #return False
	    return [list Inf {}]
	} else {
	    set cn $d
	    set wireNodeList {}
	    while {$parent($cn)!=$s} {
	        set cn $parent($cn)
	        set wireNodeList [linsert $wireNodeList 0 $cn]
	    }
	    return [list $distance($d) $wireNodeList]
	}
    }
    unset visited
    unset distance
    unset parent
}

proc WaterWire::isBonded {id1 id2 molid frame} {
    if {[lsearch [[atomselect $molid "index $id1"] getbonds] $id2] !=-1} {return True}
    return False
}

proc WaterWire::isHbond {id1 id2 molid frame cutoff} {
    set dis [measure bond [list $id1 $id2] molid $molid frame $frame] 
    if {$dis<=$cutoff} {
	return $dis
    } else {
	return False
    }
}

proc WaterWire::buildGraph {g frame} {
    upvar 1 $g myg

    variable allwaterOSel
    variable allnowaterSel
    variable allSel
    variable startSel
    variable endSel
    variable molid
    variable searchtype
    variable hbonddiscutoff
    variable hbondanglecutoff
    $allwaterOSel frame $frame
    $allnowaterSel frame $frame
    $allSel frame $frame
    $startSel frame $frame
    $endSel frame $frame

    $allwaterOSel update
    $allnowaterSel update
    $allSel update
    $startSel update
    $endSel update
    
    #start node and end node
    WaterWire::addEdge myg "start" "start" 0
    WaterWire::addEdge myg "end" "end" 0
    #all nodes
    foreach id [$allSel get index] {
	WaterWire::addEdge myg $id $id 0
    }
    #connect start node and end node
    foreach id [$startSel get index] {
	WaterWire::addEdge myg "start" $id 0
    }
    foreach id [$endSel get index] {
	WaterWire::addEdge myg "end" $id 0
    }
    #connect OH2-H1 and OH2-H2
    #cannot use [topo getbondlist] on water because of the potential H-H bonds
    if {1} {
    set Obondlist [$allwaterOSel getbonds]
    foreach Oid [$allwaterOSel get index] bonded $Obondlist {
	foreach Hid $bonded {
	    if {$searchtype==0} {
		WaterWire::addEdge myg $Oid $Hid 1
	    }
	    if {$searchtype==1} {
		set dis [measure bond [list $Oid $Hid] molid $molid frame $frame] 
		WaterWire::addEdge myg $Oid $Hid $dis
	    }
	}
    }
    }
    if {0} {
    foreach Oid [$allwaterOSel get index] {
	if {$searchtype==0} {
	    WaterWire::addEdge myg $Oid [expr $Oid+1] 1
	    WaterWire::addEdge myg $Oid [expr $Oid+2] 1
	}
	if {$searchtype==1} {
	    set Hid [expr $Oid+1]
	    set dis [measure bond [list $Oid $Hid] molid $molid frame $frame] 
	    WaterWire::addEdge myg $Oid $Hid $dis
	    set Hid [expr $Oid+2]
	    set dis [measure bond [list $Oid $Hid] molid $molid frame $frame] 
	    WaterWire::addEdge myg $Oid $Hid $dis
	}
    }
    }
    set otherbondlist [topo getbondlist -sel $allnowaterSel]
    foreach bond $otherbondlist {
	lassign $bond id1 id2
	if {$searchtype==0} {
	    WaterWire::addEdge myg $id1 $id2 1
	}
	if {$searchtype==1} {
	    set dis [measure bond [list $id1 $id2] molid $molid frame $frame] 
	    WaterWire::addEdge myg $id1 $id2 $dis
	}
    }
    set hbondmeasure [measure hbonds $hbonddiscutoff $hbondanglecutoff $allSel]
    set acclist [lindex $hbondmeasure 1]
    set hlist [lindex $hbondmeasure 2]
    foreach id1 $acclist id2 $hlist {
	if {$searchtype==0} {
	    WaterWire::addEdge myg $id1 $id2 1
	}
	if {$searchtype==1} {
	    set dis [measure bond [list $id1 $id2] molid $molid frame $frame] 
	    WaterWire::addEdge myg $id1 $id2 $dis
	}
    }
}


proc WaterWire::isWaterWired {frame} {
    variable results
    variable totnumframes
    variable abort
    if {$abort==1} {return}

    array set g {}
    set t1 [clock milliseconds]
    buildGraph g $frame 
    set t2 [clock milliseconds]

    variable searchtype
    if {$searchtype==0} {
	set result [isReachable g "start" "end"]
    } 
    if {$searchtype==1} {
	set result [isReachable g "start" "end"]
	lassign $result dis rout
	if {$dis!=Inf} {
	    set result [Dijkstra g "start" "end"]
	}
    }
    set t3 [clock milliseconds]
    puts "graph [expr $t2-$t1], search [expr $t3-$t2]"

    variable w
    lassign $result dis rout
    variable readfromfile
    if {$dis!=Inf} {
	if {$searchtype==1} {
	    set dis [format "%.3f" $dis]
	}
	set connectivity  1
    } else {
	set connectivity  0
    }
    if {!$readfromfile} {
	$w.output.results insert end [list $frame $connectivity $dis]
	lappend results [list $frame $dis $rout]
    } else {
#somehow bigdcd count from 1
	$w.output.results insert end [list [expr $frame-1] $connectivity $dis]
	lappend results [list [expr $frame-1] $dis $rout]
    }
    variable curnum
    incr curnum
    updateStatusText "$curnum/$totnumframes"
    update
}

#proc isWaterWired {idListO idListH idList1 idList2 frame} {
##idListO: all Oxygen, idListH: all Hydrogen, idList1: starting water, idList2: desitination water 
#    array set g {}
#    buildGraph g $idListO $idListH $frame
#    #parray g
#    foreach id1 $idList1 {
#	foreach id2 $idList2 {
#	    if {[isReachable g $id1 $id2]} {
#		return True
#	    }
#	}
#    }
#    return False
#}

proc WaterWire::waterwire_usage {} {
    vmdcon -info "Usage: waterwire <option1?> <option2?>..."
    vmdcon -info "Options:"
    vmdcon -info "  -help"
    vmdcon -info "  trajectory information: (top molecule by default if none is given):"
    vmdcon -info "	-molid <molid> default top"
    vmdcon -info "	-psffile <psf file name> overwrite molid"
    vmdcon -info "	-dcdfile <dcd/pdb file name>"
    vmdcon -info "  frame range (current frame by default if none is given):"
    vmdcon -info "	-first <first frame to analyze> default current frame"
    vmdcon -info "	-last <last frame to analyze> default current frame"
    vmdcon -info "	-all <all frame to analyze> analyze all frames if set"
    vmdcon -info "	-stride <stride> default 1"
    vmdcon -info "  Hbond defination:"
    vmdcon -info "	-Hbond <length of the Hbond cutoff> default 2.5"
    vmdcon -info "  Water selection:"
    vmdcon -info "	-allwater <atomselection string for all the interested water molecules>:"
    vmdcon -info "	-startwater <atomselection string for the start water molecules (in addition to allwater)>:"
    vmdcon -info "	-endwater <atomselection string for the end water molecules (in addition to allwater)>:"
    vmdcon -info "  Others:"
    vmdcon -info "	-wrap <wrap water centered at protein> if given, wrap water"
    vmdcon -info "	-verbose <output verbose> 0 (default): connected(1) or not(0);" 
    vmdcon -info "			          1: number of water molecules, length of water wire (-1 -1 if not connected); "
    vmdcon -info "				  2: number of water molecules, length of water wire (-1 -1 if not connected), Oxygen atom index of water along the wire"
    vmdcon -info "				  3: number of water molecules, length of water wire (-1 -1 if not connected), all atom index along the wire"
    vmdcon -info "	-lengthtype <length type> 0 (default): number of bonds;"
    vmdcon -info "	                          1: number of water molecules (implemented, need more test);"
    vmdcon -info "	                          2: actually length of the bonds (implemented, need more test)"
    vmdcon -info "	-output <output file> print to screen by default"
    error ""
} 

proc WaterWire::waterwire_todelete {args} {
    global errorInfo errorCode
    set errflag [catch { eval waterwire_core $args } errMsg]
    set savedInfo $errorInfo
    set savedCode $errorCode
    if $errflag { error $errMsg $savedInfo $savedCode }
}

proc WaterWire::waterwire_core {} {
    #claim variables
    variable readfromfile
    variable selectedmol
    variable psffile
    variable pdbfile
    variable firstframe
    variable lastframe
    variable stepframe
    variable allselstr
    variable startselstr
    variable endselstr
    variable hbonddiscutoff
    variable hbondanglecutoff
    variable searchtype

    variable molid
    variable w

    switch $searchtype {
	0 {
	    $w.output.results config -columns {1 "Frame" 1 "Connectivity" 1 "Length\n(number of bonds)"}
	}
	1 {
	    $w.output.results config -columns {1 "Frame" 1 "Connectivity" 1 "Length\n(angstrom)"}
	}
    }

    if {!$readfromfile} {
	set molid [lindex $selectedmol 0]
    } else {
	set molid [mol new $psffile]
    }
    #core
    variable allwaterOSel
    variable allnowaterSel
    variable allSel
    variable startSel
    variable endSel
    set allwaterOSel [atomselect $molid "name OH2 and (($allselstr) or ($startselstr) or ($endselstr))"]
    set allnowaterSel [atomselect $molid "not water and (($allselstr) or ($startselstr) or ($endselstr))"]
    set allSel [atomselect $molid "($allselstr) or ($startselstr) or ($endselstr)"]
    set startSel [atomselect $molid "(($startselstr))"]
    set endSel [atomselect $molid "(($endselstr))"] 
    $allwaterOSel global
    $allnowaterSel global
    $allSel global
    $startSel global
    $endSel global

    variable results [list]
    variable totnumframes 
    variable curnum 0
    if {!$readfromfile} {
	set numframes [molinfo $molid get numframes]
	set first [expr $firstframe%$numframes]
	set last [expr $lastframe%$numframes]
	set totnumframes [expr ($last-$first)/$stepframe+1]
	for {set frame $first} {$frame<=$last} {incr frame $stepframe} {
	    WaterWire::isWaterWired $frame
	}
    } else {
	set fileext [file extension $pdbfile]
	if {$fileext==".pdb"} {
	    set totnumframes 1
	}
	if {$fileext==".dcd"} {
	    set location ""
	    if {[catch {glob $env(VMDDIR)/plugins/[vmdinfo arch]/bin/catdcd*} location]==0} {
		set totnumframes [lindex [exec ${location}/catdcd $pdbfile] 8]
	    }
	}
	bigdcd WaterWire::isWaterWired $pdbfile
    }
}



   




