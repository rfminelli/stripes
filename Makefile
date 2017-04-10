#
# Makefile,v 1.6 2001/05/29 19:39:27 kim Exp
#
# Copyright (c) 2001 Global Wire Oy.
# All rights reserved.
#
# This code is derived from software contributed to Global Wire Oy
# by Kimmo Suominen.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Global Wire Oy nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY GLOBAL WIRE OY AND CONTRIBUTORS ``AS IS''
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL GLOBAL WIRE OY OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE.
#

SHELL		= /bin/sh

PROG		= lg

CONFIGFILE	= /etc/httpd/lg.conf

RM		= /bin/rm -f
MV		= /bin/mv -f
CP		= /bin/cp
INSTALL		= /usr/bin/install

BINMODE		= -m 0555
MANMODE		= -m 0444

DEST		= /usr/pkg
BINDIR		= $(DEST)/libexec/cgi-bin
MANDIR		= $(DEST)/man/man$(MANEXT)
MANEXT		= 8

PERL		= $(DEST)/bin/perl

#
# STOP HERE
#

PNAME		= stripes
PVERS		= 2.1
PDATE		= 29 May 2001
CVSROOT		= cvs.gw.com:/src/pub
NODISTFILES	= index.list

all: $(PROG) $(PROG).$(MANEXT)

.SUFFIXES: .man .$(MANEXT) .pl .list .html

.pl .man.$(MANEXT) .list.html:
	sed \
	    -e "s|@PERL@|$(PERL)|" \
	    -e "s|@PVERS@|$(PVERS)|" \
	    -e "s|@PDATE@|$(PDATE)|" \
	    -e "s|@PCONF@|$(CONFIGFILE)|" \
	    < $< > $@
	@(  set -x; \
	    case $< in \
	    *.pl) chmod +x $@;; \
	    esac; \
	)

install: all
	-$(INSTALL) -d $(BINDIR)
	$(INSTALL) $(BINMODE) $(PROG) $(BINDIR)
	-$(INSTALL) -d $(MANDIR)
	$(INSTALL) $(MANMODE) $(PROG).$(MANEXT) $(MANDIR)

clean:
	-@$(RM) -rf dist
	$(RM) $(PROG) $(PROG).$(MANEXT) README index.html *.bak *~

README: index.html
	lynx -dump -nolist -reload $? \
	| expand | sed -e 's/^  *$$//' | cat -s \
	> $@

tag:
	@(  UP=`echo $(PNAME) | tr '[:lower:]' '[:upper:]'`; \
	    TAG=`echo $${UP}$(PVERS) | sed -e s/\\\\./_/g`; \
	    set -x; \
	    cvs tag $(FORCETAG) $${TAG}; \
	)

tar:
	-@$(RM) -rf dist
	@(  UP=`echo $(PNAME) | tr '[:lower:]' '[:upper:]'`; \
	    TAG=`echo $${UP}$(PVERS) | sed -e s/\\\\./_/g`; \
	    set -x; \
	    mkdir dist; \
	    cd dist; \
	    cvs -d $(CVSROOT) export -kv -r$$TAG $(PNAME); \
	    (	cd $(PNAME) && \
		make README && \
		make clean && \
		rm -f $(NODISTFILES); \
	    ); \
	    mv $(PNAME) $(PNAME)-$(PVERS); \
	    tar -czf ../$(PNAME)-$(PVERS).tar.gz $(PNAME)-$(PVERS); \
	)
	-@$(RM) -rf dist
	@ls -l $(PNAME)-$(PVERS).tar.gz
