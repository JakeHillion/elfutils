#! /bin/sh
# Copyright (C) 2011, 2013 Red Hat, Inc.
# This file is part of elfutils.
#
# This file is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# elfutils is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

. $srcdir/test-subr.sh

if test -n "$ELFUTILS_MEMORY_SANITIZER"; then
  echo "binaries linked with memory sanitizer are too big"
  exit 77
fi

testfiles hello_i386.ko hello_x86_64.ko hello_ppc64.ko hello_s390.ko \
	hello_aarch64.ko hello_m68k.ko hello_riscv64.ko hello_csky.ko \
	hello_arc_hs4.ko

tempfiles readelf.out readelf.out1 readelf.out2
tempfiles out.stripped1 out.debug1 out.stripped2 out.debug2

status=0
runtest() {
  infile=$1
  is_ET_REL=$2
  outfile1=out.stripped1
  debugfile1=out.debug1
  outfile2=out.stripped2
  debugfile2=out.debug2

  echo "runtest $infile"

  rm -f $outfile1 $debugfile1 $outfile2 $debugfile2

  testrun ${abs_top_builddir}/src/strip -o $outfile1 -f $debugfile1 $infile ||
  { echo "*** failure strip $infile"; status=1; }

  testrun ${abs_top_builddir}/src/strip --reloc-debug-sections -o $outfile2 \
	-f $debugfile2 $infile ||
  { echo "*** failure strip --reloc-debug-sections $infile"; status=1; }

  # shouldn't make any difference for stripped files.
  testrun ${abs_top_builddir}/src/readelf -a $outfile1 > readelf.out ||
  { echo "*** failure readelf -a outfile1 $infile"; status=1; }

  testrun_compare ${abs_top_builddir}/src/readelf -a $outfile2 < readelf.out ||
  { echo "*** failure compare stripped files $infile"; status=1; }

  # debug files however should be smaller, when ET_REL.
  SIZE1=$(stat -c%s $debugfile1)
  SIZE2=$(stat -c%s $debugfile2)
  test \( \( $is_ET_REL -eq 1 \) -a \( $SIZE1 -gt $SIZE2 \) \) \
	-o \( \( $is_ET_REL -eq 0 \) -a \( $SIZE1 -eq $SIZE2 \) \) ||
  { echo "*** failure --reloc-debug-sections not smaller $infile"; status=1; }

  # Strip of DWARF section lines, offset will not match.
  # Everything else should match.
  testrun ${abs_top_builddir}/src/readelf -w $debugfile1 \
	| grep -v ^DWARF\ section > readelf.out1 ||
  { echo "*** failure readelf -w debugfile1 $infile"; status=1; }

  testrun ${abs_top_builddir}/src/readelf -w $debugfile2 \
	| grep -v ^DWARF\ section > readelf.out2 ||
  { echo "*** failure readelf -w debugfile2 $infile"; status=1; }

  testrun_compare cat readelf.out1 < readelf.out2 ||
  { echo "*** failure readelf -w compare $infile"; status=1; }

  testrun ${abs_top_builddir}/src/strip --reloc-debug-sections-only \
	  $debugfile1 ||
  { echo "*** failure strip --reloc-debug-sections-only $debugfile1"; \
    status=1; }

  cmp $debugfile1 $debugfile2 ||
  { echo "*** failure --reloc-debug-sections[-only] $debugfile1 $debugfile2"; \
    status=1; }
}

# Most simple hello world kernel module for various architectures.
# Make sure that it contains debuginfo with CONFIG_DEBUG_INFO=y.
# ::::::::::::::
# Makefile
# ::::::::::::::
# obj-m	:= hello.o
# hello-y := init.o exit.o
# 
# all:
# 	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) \
#		CONFIG_DEBUG_INFO=y modules
# ::::::::::::::
# init.c
# ::::::::::::::
# #include <linux/kernel.h>
# #include <linux/module.h>
# 
# int init_module(void)
# {
#   printk(KERN_INFO "Hello, world!\n");
#   return 0;
# }
# ::::::::::::::
# exit.c
# ::::::::::::::
# #include <linux/kernel.h>
# #include <linux/module.h>
# 
# void cleanup_module()
# {
#   printk(KERN_INFO "Goodbye, World!\n");
# }
runtest hello_i386.ko 1
runtest hello_x86_64.ko 1
runtest hello_ppc64.ko 1
runtest hello_s390.ko 1
runtest hello_aarch64.ko 1
runtest hello_m68k.ko 1
runtest hello_riscv64.ko 1
runtest hello_csky.ko 1
runtest hello_arc_hs4.ko 1

# self test, shouldn't impact non-ET_REL files at all.
runtest ${abs_top_builddir}/src/strip 0
runtest ${abs_top_builddir}/src/strip.o 1

# Copy ET_REL file for self-test and make sure to run with/without
# elf section compression.
tempfiles strip-uncompressed.o strip-compressed.o
testrun ${abs_top_builddir}/src/elfcompress -o strip-uncompressed.o -t none \
  ${abs_top_builddir}/src/strip.o
testrun ${abs_top_builddir}/src/elfcompress -o strip-compressed.o -t zlib \
  --force ${abs_top_builddir}/src/strip.o

runtest strip-uncompressed.o 1
runtest strip-compressed.o 1

# See run-readelf-zdebug-rel.sh
testfiles testfile-debug-rel-ppc64.o
runtest testfile-debug-rel-ppc64.o 1

testfiles testfile-debug-rel-ppc64-z.o
runtest testfile-debug-rel-ppc64-z.o 1

testfiles testfile-debug-rel-ppc64-g.o
runtest testfile-debug-rel-ppc64-g.o 1

exit $status
