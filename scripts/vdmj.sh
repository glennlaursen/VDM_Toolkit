#!/bin/bash
#####################################################################################
# Execute VDMJ jar with various options
#
# Version adapted from https://github.com/nickbattle/vdmj/blob/master/vdmj/src/main/scripts/vdmsl.sh
#####################################################################################

# Change these to flip VDMJ version
MVERSION="4.5.0-SNAPSHOT"  #$VDMJ_VERSION
PVERSION="4.5.0-P-SNAPSHOT"

VTVERSION="1.2.0-SNAPSHOT" #VDMJTK_VERSION
STVERSION="4.3.5-SNAPSHOT"
ANTLRVERSION="3.5.3"

# Preferred VDMJ options
VDMJ_OPTS="-strict"

# The Maven repository directory containing VDMJ and VDM_Toolkit jars
VDMJMAVENREPO=~/.m2/repository/dk/au/ece/vdmj
VDMTOOLKITMAVENREPO=~/.m2/repository/vdmtoolkit
STMAVENREPO=~/.m2/repository/org/antlr

# Location of the vdmj.properties file, if any. Override with -D.
PROPDIR="$HOME/lib"

# Details for 64-bit Java
JAVA64="/usr/bin/java"
VM_OPTS="-Xmx3000m -Xss1m -Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote -Dmax.errors=1000 -Dvdmj.diag.max_stack=10"

function help()
{
    echo "Usage: $0 [--help|-?] [-P] [-A] <VM and VDMJ options>"
    echo "-P use high precision VDMJ"
    echo "-A use annotation libraries and options"
    echo "Default VM options are $JAVA64 $VM_OPTS"
    exit 0
}

function check()
{
    if [ ! -r "$1" ]
    then
	echo "Cannot read $1"
	exit 1
    fi
}

function latest()
{
	# Warn if a later version is available in Maven
	BASEVER=$(echo $1 | sed -e "s/\(^[0-9]*\.[0-9]*\.[0-9]*\(-P\)\{0,1\}\).*$/\1/")
	
	if [ -e $MAVENREPO/vdmj/$BASEVER ]
	then
		LATEST=$BASEVER
	elif [[ $1 == *-P* ]]
	then
		LATEST=$(ls $MAVENREPO/vdmj | grep "^[0-9]*\.[0-9]*\.[0-9]*" | grep -- "-P" | tail -1)
	else
		LATEST=$(ls $MAVENREPO/vdmj | grep "^[0-9]*\.[0-9]*\.[0-9]*" | grep -v -- "-P" | tail -1)
	fi
	
	if [ "$1" != "$LATEST" ]
	then
	    echo "WARNING: Latest VDMJ version is $LATEST, not $1"
	fi
}

# Just warn if a later version is available in Maven
LATEST=$(ls $VDMJMAVENREPO/vdmj | grep "^[0-9].[0-9].[0-9]" | tail -1)

if [ "$MVERSION" != "$LATEST" ]
then
    echo "WARNING: Latest VDMJ version is $LATEST, not $MVERSION"
fi

# Just warn if a later version is available in Maven
LATEST=$(ls $VDMTOOLKITMAVENREPO/vdm2isa | grep "^[0-9].[0-9].[0-9]" | tail -1)

if [ "$VTVERSION" != "$LATEST" ]
then
    echo "WARNING: Latest VDM TOOLKIT version is $LATEST, not $VTVERSION"
fi

# Chosen version defaults to "master"
VERSION=$MVERSION

if [ $# -eq 0 ]
then help
fi

# Process non-VDMJ options
while [ $# -gt 0 ]
do
    case "$1" in
	--help|-\?)
	    help
	    ;;
	-A)
	    ANNOTATIONS_VERSION=$VERSION
	    ;;
	-P)
	    VERSION=$PVERSION
	    ;;
	-D*|-X*)
	    VM_OPTS="$VM_OPTS $1"
	    ;;
	*)
	    VDMJ_OPTS="$VDMJ_OPTS $1"
    esac
    shift
done

# Locate the jars; append VDMToolkit jars accordingly, but with MVERSION (not -P)!
VDMJ_JAR=$VDMJMAVENREPO/vdmj/${VERSION}/vdmj-${VERSION}.jar
STDLIB_JAR=$VDMJMAVENREPO/stdlib/${VERSION}/stdlib-${VERSION}.jar
PLUGINS_JAR=$VDMJMAVENREPO/cmd-plugins/${VERSION}/cmd-plugins-${VERSION}.jar
VDMTOOLKIT_LIB_JAR=$VDMTOOLKITMAVENREPO/vdmlib/${VTVERSION}/vdmlib-${VTVERSION}.jar
VDMTOOLKIT_PLUGIN_JAR=$VDMTOOLKITMAVENREPO/vdm2isa/${VTVERSION}/vdm2isa-${VTVERSION}.jar
ST_JAR=$STMAVENREPO/ST4/${STVERSION}/ST4-${STVERSION}.jar
ANTLR_JAR=$STMAVENREPO/antlr-runtime/${ANTLRVERSION}/antlr-runtime-${ANTLRVERSION}.jar

check "$VDMJ_JAR"
check "$STDLIB_JAR"
check "$PLUGINS_JAR"
check "$VDMTOOLKIT_LIB_JAR"
check "$VDMTOOLKIT_PLUGIN_JAR"
check "$ST_JAR"
check "$ANTLR_JAR"
CLASSPATH="$VDMJ_JAR:$PLUGINS_JAR:$VDMTOOLKIT_PLUGIN_JAR:$STDLIB_JAR:$VDMTOOLKIT_LIB_JAR:$ST_JAR:$ANTLR_JAR"
#MAIN="com.fujitsu.vdmj.VDMJ"
MAIN="com.fujitsu.vdmj.plugins.VDMJ"

#always keep them on for now 
#if [ $ANNOTATIONS_VERSION ]
#then
    ANNOTATIONS_JAR=$VDMJMAVENREPO/annotations/${VERSION}/annotations-${VERSION}.jar
    check "$ANNOTATIONS_JAR"
    # Remove Annotations2 to allow for right "Witness" to be picked
    #ANNOTATIONS2_JAR=$VDMJMAVENREPO/annotations2/${VERSION}/annotations2-${VERSION}.jar
    #check "$ANNOTATIONS2_JAR"
    ANNOTATIONS_VDM_TOOLKIT_JAR=$VDMTOOLKITMAVENREPO/annotationsVDMToolkit/${VTVERSION}/annotationsVDMToolkit-${VTVERSION}.jar
    check "$ANNOTATIONS_VDM_TOOLKIT_JAR"
    VDMJ_OPTS="$VDMJ_OPTS -annotations -strict"
    VM_OPTS="$VM_OPTS -Dvdmj.annotations.debug=true -Dvdmj.parser.merge_comments=true -Dvdmj.plugins=plugins.analyses.IsabellePlugin"
    CLASSPATH="$CLASSPATH:$ANNOTATIONS_JAR:$ANNOTATIONS_VDM_TOOLKIT_JAR"
    #$ANNOTATIONS2_JAR:
#fi

# The dialect for vdm2isa is always VDMSL for now; is based on $0, so hard-link this file as vdmsl, vdmpp and vdmrt.
#DIALECT=$(basename $0)
DIALECT=vdmsl

#echo "\"$JAVA64\" $VM_OPTS -cp $CLASSPATH $MAIN -$DIALECT $VDMJ_OPTS \"$@\""

# Check whether RLWRAP exists calling without it if not
if which rlwrap >/dev/null 2>&1
then
	# Keep rlwrap output in a separate folder
	export RLWRAP_HOME=~/.vdmj
	exec rlwrap "$JAVA64" $VM_OPTS -cp $CLASSPATH $MAIN -$DIALECT $VDMJ_OPTS "$@"
else
	exec "$JAVA64" $VM_OPTS -cp $CLASSPATH $MAIN -$DIALECT $VDMJ_OPTS "$@"
fi