#!/bin/bash
#
# crazy_logger_phone.sh
# Script to restart and point crazy_logger_phone.rb to the right log file
# when the log file is rotated daily

# stop crazy_logger.rb
/mnt/system/crazy_logger.rb stop
# start crazy_logger.rb with the clear temp file flag
/mnt/system/crazy_logger.rb -f /mnt/logs/mobilcastphone/MELODEO.log -u logger-01.mobilcast.ec2 --clear start