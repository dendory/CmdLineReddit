#!/usr/bin/perl
use XML::Feed;
use HTML::FormatText::WithLinks;
use HTML::LinkExtor;
use JSON::Parse 'parse_json';
use HTTP::Cookies;
use LWP::UserAgent;
use utf8;
no warnings 'utf8';

$COOKIEFILE = "reddit.cache";
if($ENV{'REDDIT_CACHE'}) { $COOKIEFILE = $ENV{'REDDIT_CACHE'}; }
$MAXITEMS = $ENV{'REDDIT_COUNT'};
if($MAXITEMS < 1 || $MAXITEMS > 100) { $MAXITEMS = 10; }

if($ENV{'REDDIT_BROWSER'}) { $BROWSER = $ENV{'REDDIT_BROWSER'}; }
else { $BROWSER = "firefox"; }

if($#ARGV == -1) # front page
{ 
	$feed = XML::Feed->parse(URI->new("http://www.reddit.com/.rss?limit=$MAXITEMS"), "RSS") or do { if($ENV{'REDDIT_DEBUG'}) { print "Debug: " . XML::Feed->errstr . "\n"; } die("Error: Could not connect to reddit.com\n"); };
	$i = 1;
	foreach $ni ($feed->entries)
	{
		print "$i: ", $ni->title, " [" , $ni->category, "]\n";
		last if($i++ == $MAXITEMS);
	}
}
elsif($ARGV[0] eq "-r" && $#ARGV == 1) # subreddit
{ 
	$feed = XML::Feed->parse(URI->new("http://www.reddit.com/r/$ARGV[1]/.rss?limit=$MAXITEMS"), "RSS") or do { if($ENV{'REDDIT_DEBUG'}) { print "Debug: " . XML::Feed->errstr . "\n"; } die("Error: Could not connect to reddit.com\n"); };
	$i = 1;
	foreach $ni ($feed->entries)
	{
		print "$i: ", $ni->title, "\n";
		last if($i++ == $MAXITEMS);
	}
}
elsif($ARGV[0] eq "-u" && $#ARGV == 1) # user posts
{ 
	$feed = XML::Feed->parse(URI->new("http://www.reddit.com/user/$ARGV[1]/.rss?limit=$MAXITEMS"), "RSS") or do { if($ENV{'REDDIT_DEBUG'}) { print "Debug: " . XML::Feed->errstr . "\n"; } die("Error: Could not connect to reddit.com\n"); };
	$i = 1;
	foreach $ni ($feed->entries)
	{
		print "$i: ", $ni->title, "\n\n";
		$parsed = HTML::FormatText::WithLinks->new(before_link=>'', after_link=>'', footnote=>'');
		print $parsed->parse($ni->content->body);
		last if($i++ == $MAXITEMS);
	}
}
elsif($ARGV[0] eq "-s" && $#ARGV == 1) # search
{ 
	$feed = XML::Feed->parse(URI->new("http://www.reddit.com/search/.rss?q=$ARGV[1]&limit=$MAXITEMS"), "RSS") or do { if($ENV{'REDDIT_DEBUG'}) { print "Debug: " . XML::Feed->errstr . "\n"; } die("Error: Could not connect to reddit.com\n"); };
	$i = 1;
	foreach $ni ($feed->entries)
	{
		print "$i: ", $ni->title, " [" . $ni->category . "]\n\n";
		$parsed = HTML::FormatText::WithLinks->new(before_link=>'', after_link=>'', footnote=>'');
		print $parsed->parse($ni->content->body);
		last if($i++ == $MAXITEMS);
	}
}
elsif($ARGV[0] eq "-s" && $ARGV[2] > 0) # search item
{ 
	$feed = XML::Feed->parse(URI->new("http://www.reddit.com/search/.rss?q=$ARGV[1]&limit=$MAXITEMS"), "RSS") or do { if($ENV{'REDDIT_DEBUG'}) { print "Debug: " . XML::Feed->errstr . "\n"; } die("Error: Could not connect to reddit.com\n"); };
	$i = 1;
	foreach $ni ($feed->entries)
	{
		if($i == $ARGV[2])
		{
			$CSRC = $ni->link . ".rss?limit=$MAXITEMS";
			$cfeed = XML::Feed->parse(URI->new($CSRC), "RSS") or do { if($ENV{'REDDIT_DEBUG'}) { print "Debug: " . XML::Feed->errstr . "\n"; } die("Error: Could not connect to reddit.com\n"); };
			$ci = 0;
			foreach $cni ($cfeed->entries)
			{
				if($ci == 0)
				{
					print "Title: ", $cni->title, "\n";
					print "Link: ", $cni->link, "\n\n---\n";
				}
				else
				{
					print "$ci: ";
					$parsed = HTML::FormatText::WithLinks->new();
					print $parsed->parse($cni->content->body), "\n";
					@name = split(/ /, $cni->title);
					print "by: ", $name[0], "\n\n";
				}
				last if($ci++ == $MAXITEMS);
			}
		}
		last if($i++ == $MAXITEMS);
	}
}
elsif(($ARGV[0] > 0 && $ARGV[0] < ($MAXITEMS+1) && ($#ARGV == 0 || $ARGV[1] eq "-url")) || ($ARGV[0] eq "-r" && ($#ARGV == 2 || $ARGV[3] eq "-url") && ($ARGV[2] > 0 && $ARGV[2] < ($MAXITEMS+1)))) # news item
{
	if ($ARGV[0] ne "-r")
	{
		$SRC = "http://www.reddit.com/.rss?limit=$MAXITEMS";
		print "Fetching front page item $ARGV[0]...\n";
		$fi = $ARGV[0];
	}
	else
	{
		$SRC = "http://www.reddit.com/r/$ARGV[1]/.rss?limit=$MAXITEMS";
		print "Fetching subreddit $ARGV[1] item $ARGV[2]...\n";
		$fi = $ARGV[2];
	}
	$feed = XML::Feed->parse(URI->new($SRC), "RSS") or do { if($ENV{'REDDIT_DEBUG'}) { print "Debug: " . XML::Feed->errstr . "\n"; } die("Error: Could not connect to reddit.com\n"); };
	$i = 1;
	foreach $ni ($feed->entries)
	{
		if($i == $fi)
		{
			my $pos = rindex($ni->link ,'/', rindex($ni->link, '/', rindex($ni->link, '/')-1)-1)+1;
			print "\nTitle: ", $ni->title;
			if($ni->category) { print " [" . $ni->category . "]"; }
			print " [PID: " . substr($ni->link, $pos, index($ni->link, '/')+1)  . "]\n";
			print "Time: ", $ni->issued, "\n";
			print "Content:\n\n";
			$parsed = HTML::FormatText::WithLinks->new(before_link=>'', after_link=>'', footnote=>'');
			print $parsed->parse($ni->content->body);
			$parsedlinks = new HTML::LinkExtor();
			$parsedlinks->parse($ni->content->body);
			print "\nSources: ";
 			for $ln ($parsedlinks->links)
			{
    				@ln = @$ln;
    				$tag = shift @ln;
				while (@ln)
				{
      					shift @ln;
	      				$url = shift @ln;
      					if(index($url, "reddit") < 0)
					{
						print $url, "\n" unless $seen{$url}++;
						if($ARGV[1] eq "-url" || $ARGV[3] eq "-url") { system($BROWSER, $url); }
					}
				}
  			}
		}
		$i++;
	}
}
elsif(($ARGV[0] > 0 && $ARGV[0] < ($MAXITEMS+1) && $ARGV[1] eq "-c") || ($ARGV[0] eq "-r" && $ARGV[3] eq "-c" && ($ARGV[2] > 0 && $ARGV[2] < ($MAXITEMS+1)))) # comments
{
	if($#ARGV == 1)
	{
		$SRC = "http://www.reddit.com/.rss?limit=$MAXITEMS";
		print "Fetching comments for front page item $ARGV[0]...\n";
		$fi = $ARGV[0];
	}
	else
	{
		$SRC = "http://www.reddit.com/r/$ARGV[1]/.rss?limit=$MAXITEMS";
		print "Fetching comments for subreddit $ARGV[1] item $ARGV[2]...\n";
		$fi = $ARGV[2];
	}
	$feed = XML::Feed->parse(URI->new($SRC), "RSS") or die XML::Feed->errstr;
	$i = 1;
	foreach $ni ($feed->entries)
	{
		if($i == $fi)
		{
			print "\n";
			$CSRC = $ni->link . ".rss?limit=$MAXITEMS";
			$cfeed = XML::Feed->parse(URI->new($CSRC), "RSS") or do { if($ENV{'REDDIT_DEBUG'}) { print "Debug: " . XML::Feed->errstr . "\n"; } die("Error: Could not connect to reddit.com\n"); };
			$ci = 0;
			foreach $cni ($cfeed->entries)
			{
				if($ci == 0)
				{
					print "Title: ", $cni->title, "\n";
					print "Link: ", $cni->link, "\n\n---\n";
					if($ARGV[2] eq "-url" || $ARGV[4] eq "-url") { system($BROWSER, $cni->link); }
				}
				else
				{
					$parsed = HTML::FormatText::WithLinks->new();
					print $ci . ":" . $parsed->parse($cni->content->body);
					@name = split(/ /, $cni->title);
					print "   submitted by ", $name[0], " [CID: " . substr($cni->link, rindex($cni->link, '/')+1) . "]\n\n";
				}
				last if($ci++ == $MAXITEMS);
			}
		}
		$i++;
	}
}
elsif($ARGV[0] eq "-list" || $ARGV[0] eq "-l") # list subreddits
{			
	$feed = XML::Feed->parse(URI->new("http://www.reddit.com/reddits/.rss?limit=$MAXITEMS"), "RSS") or do { if($ENV{'REDDIT_DEBUG'}) { print "Debug: " . XML::Feed->errstr . "\n"; } die("Error: Could not connect to reddit.com\n"); };
	$i = 1;
	foreach $ni ($feed->entries)
	{
		@sub = split(/\//, $ni->link);
		printf("%-20s", $sub[2]);
		last if($i++ == $MAXITEMS0);
	}
}
elsif($ARGV[0] eq "-login" && $#ARGV == 2)
{
	open($TMPC, ">$COOKIEFILE") or die("Error: Could not access cache file $COOKIEFILE\n");
	close($TMPC);
	unlink($COOKIEFILE);
	my $server_endpoint;
	if($ENV{'REDDIT_NOSSL'}) { $server_endpoint = "http://www.reddit.com/api/login"; }
	else { $server_endpoint = "https://www.reddit.com/api/login"; }
	$cookie_jar = HTTP::Cookies->new(file => $COOKIEFILE, autosave => 1, ignore_discard => 1);
	my $ua = LWP::UserAgent->new(cookie_jar => $cookie_jar);
	$ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00); 
	my $req = HTTP::Request->new(POST => $server_endpoint) or die("Error: Could not open socket.\n");
	$req->header('content-type' => 'application/json');
	my %post;
	$post{'user'} = $ARGV[1];
	$post{'passwd'} = $ARGV[2];
	my $result = $ua->post($server_endpoint, \%post ) or die("Error: Could not connect to reddit.com\n");
	if($result->is_success)
	{
		if($ENV{'REDDIT_DEBUG'}) { print "Debug: " . $result->decoded_content . "\n"; }
		if(index($result->decoded_content, "WRONG_PASSWORD") != -1) { die("Error: Wrong username or password.\n"); }
		elsif(index($result->decoded_content, "RATELIMIT") != -1) { die("Error: You are trying that too often.\n"); }
		elsif(index($result->decoded_content, "error") != -1) { die("Error: Unknown error.\n"); }
		else { print "Logged in successfully.\n"; }
	}
	else
	{
		die("Error: " . $result->status_line . "\n");
	}
}
elsif(($ARGV[0] eq "-reply" || $ARGV[0] eq "-post") && $#ARGV == 2)
{
	my $modhash;
	open($TMPC, "$COOKIEFILE") or die("Error: Could not access cache file $COOKIEFILE\n");
	close($TMPC);
	my $server_endpoint;
	if($ENV{'REDDIT_NOSSL'}) { $server_endpoint = "http://www.reddit.com/api/me.json"; }
	else { $server_endpoint = "https://www.reddit.com/api/me.json"; }
	$cookie_jar = HTTP::Cookies->new(file => $COOKIEFILE, autosave => 1, ignore_discard => 1);
	my $ua = LWP::UserAgent->new(cookie_jar => $cookie_jar);
	$ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00); 
	my $req = HTTP::Request->new(GET => $server_endpoint) or die("Error: Could not open socket.\n");
	$req->header('content-type' => 'application/json');
	my $result = $ua->request($req) or die("Error: Could not connect to reddit.com\n");
	if($result->is_success)
	{
		if($ENV{'REDDIT_DEBUG'}) { print "Debug: " . $result->decoded_content . "\n"; }
		if(index($result->decoded_content, "RATELIMIT") != -1) { die("Error: You are trying that too often.\n"); }
		my $parsed = parse_json($result->decoded_content);
		$modhash = $parsed->{'data'}{'modhash'};
		if(!$modhash) { die("Error: Could not establish session information.\n"); }
	}
	else
	{
		die("Error: " . $result->status_line . "\n");
	}
	if($ENV{'REDDIT_NOSSL'}) { $server_endpoint = "http://www.reddit.com/api/comment"; }
	else { $server_endpoint = "https://www.reddit.com/api/comment"; }
	$cookie_jar = HTTP::Cookies->new(file => $COOKIEFILE, autosave => 1, ignore_discard => 1);
	my $ua = LWP::UserAgent->new(cookie_jar => $cookie_jar);
	$ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00); 
	my $req = HTTP::Request->new(POST => $server_endpoint) or die("Error: Could not open socket.\n");
	$req->header('content-type' => 'application/json');
	my %post;
	if($ARGV[0] eq "-reply") { $post{'thing_id'} = "t1_" . $ARGV[1]; }
	else { $post{'thing_id'} = "t3_" . $ARGV[1]; }
	$post{'text'} = $ARGV[2];
	$post{'api_type'} = "json";
	$post{'uh'} = $modhash;
	my $result = $ua->post($server_endpoint, \%post ) or die("Error: Could not connect to reddit.com\n");
	if($result->is_success)
	{
		if($ENV{'REDDIT_DEBUG'}) { print "Debug: " . $result->decoded_content . "\n"; }
		if($ARGV[0] eq "-reply") { print "Reply sent.\n"; }
		else { print "Post sent.\n"; }
	}
	else
	{
		die("Error: " . $result->status_line . "\n");
	}
}
else # usage
{
	print "Simple unofficial command line Reddit app v1.3 by Patrick Lambert - http://dendory.net\n\nUsage:\n";
 	printf("%-*s%-*s", (length($0)+36), "$0 [1..$MAXITEMS] [-c] [-url]", 0, "Front page news items, thread or comments\n");
	printf("%-*s%-*s", (length($0)+36), "$0 -r <subreddit> [1..$MAXITEMS] [-c] [-url]", 0, "Subreddit news items, thread or comments\n");
	printf("%-*s%-*s", (length($0)+36), "$0 -s <keyword> [1..$MAXITEMS]", 0, "Display threads related to a keyword\n");
	printf("%-*s%-*s", (length($0)+36), "$0 -u <user>", 0, "Display posts from a user\n");
	printf("%-*s%-*s", (length($0)+36), "$0 -list", 0, "List trending subreddits\n");
	printf("%-*s%-*s", (length($0)+36), "$0 -login <user> <passwd>", 0, "Login, required to post a comment or reply\n");
	printf("%-*s%-*s", (length($0)+36), "$0 -post <pid> <comment>", 0, "Post a comment to an item\n");
	printf("%-*s%-*s", (length($0)+36), "$0 -reply <cid> <comment>", 0, "Reply to an existing comment\n");
	print "\nAdvanced tip: <subreddit> will show hot topics by default. You can also use <subreddit/new>, <subreddit/controversial> or <subreddit/rising>.\n";
	print "\nSettings: Set environment variable REDDIT_COUNT between 1 and 100 to change the number of items returned. Default is 10. Set REDDIT_BROWSER with the full path to your browser for '-url' flag. Default is 'firefox'. Set REDDIT_NOSSL to avoid using https connections when logging in. Set REDDIT_CACHE to the file name to use for cache credentials. Default is 'reddit.cache'. Set REDDIT_DEBUG for debug messages.\n";
}