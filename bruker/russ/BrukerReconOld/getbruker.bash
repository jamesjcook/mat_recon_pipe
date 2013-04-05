#!/bin/bash
#get study folder from bruker 7t
# input arguments 
# example ./getbruker.bash 20110603-2 BrainEPI 1-12
# brukerid may be run number in the future, this needs to be checked if we can enter in new scans on a previous bruker ID
# brukerstudyname, NOTE: this is the  bruker brukerstudyname, if you make a type on the bruker make sure to replicate it here.
# brukerscannum , a number.... if blank or 0 will get entire study


brukerid=$1 # currently using specid, may change in fusture
brukerstudyname=$2
brukerscannum=$3


destdir=/Users/rmd22/Documents/MATLAB/11.rd.02/frombruker
brukeruser=nmrsu
brukerserver=nemo
paravisionversion=PV5.1


###
# clean brukerid here
###
#assume good for now


path=/opt/${paravisionversion}/data/${brukeruser}/nmr/ 
# cant have bruker id in path as it will be eaten up, will have to filter results by bruker id ${brukerid}
cmd='ssh ${brukeruser}@${brukerserver} find ${path} -iname "subject" '
echo $cmd
filelist=`eval $cmd`

for file in $filelist
do
    if [ `echo $file | grep -c ${brukerid}` -ge 1 ] 
    then
	
	findstudycommand="ssh ${brukeruser}@${brukerserver} grep -C 1 '\$SUBJECT_study_name' $file  | tail -n 1"
	echo "Checking $file using command $findstudycommand"
	foundstudyname=`$findstudycommand`

	echo "Found studyname $foundstudyname"
	if [ "${foundstudyname}" == "<${brukerstudyname}>" ] 
	then
	    #echo "Study found in $file"
	    if [ ! -d ${destdir} ] 
	    then
		mkdir ${destdir}
	    fi
	    if [ ! -d ${destdir}/${brukerid}_${brukerstudyname} ] 
	    then
		mkdir ${destdir}/${brukerid}_${brukerstudyname}/
	    fi
	    echo "Placing files in ${destdir}/${brukerid}_${brukerstudyname}"
	    # add previously existing file checks here, perhaps transfer anyway and add a diff to make sure they're the same.
	    scp -q ${brukeruser}@${brukerserver}:$file ${destdir}/${brukerid}_${brukerstudyname}
	    if [ `echo $brukerscannum | grep -c ","` -ge 1 ]
	    then
		#handle coma list of scannumbers
		exit "dont do that"
		    # add check for already existing here, do not want to recopy as it will just keep adding to directory
		scp -qr ${brukeruser}@${brukerserver}:${file%/*}/${brukerscannum} ${destdir}/${brukerid}_${brukerstudyname}/${brukerscannum}
	    elif [ `echo $brukerscannum | grep -c "-"` -ge 1 ]
	    then
		# handle dash of scan nums
		startnum=`echo $brukerscannum| cut -d "-" -f1 `
		stopnum=`echo $brukerscannum| cut -d "-" -f2`
		for((i=$startnum;i<=$stopnum;i++))
		do 
		    brukerscannum=$i;
		    # add check for already existing here, do not want to recopy as it will just keep adding to directory
		    scp -qr ${brukeruser}@${brukerserver}:${file%/*}/${brukerscannum} ${destdir}/${brukerid}_${brukerstudyname}/${brukerscannum}
		done
	    else
		    # add check for already existing here, do not want to recopy as it will just keep adding to directory
		scp -qr ${brukeruser}@${brukerserver}:${file%/*}/${brukerscannum} ${destdir}/${brukerid}_${brukerstudyname}/${brukerscannum}
	    fi
	else
	    echo "DID NOT FIND STUDY ${brukerstudyname}"
	fi
    else
	#echo "Ignoring file $file"
	echo -n ""
    fi
done
