#!/usr/pkg/bin/perl
#
# lg.pl,v 1.2 2001/05/29 17:27:24 kim Exp
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

use CGI qw/:standard/;
use Net::Telnet;


#
# Set this appropriately:
#

$lgconf = '@PCONF@';


#
# You can override or augment these in the config file:
#

$ORGNAME = 'Network';
$ORGADDR = 'nobody@nowhere.net';

%ROUTERS = (
    'localhost' => 'localhost:2605',
);
$DEFROUTER = 'localhost';

%QUERIES = (
    'access-list 112'     => 'show %q',
    'bgp'                 => 'show %p %q %a',
    'bgp dampened-paths'  => 'show %p %q %a',
    'bgp flap-statistics' => 'show %p %q %a',
    'bgp longer-prefixes' => 'show %p bgp %a longer-prefixes',
    'bgp regexp'          => 'show %p %q %r',
    'bgp summary'         => 'show %p %q',
    'environmental'       => 'show %q all',
    'mroute summary'      => 'show %p %q %a',
    'ping'                => '%q %a',
    'trace'               => '%q %a',
);
$DEFQUERY = 'bgp summary';

%PROTOCOLS = (
    'IPv4'   => 'ip',
    'IPv6'   => 'ipv6',
);
$DEFPROTOCOL = 'IPv4';


#
# Let's read your config:
#

if ( -r $lgconf ) {
    if ( ! require $lgconf ) {
	push(@results, "Funny, I don't seem to be able to load $lgconf.\n");
	push(@results, "Please check the configuration.\n");
	&print_results;
	exit;
    }
}


#
# There are no configuration options below.
#

%CHECKLISTS = (
    'protocol' => PROTOCOLS,
    'query'    => QUERIES,
    'router'   => ROUTERS,
);

# Empty query gets the form.
if (! param) {
    &print_query_form;
    exit;
}

# No errors yet.
$sawerr = 0;

# Make sure they chose things in today's menu.
for $i ('router', 'query', 'protocol') {
    if (! param($i)) {
	push(@results, "Please step back and select a $i.\n\n");
	$sawerr = 1;
    } elsif (!defined($CHECKLISTS{$i}{param($i)})) {
	push(@results, "Funny, I don't seem to know about ", param($i), ".\n");
	push(@results, "Please step back and select a $i from the menu.\n\n");
	$sawerr = 1;
    }
}

$q = param('query');
$query = $QUERIES{$q};

if ($query =~ m/%a/) {
    $addr = &check_addr(param('addr'));
    $query =~ s/%a/$addr/g;
}

if ($query =~ m/%r/) {
    $addr = &check_regexp(param('addr'));
    $query =~ s/%r/$addr/g;
}

$query =~ s/%p/$PROTOCOLS{param('protocol')}/g;
$query =~ s/%q/$q/g;

if (! $sawerr) {
    @results = &do_query($ROUTERS{param('router')}, $query);
}

&print_results;
exit;


#
# Check ip address validity:
#

sub check_addr {
    local $addr = shift(@_);
    local $ip = '';

    if ($addr) {
	if (param('protocol') eq 'IPv4'
	    && $addr =~ m!^\d+\.\d+\.\d+\.\d+(/\d+)?$!) {
	    $ip = $addr;
	} elsif (param('protocol') eq 'IPv6'
	    && $addr =~ m!^[:xdigit:]+[:[:xdigit:]]+(/\d+)?$!) {
	    $ip = $addr;
	} else {
	    push(@results, "Funny, I don't think $addr is a good ",
		param('protocol'), " address.\n");
	    push(@results, "Please step back and try again.\n\n");
	    $sawerr = 1;
	}
    } else {
	push(@results, "Please step back and input an address.\n\n");
	$sawerr = 1;
    }
    return $ip;
}


#
# Check regexp validity:
#

sub check_regexp {
    local $addr = shift(@_);
    local $regexp = '';

    if ($addr) {
	if ($addr =~ m![_^][0-9 ]+[_\$]!) {
	    $regexp = $addr;
	} elsif ($addr =~ m!^[0-9 ]+$!) {
	    $regexp = '_' . $addr . '_';
	} else {
	    push(@results, "Funny, I don't think $addr is a good regexp.\n");
	    push(@results, "Please step back and try again.\n\n");
	    $sawerr = 1;
	}
    } else {
	push(@results, "Please step back and input a regexp ");
	push(@results, "in the address field.\n\n");
	$sawerr = 1;
    }
    return $regexp;
}


#
# Query the router:
#

sub do_query
{
	local ($router,$cmd) = @_;
	local (@results);
	local ($auth, $host, $port);
	local ($user, $pass);

	if ($router =~ /\@/) {
	    ($auth, $router) = split(/\@/, $router);
	}

	if ($auth =~ /:/) {
	    ($user, $pass) = split(/:/, $auth);
	} else {
	    $pass = $auth;
	}

	if ($router =~ /:/) {
	    ($host, $port) = split(/:/, $router);
	} else {
	    $host = $router;
	    $port = 23;
	}

	$t = new Net::Telnet(
		Binmode => 1,
		Errmode => 'return',
		Port    => $port,
		Prompt  => '/[#>] *$/',
		Timeout => 10
	    );
	$t->open($host);
	($pre, $match) = $t->waitfor('/(ogin:|sername:|assword:|[#>]) *$/');
	if ($match =~ /(ogin:|sername:)/) {
	    $t->print($user);
	    ($pre, $match) = $t->waitfor('/(assword:|[#>]) *$/');
	}
	if ($match =~ /assword:/) {
	    $t->print($pass);
	    ($pre, $match) = $t->waitfor('/[#>] *$/');
	}
	@results = $t->cmd('terminal length 0');
	@results = $t->cmd($cmd);
	if (!@results) {
	    push(@results, $t->errmsg . "\n");
	} else {
	    unshift(@results, " > $cmd\n\n");
	    pop(@results);
	}
	$t->close;
	return @results;
}


#
# The query form:
#

sub print_query_form {
    print
	header('text/html'),
	start_html(-title => "$ORGNAME - Looking Glass"),
	font({-size => '+2'},strong("$ORGNAME - Looking Glass")),
	hr,
	start_form,
	table({-border => 0, -cellpadding => 0},
	    Tr({-valign => top},
		td(strong('Router:')),
		td(popup_menu(
		    'router',
		    [sort(keys(%ROUTERS))],
		    $DEFROUTER,
		    'true'
		))
	    ),
	    Tr({-valign => top}, td('&nbsp;')),
	    Tr({-valign => top},
		td(strong('Query:')),
		td(radio_group(
		    'query',
		    [sort(keys(%QUERIES))],
		    $DEFQUERY,
		    'true'
		))
	    ),
	    Tr({-valign => top}, td('&nbsp;')),
	    Tr({-valign => top},
		td(strong('Protocol:')),
		td(radio_group(
		    'protocol',
		    [sort(keys(%PROTOCOLS))],
		    $DEFPROTOCOL,
		    'true'
		))
	    ),
	    Tr({-valign => top}, td('&nbsp;')),
	    Tr({-valign => top},
		td(strong('Address:')),
		td(textfield('addr', '', 20, 20))
	    ),
	    Tr({-valign => top}, td('&nbsp;')),
	    Tr({-valign => top},
		td({-colspan => 2},
		    submit, '&nbsp;', reset, '&nbsp;', defaults
		)
	    )
	),
	end_form;
    &html_footer;
}


#
# The results page:
#

sub print_results {
    print
	header('text/html'),
	start_html(-title => "$ORGNAME - Looking Glass Results"),
	font({-size => '+2'},strong("$ORGNAME - Looking Glass Results")),
	hr,
	strong('Router: '), param('router'),
	pre(@results);
    &html_footer;
}


#
# Common footer for HTML output:
#

sub html_footer {
    #
    # Please don't remove the URL to the software home page.
    # It is difficult enough, as it is, to find source code
    # for looking glass implementations.
    #
    # Thanks,
    # + Kim
    #
    print
	'Please e-mail questions or comments to ',
	a({href => "mailto:$ORGADDR"}, $ORGADDR) . '.',
	hr,
	font({-size => '-2'},
	    a({href => 'http://www.gw.com/sw/stripes/'},
		'Stripes Looking Glass @PVERS@'),
	    '(@PDATE@) // Copyright (c) 2001 Global Wire Oy',
	    br
	),
	end_html;
}
