#!/bin/sh
#
# Acceptance test for XDD.
#
# Validate the retry flag with xddcp without the -a resume flag
#

#
# Source the test configuration environment
#
source ./test_config

# Perform pre-test 
echo "Beginning XDDCP Retry Test 2 . . ."
test_dir=$XDDTEST_SOURCE_MOUNT/retry2
rm -rf $test_dir
mkdir -p $test_dir
ssh $XDDTEST_E2E_DEST "rm -rf $XDDTEST_DEST_MOUNT/retry2"
ssh $XDDTEST_E2E_DEST "mkdir -p $XDDTEST_DEST_MOUNT/retry2"

source_file=$test_dir/file1
dest_file=$XDDTEST_DEST_MOUNT/retry2/file1

#
# This test requires the gethostip command
#
type -P gethostip &>/dev/null
hasIpTranslator=$?
if [ 0 -ne $hasIpTranslator ]; then
    echo "Acceptance XDDCP2: Retry Test 2 - Check: Skipped (gethostip missing)."
    exit 2
fi
 

#
# Create the source file
#
$XDDTEST_XDD_EXE -target $source_file -op write -reqsize 4096 -mbytes 8000 -qd 4 -datapattern random >/dev/null

#
# Start a long copy
#
export PATH=$(dirname $XDDTEST_XDD_EXE):/usr/bin:$PATH
scp $XDDTEST_XDD_EXE $XDDTEST_E2E_DEST:~/bin/xdd.Linux &>/dev/null
$XDDTEST_XDDCP_EXE -f -n 1 $source_file $XDDTEST_E2E_DEST:$dest_file &
pid=$!

#
# Kill the destination side
#
sleep 10
ssh $XDDTEST_E2E_DEST "killall xdd.Linux" &>/dev/null

#
# Let the retry complete
#
wait $pid
rc=$?

test_passes=0
if [ 0 -eq $rc ]; then

    #
    # Perform MD5sum check
    #
    test_passes=1
    srcHash=$(md5sum $source_file |cut -d ' ' -f 1)
    destHash=$(ssh $XDDTEST_E2E_DEST "md5sum $dest_file |cut -d ' ' -f 1")
    if [ "$srcHash" != "$destHash" ]; then
	test_passes=0
	echo "ERROR: Failure in retry2"
	echo "\tSource hash for $i: $srcHash"
	echo "\tDestination hash for $d: $destHash"
    fi
else
    echo "ERROR: XDDCP exited with: $rc"
fi

# Perform post-test cleanup
#rm -rf $test_dir

# Output test result
if [ "1" == "$test_passes" ]; then
  echo "Acceptance XDDCP2: Retry Test - Check: PASSED."
  exit 0
else
  echo "Acceptance XDDCP2: Retry Test - Check: FAILED."
  exit 1
fi
