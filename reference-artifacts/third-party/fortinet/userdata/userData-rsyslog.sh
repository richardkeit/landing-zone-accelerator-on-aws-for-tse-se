#!/bin/bash

yum update -y
yum install -y rsyslog amazon-cloudwatch-agent
chkconfig rsyslog on

cat << EOT > /etc/rsyslog.conf

# rsyslog configuration file
# note that most of this config file uses old-style format,
# because it is well-known AND quite suitable for simple cases
# like we have with the default config. For more advanced
# things, RainerScript configuration is suggested.

# For more information see /usr/share/doc/rsyslog-*/rsyslog_conf.html
# If you experience problems, see http://www.rsyslog.com/doc/troubleshoot.html

#### MODULES ####

module(load="imuxsock") # provides support for local system logging (e.g. via logger command)
module(load="imklog")   # provides kernel logging support (previously done by rklogd)
#module(load"immark")  # provides --MARK-- message capability

# Provides UDP syslog reception
# for parameters see http://www.rsyslog.com/doc/imudp.html
module(load="imudp") # needs to be done just once
input(type="imudp" port="514")

# Provides TCP syslog reception
# for parameters see http://www.rsyslog.com/doc/imtcp.html
module(load="imtcp") # needs to be done just once
input(type="imtcp" port="514")


#### GLOBAL DIRECTIVES ####

# Use default timestamp format
\$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat

# File syncing capability is disabled by default. This feature is usually not required,
# not useful and an extreme performance hit
#$ActionFileEnableSync on

# Include all config files in /etc/rsyslog.d/
\$IncludeConfig /etc/rsyslog.d/*.conf


#### RULES ####

# Log all kernel messages to the console.
# Logging much else clutters up the screen.
#kern.*                                                 /dev/console

# Log anything (except mail) of level info or higher.
# Don't log private authentication messages!
*.info;mail.none;authpriv.none;cron.none                /var/log/messages

# The authpriv file has restricted access.
authpriv.*                                              /var/log/secure

# Log all the mail messages in one place.
mail.*                                                  /var/log/maillog


# Log cron stuff
cron.*                                                  /var/log/cron

# Everybody gets emergency messages
*.emerg                                                 :omusrmsg:*

# Save news errors of level crit and higher in a special file.
uucp,news.crit                                          /var/log/spooler

# Save boot messages also to boot.log
local7.*                                                /var/log/boot.log


:programname,isequal,"dhclient"  stop
:programname,isequal,"ec2net"    stop


# ### begin forwarding rule ###
# The statement between the begin ... end define a SINGLE forwarding
# rule. They belong together, do NOT split them. If you create multiple
# forwarding rules, duplicate the whole block!
# Remote Logging (we use TCP for reliable delivery)
#
# An on-disk queue is created for this action. If the remote host is
# down, messages are spooled to disk and sent when it is up again.
#$WorkDirectory /var/lib/rsyslog # where to place spool files
#$ActionQueueFileName fwdRule1 # unique name prefix for spool files
#$ActionQueueMaxDiskSpace 1g   # 1gb space limit (use as much as possible)
#$ActionQueueSaveOnShutdown on # save messages to disk on shutdown
#$ActionQueueType LinkedList   # run asynchronously
#$ActionResumeRetryCount -1    # infinite retries if host is down
# remote host is: name/ip:port, e.g. 192.168.0.1:514, port optional
#*.* @@remote-host:514
# ### end of the forwarding rule ###


EOT

systemctl restart rsyslog.service

echo "{\"agent\":{\"metrics_collection_interval\":10,\"logfile\":\"/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log\"},\"logs\":{\"logs_collected\":{\"files\":{\"collect_list\":[{\"file_path\":\"/var/log/messages\",\"log_group_name\":\"/AWSAccelerator/rsyslog\",\"log_stream_name\":\"{instance_id}\",\"timezone\":\"UTC\"}]}},\"log_stream_name\":\"{instance_id}\",\"force_flush_interval\":15}}" >> /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -s -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
