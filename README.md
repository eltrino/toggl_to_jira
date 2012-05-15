# Introduction

[JIRA](http://www.atlassian.com/software/jira) is a great tool to manage projects, but it's a lot of hassle to manually log time spent on tickets. 

[Toggl](http://www.toggl.com)  is a really good time tracking tool. 

This script aims to merge the good parts of these 2 tools together. It allows you to easily import time log from toggl to JIRA. I used it on JIRA 4.4.4.

Check [this blog post](http://b2.broom9.com/?p=10336) for more thoughts behind this tool.

# Setup

* Install the latest ruby 1.8.x. 1.9 is not supported because of jira4r gem.
* Install the latest rubygems.
* Install required gems `gem install activesupport json soap4r jira4r`
* Copy config.example.yml to config.yml, fill your own configuration vaues.

# Usage

Run the script `ruby toggl_to_jira.rb`

It will create a file "imported.yml" to store entries which are successfully pushed to JIRA, so they won't be imported into JIRA again. This list keeps 500 entry IDs at most.

By default this script fetches all entries logged on toggl today. The recommended way of using it is to run it at least once a day.

