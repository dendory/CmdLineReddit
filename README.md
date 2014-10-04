CmdLineReddit
=============

This is a simple unofficial command line Reddit reader in Perl. It reads RSS feeds from Reddit. A compiled binary for Windows and Linux is available from my site http://dendory.net/?d=53e56eeb

Usage
-----
Usage:
- reddit [1..10] [-c] [-url]                Front page news items, thread or comments
- reddit -r <subreddit> [1..10] [-c] [-url] Subreddit news items, thread or comments
- reddit -s <keyword> [1..10]               Display threads related to a keyword
- reddit -u <user>                          Display posts from a user
- reddit -list                              List trending subreddits

Advanced tip: <subreddit> will show hot topics by default. You can also use <subreddit/new>, <subreddit/controversial> or <subreddit/rising>.

Settings: Set environment variable REDDIT_COUNT between 1 and 100 to change the number of items returned. Default is 10. Set REDDIT_BROWSER with the full path to your browser for '-url' flag. Default is 'firefox'.
