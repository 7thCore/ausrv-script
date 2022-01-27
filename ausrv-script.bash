#!/bin/bash

#    Copyright (C) 2022 7thCore
#    This file is part of AuSrv-Script.
#
#    AuSrv-Script is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    AuSrv-Script is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#Among Us Impostor server script by 7thCore
#If you do not know what any of these settings are you are better off leaving them alone. One thing might brake the other if you fiddle around with it.

#Basics
export NAME="AuSrv" #Name of the tmux session
export VERSION="1.0-3" #Package and script version

#Server configuration
export SERVICE_NAME="ausrv" #Name of the service files, user, script and script log
CONFIG_DIR="/srv/$SERVICE_NAME/config" #Location of this script

#Script configuration
if [ -f "$CONFIG_DIR/$SERVICE_NAME-script.conf" ] ; then
	BCKP_DELOLD=$(cat $CONFIG_DIR/$SERVICE_NAME-script.conf | grep script_bckp_delold= | cut -d = -f2) #Delete old backups.
	LOG_DELOLD=$(cat $CONFIG_DIR/$SERVICE_NAME-script.conf | grep script_log_delold= | cut -d = -f2) #Delete old logs.
	UPDATE_IGNORE_FAILED_ACTIVATIONS=$(cat $CONFIG_DIR/$SERVICE_NAME-script.conf | grep script_update_ignore_failed_startups= | cut -d = -f2) #Ignore failed startups during update configuration
else
	BCKP_DELOLD=7
	LOG_DELOLD=7
	UPDATE_IGNORE_FAILED_ACTIVATIONS=0
fi

#Discord configuration
if [ -f "$CONFIG_DIR/$SERVICE_NAME-discord.conf" ] ; then
	DISCORD_UPDATE=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf | grep discord_update= | cut -d = -f2) #Send notification when the server updates
	DISCORD_START=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf | grep discord_start= | cut -d = -f2) #Send notifications when the server starts
	DISCORD_STOP=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf | grep discord_stop= | cut -d = -f2) #Send notifications when the server stops
	DISCORD_CRASH=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf | grep discord_crash= | cut -d = -f2) #Send notifications when the server crashes
else
	DISCORD_UPDATE="0"
	DISCORD_START="0"
	DISCORD_STOP="0"
	DISCORD_CRASH="0"
fi

#Email configuration
if [ -f "$CONFIG_DIR/$SERVICE_NAME-email.conf" ] ; then
	EMAIL_SENDER=$(cat $CONFIG_DIR/$SERVICE_NAME-email.conf | grep email_sender= | cut -d = -f2) #Send emails from this address
	EMAIL_RECIPIENT=$(cat $CONFIG_DIR/$SERVICE_NAME-email.conf | grep email_recipient= | cut -d = -f2) #Send emails to this address
	EMAIL_UPDATE=$(cat $CONFIG_DIR/$SERVICE_NAME-email.conf | grep email_update= | cut -d = -f2) #Send emails when server updates
	EMAIL_START=$(cat $CONFIG_DIR/$SERVICE_NAME-email.conf | grep email_start= | cut -d = -f2) #Send emails when the server starts up
	EMAIL_STOP=$(cat $CONFIG_DIR/$SERVICE_NAME-email.conf | grep email_stop= | cut -d = -f2) #Send emails when the server shuts down
	EMAIL_CRASH=$(cat $CONFIG_DIR/$SERVICE_NAME-email.conf | grep email_crash= | cut -d = -f2) #Send emails when the server crashes
else
	EMAIL_SENDER="0"
	EMAIL_RECIPIENT="0"
	EMAIL_UPDATE="0"
	EMAIL_START="0"
	EMAIL_STOP="0"
	EMAIL_CRASH="0"
fi

#Backup configuration
BCKP_SRC="*" #What files to backup, * for all
BCKP_DIR="/srv/$SERVICE_NAME/backups" #Location of stored backups
BCKP_DEST="$BCKP_DIR/$(date +"%Y")/$(date +"%m")/$(date +"%d")" #How backups are sorted, by default it's sorted in folders by month and day

#Log configuration
export LOG_DIR="/srv/$SERVICE_NAME/logs/$(date +"%Y")/$(date +"%m")/$(date +"%d")"
export LOG_DIR_ALL="/srv/$SERVICE_NAME/logs"
export LOG_SCRIPT="$LOG_DIR/$SERVICE_NAME-script.log" #Script log
export CRASH_DIR="/srv/$SERVICE_NAME/logs/crashes/$(date +"%Y-%m-%d_%H-%M")"

#Console collors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
LIGHTRED='\033[1;31m'
NC='\033[0m'

#-------Do not edit anything beyond this line-------

#Generate log folder structure
script_logs() {
	#If there is not a folder for today, create one
	if [ ! -d "$LOG_DIR" ]; then
		mkdir -p $LOG_DIR
	fi
}

#---------------------------

#Deletes old files
script_remove_old_files() {
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Remove old files) Beginning removal of old files." | tee -a "$LOG_SCRIPT"
	#Delete old logs
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Remove old files) Removing old script logs: $LOG_DELOLD days old." | tee -a "$LOG_SCRIPT"
	find $LOG_DIR_ALL/* -mtime +$LOG_DELOLD -delete
	#Delete old game logs
	#Delete empty folders
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Remove old files) Removing empty script log folders." | tee -a "$LOG_SCRIPT"
	find $LOG_DIR_ALL/ -type d -empty -delete
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Remove old files) Removal of old files complete." | tee -a "$LOG_SCRIPT"
}

#---------------------------

#Prints out if the server is running
script_status() {
	script_logs
	IFS=","
	for SERVER_SERVICE in $(cat $CONFIG_DIR/$SERVICE_NAME-server-list.txt | tr "\\n" "," | sed 's/,$//'); do
		SERVER_NUMBER=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is not running." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is running." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is in failed state. Please check logs." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "activating" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is activating. Please wait." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "deactivating" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is in deactivating. Please wait." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "disabled" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is disabled." | tee -a "$LOG_SCRIPT"
		fi
	done
	if pidof -x "$SCRIPT_PID_CHECK" -o $$ > /dev/null; then
		echo "Is another instance of the script running?: YES"
	else
		echo "Is another instance of the script running?: NO"
	fi
}

#---------------------------

#Adds a server instance to the server list file
script_add_server() {
	script_logs
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Add server instance) User adding new server instance." | tee -a "$LOG_SCRIPT"
	read -p "Are you sure you want to add a server instance? (y/n): " ADD_SERVER_INSTANCE
	if [[ "$ADD_SERVER_INSTANCE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo ""
		echo "List of current servers (your new server instance must NOT be identical to any of them!):"
		if [ ! -f $CONFIG_DIR/$SERVICE_NAME-server-list.txt ] ; then
			touch $CONFIG_DIR/$SERVICE_NAME-server-list.txt
		fi
		cat $CONFIG_DIR/$SERVICE_NAME-server-list.txt
		echo ""
		read -p "Specify your server instance (Single digit numbers must have a 0 before them. Example: 07): " SERVER_INSTANCE
		echo "$SERVICE_NAME@$SERVER_INSTANCE.service" >> $CONFIG_DIR/$SERVICE_NAME-server-list.txt
		systemctl --user enable $SERVICE_NAME@$SERVER_INSTANCE.service
		echo ""
		read -p "Server instance $SERVER_INSTANCE added successfully. Do you want to start it? (y/n): " START_SERVER_INSTANCE
		if [[ "$START_SERVER_INSTANCE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			systemctl --user start $SERVICE_NAME@$SERVER_INSTANCE.service
		fi
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Add server instance) Server instance $SERVER_INSTANCE successfully added." | tee -a "$LOG_SCRIPT"
	else
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Add server instance) User canceled adding new server instance." | tee -a "$LOG_SCRIPT"
	fi
}

#---------------------------

#Removes a server instance from the server list file
script_remove_server() {
	script_logs
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Remove server instance) User started removal of server instance." | tee -a "$LOG_SCRIPT"
	read -p "Are you sure you want to remove a server instance? (y/n): " REMOVE_SERVER_INSTANCE
	if [[ "$REMOVE_SERVER_INSTANCE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo ""
		echo "List of current servers:"
		cat $CONFIG_DIR/$SERVICE_NAME-server-list.txt
		echo ""
		read -p "Specify your server instance (Single digit numbers must have a 0 before them. Example: 07): " SERVER_INSTANCE
		sed -e "s/$SERVICE_NAME@$SERVER_INSTANCE.service//g" -i $CONFIG_DIR/$SERVICE_NAME-server-list.txt
		sed '/^$/d' -i $CONFIG_DIR/$SERVICE_NAME-server-list.txt
		systemctl --user disable $SERVICE_NAME@$SERVER_INSTANCE.service
		echo ""
		read -p "Server instance $SERVER_INSTANCE removed successfully. Do you want to stop it? (y/n): " STOP_SERVER_INSTANCE
		if [[ "$STOP_SERVER_INSTANCE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			systemctl --user stop $SERVICE_NAME@$SERVER_INSTANCE.service
		fi
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Remove server instance) Server instance $SERVER_INSTANCE successfully removed." | tee -a "$LOG_SCRIPT"
	else
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Remove server instance) User canceled removal of server instance." | tee -a "$LOG_SCRIPT"
	fi
}

#---------------------------

#Attaches to the server tmux session
script_attach() {
	script_logs
	if [ -z "$1" ]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Attach) Failed to attach. Specify server ID: $SERVICE_NAME-script -attach ID" | tee -a "$LOG_SCRIPT"
	else
		tmux -L $SERVICE_NAME-$1-tmux.sock has-session -t $NAME 2>/dev/null
		if [ $? == 0 ]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Attach) User attached to server session with ID: $1" | tee -a "$LOG_SCRIPT"
			tmux -L $SERVICE_NAME-$1-tmux.sock attach -t $NAME
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Attach) User deattached from server session with ID: $1" | tee -a "$LOG_SCRIPT"
		else
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Attach) Failed to attach to server session with ID: $1" | tee -a "$LOG_SCRIPT"
		fi
	fi
}

#---------------------------

#Disable all script services
script_disable_services() {
	script_logs
	IFS=","
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service | awk '{print $1}' | tr "\\n" "," | sed 's/,$//'); do
		if [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			systemctl --user disable $SERVER_SERVICE
		fi
	done
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-timer-1.timer)" == "enabled" ]]; then
		systemctl --user disable $SERVICE_NAME-timer-1.timer
	fi
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-timer-2.timer)" == "enabled" ]]; then
		systemctl --user disable $SERVICE_NAME-timer-2.timer
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Disable services) Services successfully disabled." | tee -a "$LOG_SCRIPT"
}

#---------------------------

#Disables all script services, available to the user
script_disable_services_manual() {
	script_logs
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Disable services) WARNING: This will disable all script services. The server will be disabled." | tee -a "$LOG_SCRIPT"
	read -p "Are you sure you want to disable all services? (y/n): " DISABLE_SCRIPT_SERVICES
	if [[ "$DISABLE_SCRIPT_SERVICES" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		script_disable_services
	elif [[ "$DISABLE_SCRIPT_SERVICES" =~ ^([nN][oO]|[nN])$ ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Disable services) Disable services canceled." | tee -a "$LOG_SCRIPT"
	fi
}

#---------------------------

# Enable script services by reading the configuration file
script_enable_services() {
	script_logs
	IFS=","
	for SERVER_SERVICE in $(cat $CONFIG_DIR/$SERVICE_NAME-server-list.txt | tr "\\n" "," | sed 's/,$//'); do
		if [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "disabled" ]]; then
			systemctl --user enable $SERVER_SERVICE
		fi
	done
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-timer-1.timer)" == "disabled" ]]; then
		systemctl --user enable $SERVICE_NAME-timer-1.timer
	fi
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-timer-2.timer)" == "disabled" ]]; then
		systemctl --user enable $SERVICE_NAME-timer-2.timer
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Enable services) Services successfully Enabled." | tee -a "$LOG_SCRIPT"
}

#---------------------------

# Enable script services by reading the configuration file, available to the user
script_enable_services_manual() {
	script_logs
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Enable services) This will enable all script services. All added servers will be enabled." | tee -a "$LOG_SCRIPT"
	read -p "Are you sure you want to enable all services? (y/n): " ENABLE_SCRIPT_SERVICES
	if [[ "$ENABLE_SCRIPT_SERVICES" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		script_enable_services
	elif [[ "$ENABLE_SCRIPT_SERVICES" =~ ^([nN][oO]|[nN])$ ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Enable services) Enable services canceled." | tee -a "$LOG_SCRIPT"
	fi
}

#---------------------------

#Disables all script services an re-enables them by reading the configuration file
script_reload_services() {
	script_logs
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reload services) This will reload all script services." | tee -a "$LOG_SCRIPT"
	read -p "Are you sure you want to reload all services? (y/n): " RELOAD_SCRIPT_SERVICES
	if [[ "$RELOAD_SCRIPT_SERVICES" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		script_disable_services
		systemctl --user daemon-reload
		script_enable_services
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reload services) Reload services complete." | tee -a "$LOG_SCRIPT"
	elif [[ "$RELOAD_SCRIPT_SERVICES" =~ ^([nN][oO]|[nN])$ ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reload services) Reload services canceled." | tee -a "$LOG_SCRIPT"
	fi
}

#---------------------------

#Systemd service sends notification if notifications for start enabled
script_send_notification_start_initialized() {
	script_logs
	if [[ "$EMAIL_START" == "1" ]]; then
		mail -r "$EMAIL_SENDER ($NAME-$1)" -s "Notification: Server startup $1" $EMAIL_RECIPIENT <<- EOF
		Server startup for $1 was initialized at $(date +"%d.%m.%Y %H:%M:%S")
		EOF
	fi
	if [[ "$DISCORD_START" == "1" ]]; then
		while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
			curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server startup for $1 was initialized.\"}" "$DISCORD_WEBHOOK"
		done < $CONFIG_DIR/discord_webhooks.txt
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server startup for $1 was initialized." | tee -a "$LOG_SCRIPT"
}

#---------------------------

#Systemd service sends notification if notifications for start enabled
script_send_notification_start_complete() {
	script_logs
	if [[ "$EMAIL_START" == "1" ]]; then
		mail -r "$EMAIL_SENDER ($NAME-$1)" -s "Notification: Server startup $1" $EMAIL_RECIPIENT <<- EOF
		Server startup for $1 was completed at $(date +"%d.%m.%Y %H:%M:%S")
		EOF
	fi
	if [[ "$DISCORD_START" == "1" ]]; then
		while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
			curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server startup for $1 complete.\"}" "$DISCORD_WEBHOOK"
		done < $CONFIG_DIR/discord_webhooks.txt
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server startup for $1 complete." | tee -a "$LOG_SCRIPT"
}

#---------------------------

#Systemd service sends notification if notifications for stop enabled
script_send_notification_stop_initialized() {
	script_logs
	if [[ "$EMAIL_STOP" == "1" ]]; then
		mail -r "$EMAIL_SENDER ($NAME-$1)" -s "Notification: Server shutdown $1" $EMAIL_RECIPIENT <<- EOF
		Server shutdown was initiated at $(date +"%d.%m.%Y %H:%M:%S")
		EOF
	fi
	if [[ "$DISCORD_STOP" == "1" ]]; then
		while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
			curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server shutdown for $1 was initialized.\"}" "$DISCORD_WEBHOOK"
		done < $CONFIG_DIR/discord_webhooks.txt
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server shutdown for $1 was initialized." | tee -a "$LOG_SCRIPT"
}

#---------------------------

#Systemd service sends notification if notifications for stop enabled
script_send_notification_stop_complete() {
	script_logs
	if [[ "$EMAIL_STOP" == "1" ]]; then
		mail -r "$EMAIL_SENDER ($NAME-$1)" -s "Notification: Server shutdown $1" $EMAIL_RECIPIENT <<- EOF
		Server shutdown was complete at $(date +"%d.%m.%Y %H:%M:%S")
		EOF
	fi
	if [[ "$DISCORD_STOP" == "1" ]]; then
		while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
			curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server shutdown for $1 complete.\"}" "$DISCORD_WEBHOOK"
		done < $CONFIG_DIR/discord_webhooks.txt
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server shutdown for $1 complete." | tee -a "$LOG_SCRIPT"
}

#---------------------------

#Systemd service sends email if email notifications for crashes enabled
script_send_notification_crash() {
	script_logs
	if [ ! -d "$CRASH_DIR" ]; then
		mkdir -p "$CRASH_DIR"
	fi
	
	systemctl --user status $SERVICE_NAME@$1.service > $CRASH_DIR/service_log.txt
	zip -j $CRASH_DIR/service_logs.zip $CRASH_DIR/service_log.txt
	zip -j $CRASH_DIR/script_logs.zip $LOG_SCRIPT
	rm $CRASH_DIR/service_log.txt
	
	if [[ "$EMAIL_CRASH" == "1" ]]; then
		mail -a $CRASH_DIR/service_logs.zip -a $CRASH_DIR/script_logs.zip -r "$EMAIL_SENDER ($NAME $SERVICE_NAME)" -s "Notification: Crash" $EMAIL_RECIPIENT <<- EOF
		The $NAME server $1 crashed 3 times in the last 5 minutes. Automatic restart is disabled and the server is inactive. Please check the logs for more information.
		
		Attachment contents:
		service_logs.zip - Logs from the systemd service
		script_logs.zip - Logs from the script
		
		Contact the script developer 7thCore on discord for help regarding any problems the script may have caused.
		EOF
	fi
	
	if [[ "$DISCORD_CRASH" == "1" ]]; then
		while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
			curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Crash) The server crashed 3 times in the last 5 minutes. Automatic restart is disabled and the server is inactive. Please review your logs located in $CRASH_DIR.\"}" "$DISCORD_WEBHOOK"
		done < $CONFIG_DIR/discord_webhooks.txt
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Crash) Server crashed. Please review your logs located in $CRASH_DIR." | tee -a "$LOG_SCRIPT"
	
	touch /tmp/$(id -u $SERVICE_NAME).crash
}

#---------------------------

#Start the server
script_start() {
	script_logs
	if [ -z "$1" ]; then
		IFS=","
		for SERVER_SERVICE in $(cat $CONFIG_DIR/$SERVICE_NAME-server-list.txt | tr "\\n" "," | sed 's/,$//'); do
			SERVER_NUMBER=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
			if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER start initialized." | tee -a "$LOG_SCRIPT"
				systemctl --user start $SERVER_SERVICE
				sleep 1
				while [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "activating" ]]; do
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER is activating. Please wait..." | tee -a "$LOG_SCRIPT"
					sleep 1
				done
				if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]]; then
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER has been successfully activated." | tee -a "$LOG_SCRIPT"
					sleep 1
				elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]]; then
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER failed to activate. See systemctl --user status $SERVER_SERVICE for details." | tee -a "$LOG_SCRIPT"
					sleep 1
				fi
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER is already running." | tee -a "$LOG_SCRIPT"
				sleep 1
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER is in failed state. See systemctl --user status $SERVER_SERVICE for details." | tee -a "$LOG_SCRIPT"
				read -p "Do you still want to start the server? (y/n): " FORCE_START
				if [[ "$FORCE_START" =~ ^([yY][eE][sS]|[yY])$ ]]; then
					systemctl --user start $SERVER_SERVICE
					sleep 1
					while [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "activating" ]]; do
						echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER is activating. Please wait..." | tee -a "$LOG_SCRIPT"
						sleep 1
					done
					if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]]; then
						echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER has been successfully activated." | tee -a "$LOG_SCRIPT"
						sleep 1
					elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]]; then
						echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER failed to activate. See systemctl --user status $SERVER_SERVICE for details." | tee -a "$LOG_SCRIPT"
						sleep 1
					fi
				fi
			fi
		done
	else
		if [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "inactive" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 start initialized." | tee -a "$LOG_SCRIPT"
			systemctl --user start $SERVICE_NAME@$1.service
			sleep 1
			while [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "activating" ]]; do
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 is activating. Please wait..." | tee -a "$LOG_SCRIPT"
				sleep 1
			done
			if [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "active" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 has been successfully activated." | tee -a "$LOG_SCRIPT"
				sleep 1
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "failed" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 failed to activate. See systemctl --user status $SERVICE_NAME@$1.service for details." | tee -a "$LOG_SCRIPT"
				sleep 1
			fi
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "active" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 is already running." | tee -a "$LOG_SCRIPT"
			sleep 1
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "failed" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 is in failed state. See systemctl --user status $SERVICE_NAME@$1.service for details." | tee -a "$LOG_SCRIPT"
			read -p "Do you still want to start the server? (y/n): " FORCE_START
			if [[ "$FORCE_START" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				systemctl --user start $SERVICE_NAME@$1.service
				sleep 1
				while [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "activating" ]]; do
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 is activating. Please wait..." | tee -a "$LOG_SCRIPT"
					sleep 1
				done
				if [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "active" ]]; then
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 has been successfully activated." | tee -a "$LOG_SCRIPT"
					sleep 1
				elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "failed" ]]; then
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 failed to activate. See systemctl --user status $SERVICE_NAME@$1.service for details." | tee -a "$LOG_SCRIPT"
					sleep 1
				fi
			fi
		fi
	fi
}

#---------------------------

#Start the server ignorring failed states
script_start_ignore_errors() {
	script_logs
	if [ -z "$1" ]; then
		IFS=","
		for SERVER_SERVICE in $(cat $CONFIG_DIR/$SERVICE_NAME-server-list.txt | tr "\\n" "," | sed 's/,$//'); do
			SERVER_NUMBER=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
			if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER start initialized." | tee -a "$LOG_SCRIPT"
				systemctl --user start $SERVER_SERVICE
				sleep 1
				while [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "activating" ]]; do
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER is activating. Please wait..." | tee -a "$LOG_SCRIPT"
					sleep 1
				done
				if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]]; then
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER has been successfully activated." | tee -a "$LOG_SCRIPT"
					sleep 1
				elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]]; then
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER failed to activate. See systemctl --user status $SERVER_SERVICE for details." | tee -a "$LOG_SCRIPT"
					sleep 1
				fi
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER is already running." | tee -a "$LOG_SCRIPT"
				sleep 1
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER is in failed state. See systemctl --user status $SERVER_SERVICE for details." | tee -a "$LOG_SCRIPT"
				systemctl --user start $SERVER_SERVICE
				sleep 1
				while [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "activating" ]]; do
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER is activating. Please wait..." | tee -a "$LOG_SCRIPT"
					sleep 1
				done
				if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]]; then
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER has been successfully activated." | tee -a "$LOG_SCRIPT"
					sleep 1
				elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]]; then
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $SERVER_NUMBER failed to activate. See systemctl --user status $SERVER_SERVICE for details." | tee -a "$LOG_SCRIPT"
					sleep 1
				fi
			fi
		done
	else
		if [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "inactive" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 start initialized." | tee -a "$LOG_SCRIPT"
			systemctl --user start $SERVICE_NAME@$1.service
			sleep 1
			while [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "activating" ]]; do
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 is activating. Please wait..." | tee -a "$LOG_SCRIPT"
				sleep 1
			done
			if [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "active" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 has been successfully activated." | tee -a "$LOG_SCRIPT"
				sleep 1
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "failed" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 failed to activate. See systemctl --user status $SERVICE_NAME@$1.service for details." | tee -a "$LOG_SCRIPT"
				sleep 1
			fi
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "active" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 is already running." | tee -a "$LOG_SCRIPT"
			sleep 1
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "failed" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 is in failed state. See systemctl --user status $SERVICE_NAME@$1.service for details." | tee -a "$LOG_SCRIPT"
			systemctl --user start $SERVICE_NAME@$1.service
			sleep 1
			while [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "activating" ]]; do
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 is activating. Please wait..." | tee -a "$LOG_SCRIPT"
				sleep 1
			done
			if [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "active" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 has been successfully activated." | tee -a "$LOG_SCRIPT"
				sleep 1
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "failed" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server $1 failed to activate. See systemctl --user status $SERVICE_NAME@$1.service for details." | tee -a "$LOG_SCRIPT"
				sleep 1
			fi
		fi
	fi
}

#---------------------------

#Stop the server
script_stop() {
	script_logs
	if [ -z "$1" ]; then
		IFS=","
		for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service | awk '{print $1}' | tr "\\n" "," | sed 's/,$//'); do
			SERVER_NUMBER=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
			if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server $SERVER_NUMBER is not running." | tee -a "$LOG_SCRIPT"
				sleep 1
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server $SERVER_NUMBER is in failed state. Please check logs." | tee -a "$LOG_SCRIPT"
				sleep 1
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server $SERVER_NUMBER shutdown in progress." | tee -a "$LOG_SCRIPT"
				systemctl --user stop $SERVER_SERVICE
				sleep 1
				while [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "deactivating" ]]; do
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server $SERVER_NUMBER is deactivating. Please wait..." | tee -a "$LOG_SCRIPT"
					sleep 1
				done
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server $SERVER_NUMBER is deactivated." | tee -a "$LOG_SCRIPT"
			fi
		done
	else
		if [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "inactive" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server $1 is not running." | tee -a "$LOG_SCRIPT"
			sleep 1
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "failed" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop)  Server $SERVER_NUMBER is in failed state. Please check logs." | tee -a "$LOG_SCRIPT"
			sleep 1
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "active" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server $1 shutdown in progress." | tee -a "$LOG_SCRIPT"
			systemctl --user stop $SERVICE_NAME@$1.service
			sleep 1
			while [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "deactivating" ]]; do
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server $1 is deactivating. Please wait..." | tee -a "$LOG_SCRIPT"
				sleep 1
			done
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server $1 is deactivated." | tee -a "$LOG_SCRIPT"
		fi
	fi
}

#---------------------------

#Restart the server
script_restart() {
	script_logs
	if [ -z "$1" ]; then
		IFS=","
		for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service | awk '{print $1}' | tr "\\n" "," | sed 's/,$//'); do
			SERVER_NUMBER=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
			if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Restart) Server $SERVER_NUMBER is not running. Use -start to start the server." | tee -a "$LOG_SCRIPT"
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "activating" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Restart) Server $SERVER_NUMBER is activating. Aborting restart." | tee -a "$LOG_SCRIPT"
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "deactivating" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Restart) Server $SERVER_NUMBER is in deactivating. Aborting restart." | tee -a "$LOG_SCRIPT"
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Restart) Server $SERVER_NUMBER is going to restart in 15-30 seconds, please wait..." | tee -a "$LOG_SCRIPT"
				sleep 1
				script_stop $SERVER_NUMBER
				sleep 1
				script_start $SERVER_NUMBER
				sleep 1
			fi
		done
	else
		if [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "inactive" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Restart) Server $1 is not running. Use -start to start the server." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "activating" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Restart) Server $1 is activating. Aborting restart." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "deactivating" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Restart) Server $1 is in deactivating. Aborting restart." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME@$1.service)" == "active" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Restart) Server $1 is going to restart in 15-30 seconds, please wait..." | tee -a "$LOG_SCRIPT"
			sleep 1
			script_stop $1
			sleep 1
			script_start $1
			sleep 1
		fi
	fi
}

#---------------------------

#Deletes old backups
script_deloldbackup() {
	script_logs
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete old backup) Deleting old backups: $BCKP_DELOLD days old." | tee -a "$LOG_SCRIPT"
	# Delete old backups
	find $BCKP_DIR/* -type f -mtime +$BCKP_DELOLD -delete
	# Delete empty folders
	find $BCKP_DIR/ -type d -empty -delete
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete old backup) Deleting old backups complete." | tee -a "$LOG_SCRIPT"
}

#---------------------------

#Creates a backup of the server
script_backup() {
	script_logs
	#If there is not a folder for today, create one
	if [ ! -d "$BCKP_DEST" ]; then
		mkdir -p $BCKP_DEST
	fi
	#Backup source to destination
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Backup) Backup has been initiated." | tee -a "$LOG_SCRIPT"
	cd "/srv/$SERVICE_NAME/server-$1"
	tar -cpvzf $BCKP_DEST/$(date +"%Y%m%d%H%M")_$1.tar.gz /srv/$SERVICE_NAME/server-$1/$BCKP_SRC #| sed -e "s/^/$(date +"%Y-%m-%d %H:%M:%S") [$NAME] [INFO] (Backup) Compressing: /" | tee -a "$LOG_SCRIPT"
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Backup) Backup complete." | tee -a "$LOG_SCRIPT"
}

#---------------------------

#Automaticly backs up the server and deletes old backups
script_autobackup() {
	script_logs
	IFS=","
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service | awk '{print $1}' | tr "\\n" "," | sed 's/,$//'); do
		SERVER_NUMBER=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" != "active" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Autobackup) Server $SERVER_NUMBER is not running." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]]; then
			RUNNING_SERVERS=$(($RUNNING_SERVERS + 1))
			sleep 1
			script_backup $SERVER_NUMBER
			sleep 1
			script_deloldbackup
		fi
	done
}

#---------------------------

#Install tmux configuration for specific server when first ran
script_server_tmux_install() {
	if [ -z "$2" ]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Server tmux configuration) Installing tmux configuration for server $1." | tee -a "$LOG_SCRIPT"
		TMUX_CONFIG_FILE="/tmp/$SERVICE_NAME-$1-tmux.conf"
	elif [[ "$2" == "override" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Server tmux configuration) Installing tmux override configuration for server $1." | tee -a "$LOG_SCRIPT"
		TMUX_CONFIG_FILE="/srv/$SERVICE_NAME/config/$SERVICE_NAME-$1-tmux.conf"
	fi
	
	if [ -f /srv/$SERVICE_NAME/config/$SERVICE_NAME-$1-tmux.conf ]; then
		cp /srv/$SERVICE_NAME/config/$SERVICE_NAME-$1-tmux.conf /tmp/$SERVICE_NAME-$1-tmux.conf
	else
		if [ ! -f $TMUX_CONFIG_FILE ]; then
			touch $TMUX_CONFIG_FILE
			cat > $TMUX_CONFIG_FILE <<- EOF
			#Tmux configuration
			set -g activity-action other
			set -g allow-rename off
			set -g assume-paste-time 1
			set -g base-index 0
			set -g bell-action any
			set -g default-command "${SHELL}"
			#set -g default-terminal "tmux-256color"
			set -g default-terminal "screen-hack_color"
			set -g default-shell "/bin/bash"
			set -g default-size "132x42"
			set -g destroy-unattached off
			set -g detach-on-destroy on
			set -g display-panes-active-colour red
			set -g display-panes-colour blue
			set -g display-panes-time 1000
			set -g display-time 3000
			set -g history-limit 10000
			set -g key-table "root"
			set -g lock-after-time 0
			set -g lock-command "lock -np"
			set -g message-command-style fg=yellow,bg=black
			set -g message-style fg=black,bg=yellow
			set -g mouse on
			#set -g prefix C-b
			set -g prefix2 None
			set -g renumber-windows off
			set -g repeat-time 500
			set -g set-titles off
			set -g set-titles-string "#S:#I:#W - \"#T\" #{session_alerts}"
			set -g silence-action other
			set -g status on
			set -g status-bg green
			set -g status-fg black
			set -g status-format[0] "#[align=left range=left #{status-left-style}]#{T;=/#{status-left-length}:status-left}#[norange default]#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index} #{window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{window-status-last-style},default}}, #{window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{window-status-bell-style},default}}, #{window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{window-status-activity-style},default}}, #{window-status-activity-style},}}]#{T:window-status-format}#[norange default]#{?window_end_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{window-status-current-style},default},#{window-status-current-style},#{window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{window-status-last-style},default}}, #{window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{window-status-bell-style},default}}, #{window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{window-status-activity-style},default}}, #{window-status-activity-style},}}]#{T:window-status-current-format}#[norange list=on default]#{?window_end_flag,,#{window-status-separator}}}#[nolist align=right range=right #{status-right-style}]#{T;=/#{status-right-length}:status-right}#[norange default]"
			set -g status-format[1] "#[align=centre]#{P:#{?pane_active,#[reverse],}#{pane_index}[#{pane_width}x#{pane_height}]#[default] }"
			set -g status-interval 15
			set -g status-justify left
			set -g status-keys emacs
			set -g status-left "[#S] "
			set -g status-left-length 10
			set -g status-left-style default
			set -g status-position bottom
			set -g status-right "#{?window_bigger,[#{window_offset_x}#,#{window_offset_y}] ,}\"#{=21:pane_title}\" %H:%M %d-%b-%y"
			set -g status-right-length 40
			set -g status-right-style default
			set -g status-style fg=black,bg=green
			set -g update-environment[0] "DISPLAY"
			set -g update-environment[1] "KRB5CCNAME"
			set -g update-environment[2] "SSH_ASKPASS"
			set -g update-environment[3] "SSH_AUTH_SOCK"
			set -g update-environment[4] "SSH_AGENT_PID"
			set -g update-environment[5] "SSH_CONNECTION"
			set -g update-environment[6] "WINDOWID"
			set -g update-environment[7] "XAUTHORITY"
			set -g visual-activity off
			set -g visual-bell off
			set -g visual-silence off
			set -g word-separators " -_@"

			#Change prefix key from ctrl+b to ctrl+a
			unbind C-b
			set -g prefix C-a
			bind C-a send-prefix

			#Bind C-a r to reload the config file
			bind-key r source-file /tmp/$SERVICE_NAME-$1-tmux.conf \; display-message "Config reloaded!"

			set-hook -g session-created 'resize-window -y 24 -x 10000'
			set-hook -g session-created "pipe-pane -o 'tee >> /tmp/$SERVICE_NAME-$1-tmux.log'"
			set-hook -g client-attached 'resize-window -y 24 -x 10000'
			set-hook -g client-detached 'resize-window -y 24 -x 10000'
			set-hook -g client-resized 'resize-window -y 24 -x 10000'

			#Default key bindings (only here for info)
			#Ctrl-b l (Move to the previously selected window)
			#Ctrl-b w (List all windows / window numbers)
			#Ctrl-b <window number> (Move to the specified window number, the default bindings are from 0 – 9)
			#Ctrl-b q  (Show pane numbers, when the numbers show up type the key to goto that pane)

			#Ctrl-b f <window name> (Search for window name)
			#Ctrl-b w (Select from interactive list of windows)

			#Copy/ scroll mode
			#Ctrl-b [ (in copy mode you can navigate the buffer including scrolling the history. Use vi or emacs-style key bindings in copy mode. The default is emacs. To exit copy mode use one of the following keybindings: vi q emacs Esc)
			EOF
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Server tmux configuration) Tmux configuration for server $1 installed successfully." | tee -a "$LOG_SCRIPT"
		fi
	fi
}

#---------------------------

#First timer function for systemd timers to execute parts of the script in order without interfering with each other
script_timer_one() {
	script_logs
	RUNNING_SERVERS="0"
	IFS=","
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service | awk '{print $1}' | tr "\\n" "," | sed 's/,$//'); do
		SERVER_NUMBER=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is not running." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is in failed state. Please check logs." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME)" == "activating" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is activating. Aborting until next scheduled execution." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME)" == "deactivating" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is in deactivating. Aborting until next scheduled execution." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is running." | tee -a "$LOG_SCRIPT"
			RUNNING_SERVERS=$(($RUNNING_SERVERS + 1))
		fi
	done
	
	if [ $RUNNING_SERVERS -gt "0" ]; then
		script_remove_old_files
		script_autobackup
	fi
}

#---------------------------

#Second timer function for systemd timers to execute parts of the script in order without interfering with each other
script_timer_two() {
	script_logs
	RUNNING_SERVERS="0"
	IFS=","
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service | awk '{print $1}' | tr "\\n" "," | sed 's/,$//'); do
		SERVER_NUMBER=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is not running." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is in failed state. Please check logs." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME)" == "activating" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is activating. Aborting until next scheduled execution." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE_NAME)" == "deactivating" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is in deactivating. Aborting until next scheduled execution." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server $SERVER_NUMBER is running." | tee -a "$LOG_SCRIPT"
			RUNNING_SERVERS=$(($RUNNING_SERVERS + 1))
		fi
	done
	
	if [ $RUNNING_SERVERS -gt "0" ]; then
		script_remove_old_files
	fi
}

#---------------------------

#Runs the diagnostics
script_diagnostics() {
	echo "Initializing diagnostics. Please wait..."
	echo ""
	sleep 3

	#Check package versions
	echo "Checkign package versions:"
	if [ -f "/usr/bin/pacman" ]; then
		echo "bash version:$(pacman -Qi bash | grep "^Version" | cut -d : -f2)"
		echo "coreutils version:$(pacman -Qi coreutils | grep "^Version" | cut -d : -f2)"
		echo "sudo version:$(pacman -Qi sudo | grep "^Version" | cut -d : -f2)"
		echo "grep version:$(pacman -Qi grep | grep "^Version" | cut -d : -f2)"
		echo "sed version:$(pacman -Qi sed | grep "^Version" | cut -d : -f2)"
		echo "awk version:$(pacman -Qi awk | grep "^Version" | cut -d : -f2)"
		echo "curl version:$(pacman -Qi curl | grep "^Version" | cut -d : -f2)"
		echo "rsync version:$(pacman -Qi rsync | grep "^Version" | cut -d : -f2)"
		echo "wget version:$(pacman -Qi wget | grep "^Version" | cut -d : -f2)"
		echo "findutils version:$(pacman -Qi findutils | grep "^Version" | cut -d : -f2)"
		echo "tmux version:$(pacman -Qi tmux | grep "^Version" | cut -d : -f2)"
		echo "zip version:$(pacman -Qi zip | grep "^Version" | cut -d : -f2)"
		echo "unzip version:$(pacman -Qi unzip | grep "^Version" | cut -d : -f2)"
		echo "p7zip version:$(pacman -Qi p7zip | grep "^Version" | cut -d : -f2)"
		echo "postfix version:$(pacman -Qi postfix | grep "^Version" | cut -d : -f2)"
		echo "samba version:$(pacman -Qi samba | grep "^Version" | cut -d : -f2)"
	elif [ -f "/usr/bin/dpkg" ]; then
		echo "bash version:$(dpkg -s bash | grep "^Version" | cut -d : -f2)"
		echo "coreutils version:$(dpkg -s coreutils | grep "^Version" | cut -d : -f2)"
		echo "sudo version:$(dpkg -s sudo | grep "^Version" | cut -d : -f2)"
		echo "libpam-systemd version:$(dpkg -s libpam-systemd | grep "^Version" | cut -d : -f2)"
		echo "grep version:$(dpkg -s grep | grep "^Version" | cut -d : -f2)"
		echo "sed version:$(dpkg -s sed | grep "^Version" | cut -d : -f2)"
		echo "gawk version:$(dpkg -s gawk | grep "^Version" | cut -d : -f2)"
		echo "curl version:$(dpkg -s curl | grep "^Version" | cut -d : -f2)"
		echo "rsync version:$(dpkg -s rsync | grep "^Version" | cut -d : -f2)"
		echo "wget version:$(dpkg -s wget | grep "^Version" | cut -d : -f2)"
		echo "findutils version:$(dpkg -s findutils | grep "^Version" | cut -d : -f2)"
		echo "tmux version:$(dpkg -s tmux | grep "^Version" | cut -d : -f2)"

		echo "zip version:$(dpkg -s zip | grep "^Version" | cut -d : -f2)"
		echo "unzip version:$(dpkg -s unzip | grep "^Version" | cut -d : -f2)"
		echo "p7zip version:$(dpkg -s p7zip | grep "^Version" | cut -d : -f2)"
		echo "postfix version:$(dpkg -s postfix | grep "^Version" | cut -d : -f2)"
	fi
	echo ""

	echo "Checking if files and folders present:"
	#Check if files/folders present
	if [ -f "/usr/bin/$SERVICE_NAME-script" ] ; then
		echo "Script present: Yes"
	else
		echo "Script present: No"
	fi

	if [ -d "/srv/$SERVICE_NAME/config" ]; then
		echo "Configuration folder present: Yes"
	else
		echo "Configuration folder present: No"
	fi

	if [ -d "/srv/$SERVICE_NAME/backups" ]; then
		echo "Backups folder present: Yes"
	else
		echo "Backups folder present: No"
	fi
	
	if [ -d "/srv/$SERVICE_NAME/logs" ]; then
		echo "Logs folder present: Yes"
	else
		echo "Logs folder present: No"
	fi
	
	if [ -f "$CONFIG_DIR/$SERVICE_NAME-script.conf" ] ; then
		echo "Script configuration file present: Yes"
	else
		echo "Script configuration file present: No"
	fi

	if [ -f "$CONFIG_DIR/$SERVICE_NAME-discord.conf" ] ; then
		echo "Discord configuration file present: Yes"
	else
		echo "Discord configuration file present: No"
	fi

	if [ -f "$CONFIG_DIR/$SERVICE_NAME-email.conf" ] ; then
		echo "Email configuration file present: Yes"
	else
		echo "Email configuration file present: No"
	fi

	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME@.service" ]; then
		echo "Basic service present: Yes"
	else
		echo "Basic service present: No"
	fi
	
	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME-timer-1.timer" ]; then
		echo "Timer 1 timer present: Yes"
	else
		echo "Timer 1 timer present: No"
	fi
	
	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME-timer-1.service" ]; then
		echo "Timer 1 service present: Yes"
	else
		echo "Timer 1 service present: No"
	fi
	
	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME-timer-2.timer" ]; then
		echo "Timer 2 timer present: Yes"
	else
		echo "Timer 2 timer present: No"
	fi
	
	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME-timer-2.service" ]; then
		echo "Timer 2 service present: Yes"
	else
		echo "Timer 2 service present: No"
	fi
	
	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME-send-notification@.service" ]; then
		echo "Notification sending service present: Yes"
	else
		echo "Notification sending service present: No"
	fi
	
	if [ -f "/usr/bin/impostor-server" ]; then
		echo "Game executable present: Yes"
	else
		echo "Game executable present: No"
	fi
	
	echo "Diagnostics complete."
}

#---------------------------

#Configures discord integration
script_config_discord() {
	echo ""
	read -p "Enable discord notifications (y/n): " INSTALL_DISCORD_ENABLE
	if [[ "$INSTALL_DISCORD_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo ""
		echo "You are able to add multiple webhooks for the script to use in the discord_webhooks.txt file located in the config folder."
		echo "EACH ONE HAS TO BE IN IT'S OWN LINE!"
		echo ""
		read -p "Enter your first webhook for the server: " INSTALL_DISCORD_WEBHOOK
		if [[ "$INSTALL_DISCORD_WEBHOOK" == "" ]]; then
			INSTALL_DISCORD_WEBHOOK="none"
		fi
		echo ""
		read -p "Discord notifications for game updates? (y/n): " INSTALL_DISCORD_UPDATE_ENABLE
			if [[ "$INSTALL_DISCORD_UPDATE_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_DISCORD_UPDATE="1"
			else
				INSTALL_DISCORD_UPDATE="0"
			fi
		echo ""
		read -p "Discord notifications for server startup? (y/n): " INSTALL_DISCORD_START_ENABLE
			if [[ "$INSTALL_DISCORD_START_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_DISCORD_START="1"
			else
				INSTALL_DISCORD_START="0"
			fi
		echo ""
		read -p "Discord notifications for server shutdown? (y/n): " INSTALL_DISCORD_STOP_ENABLE
			if [[ "$INSTALL_DISCORD_STOP_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_DISCORD_STOP="1"
			else
				INSTALL_DISCORD_STOP="0"
			fi
		echo ""
		read -p "Discord notifications for crashes? (y/n): " INSTALL_DISCORD_CRASH_ENABLE
			if [[ "$INSTALL_DISCORD_CRASH_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_DISCORD_CRASH="1"
			else
				INSTALL_DISCORD_CRASH="0"
			fi
	elif [[ "$INSTALL_DISCORD_ENABLE" =~ ^([nN][oO]|[nN])$ ]]; then
		INSTALL_DISCORD_UPDATE="0"
		INSTALL_DISCORD_START="0"
		INSTALL_DISCORD_STOP="0"
		INSTALL_DISCORD_CRASH="0"
	fi

	echo "Writing configuration file..."
	touch $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_update='"$INSTALL_DISCORD_UPDATE" >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_start='"$INSTALL_DISCORD_START" >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_stop='"$INSTALL_DISCORD_STOP" >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_crash='"$INSTALL_DISCORD_CRASH" >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo "$INSTALL_DISCORD_WEBHOOK" > $CONFIG_DIR/discord_webhooks.txt
	echo "Done"
}

#---------------------------

#Configures email integration
script_config_email() {
	echo ""
	read -p "Enable email notifications (y/n): " INSTALL_EMAIL_ENABLE
	if [[ "$INSTALL_EMAIL_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo ""
		read -p "Enter the email that will send the notifications (example: sender@gmail.com): " INSTALL_EMAIL_SENDER
		echo ""
		read -p "Enter the email that will recieve the notifications (example: recipient@gmail.com): " INSTALL_EMAIL_RECIPIENT
		echo ""
		read -p "Email notifications for game updates? (y/n): " INSTALL_EMAIL_UPDATE_ENABLE
			if [[ "$INSTALL_EMAIL_UPDATE_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_EMAIL_UPDATE="1"
			else
				INSTALL_EMAIL_UPDATE="0"
			fi
		echo ""
		read -p "Email notifications for server startup? (WARNING: this can be anoying) (y/n): " INSTALL_EMAIL_START_ENABLE
			if [[ "$INSTALL_EMAIL_START_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_EMAIL_START="1"
			else
				INSTALL_EMAIL_START="0"
			fi
		echo ""
		read -p "Email notifications for server shutdown? (WARNING: this can be anoying) (y/n): " INSTALL_EMAIL_STOP_ENABLE
			if [[ "$INSTALL_EMAIL_STOP_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_EMAIL_STOP="1"
			else
				INSTALL_EMAIL_STOP="0"
			fi
		echo ""
		read -p "Email notifications for crashes? (y/n): " INSTALL_EMAIL_CRASH_ENABLE
			if [[ "$INSTALL_EMAIL_CRASH_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_EMAIL_CRASH="1"
			else
				INSTALL_EMAIL_CRASH="0"
			fi
		if [[ "$EUID" == "$(id -u root)" ]] ; then
			read -p "Configure postfix? (y/n): " INSTALL_EMAIL_CONFIGURE
			if [[ "$INSTALL_EMAIL_CONFIGURE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				echo ""
				read -p "Enter the relay host (example: smtp.gmail.com): " INSTALL_EMAIL_RELAY_HOSTNAME
				echo ""
				read -p "Enter the relay host port (example: 587): " INSTALL_EMAIL_RELAY_PORT
				echo ""
				read -p "Enter your password for $INSTALL_EMAIL_SENDER : " INSTALL_EMAIL_SENDER_PSW

				cat >> /etc/postfix/main.cf <<- EOF
				relayhost = [$INSTALL_EMAIL_RELAY_HOST]:$INSTALL_EMAIL_RELAY_PORT
				smtp_sasl_auth_enable = yes
				smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
				smtp_sasl_security_options = noanonymous
				smtp_tls_CApath = /etc/ssl/certs
				smtpd_tls_CApath = /etc/ssl/certs
				smtp_use_tls = yes
				EOF

				cat > /etc/postfix/sasl_passwd <<- EOF
				[$INSTALL_EMAIL_RELAY_HOST]:$INSTALL_EMAIL_RELAY_PORT    $INSTALL_EMAIL_SENDER:$INSTALL_EMAIL_SENDER_PSW
				EOF

				sudo chmod 400 /etc/postfix/sasl_passwd
				sudo postmap /etc/postfix/sasl_passwd
				sudo systemctl enable --now postfix
			fi
		else
			echo "Add the following lines to /etc/postfix/main.cf"
			echo "relayhost = [$INSTALL_EMAIL_RELAY_HOST]:$INSTALL_EMAIL_RELAY_HOST_PORT"
			echo "smtp_sasl_auth_enable = yes"
			echo "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
			echo "smtp_sasl_security_options = noanonymous"
			echo "smtp_tls_CApath = /etc/ssl/certs"
			echo "smtpd_tls_CApath = /etc/ssl/certs"
			echo "smtp_use_tls = yes"
			echo ""
			echo "Add the following line to /etc/postfix/sasl_passwd"
			echo "[$INSTALL_EMAIL_RELAY_HOST]:$INSTALL_EMAIL_RELAY_HOST_PORT    $INSTALL_EMAIL_SENDER:$INSTALL_EMAIL_SENDER_PSW"
			echo ""
			echo "Execute the following commands:"
			echo "sudo chmod 400 /etc/postfix/sasl_passwd"
			echo "sudo postmap /etc/postfix/sasl_passwd"
			echo "sudo systemctl enable postfix"
		fi
	elif [[ "$INSTALL_EMAIL_ENABLE" =~ ^([nN][oO]|[nN])$ ]]; then
		INSTALL_EMAIL_SENDER="none"
		INSTALL_EMAIL_RECIPIENT="none"
		INSTALL_EMAIL_UPDATE="0"
		INSTALL_EMAIL_START="0"
		INSTALL_EMAIL_STOP="0"
		INSTALL_EMAIL_CRASH="0"
	fi

	echo "Writing configuration file..."
	echo 'email_sender='"$INSTALL_EMAIL_SENDER" >> /srv/$SERVICE_NAME/config/$SERVICE_NAME-email.conf
	echo 'email_recipient='"$INSTALL_EMAIL_RECIPIENT" >> /srv/$SERVICE_NAME/config/$SERVICE_NAME-email.conf
	echo 'email_update='"$INSTALL_EMAIL_UPDATE" >> /srv/$SERVICE_NAME/config/$SERVICE_NAME-email.conf
	echo 'email_start='"$INSTALL_EMAIL_START" >> /srv/$SERVICE_NAME/config/$SERVICE_NAME-email.conf
	echo 'email_stop='"$INSTALL_EMAIL_STOP" >> /srv/$SERVICE_NAME/config/$SERVICE_NAME-email.conf
	echo 'email_crash='"$INSTALL_EMAIL_CRASH" >> /srv/$SERVICE_NAME/config/$SERVICE_NAME-email.conf
	chown $SERVICE_NAME /srv/$SERVICE_NAME/config/$SERVICE_NAME-email.conf
	echo "Done"
}

#---------------------------

#Configures the script
script_config_script() {
	echo -e "${CYAN}Script configuration${NC}"
	echo -e ""
	echo -e "The $SERVICE_NAME user's home directory is located in /srv/$SERVICE_NAME and all files are located there."
	echo -e "This configuration installation will only install the essential configuration. Discord or email."
	echo -e "Default configuration will be applied and it can work without it. You can run the optional configuration for each using the"
	echo -e "following arguments with the script:"
	echo -e ""
	echo -e "${GREEN}config_discord ${RED}- ${GREEN}Configures discord integration.${NC}"
	echo -e "${GREEN}config_email   ${RED}- ${GREEN}Configures email integration. Due to postfix configuration files being in /etc this has to be executed as root.${NC}"
	echo -e ""
	echo -e ""
	read -p "Press any key to continue" -n 1 -s -r
	echo ""

	echo "Enable services"

	systemctl --user enable $SERVICE_NAME@01.service
	systemctl --user enable --now $SERVICE_NAME-timer-1.timer
	systemctl --user enable --now $SERVICE_NAME-timer-2.timer
	echo "$SERVICE_NAME@01.service" > $CONFIG_DIR/$SERVICE_NAME-server-list.txt

	echo "Writing config files"

	if [ -f "$CONFIG_DIR/$SERVICE_NAME-script.conf" ]; then
		rm $CONFIG_DIR/$SERVICE_NAME-script.conf
	fi

	echo "Creating server files for server 01"

	mkdir /srv/$SERVICE_NAME/server-01
	mkdir /srv/$SERVICE_NAME/server-01/{libraries,plugins}

	touch mkdir /srv/$SERVICE_NAME/server-01/config.json

	cat >> /srv/$SERVICE_NAME/server-01/config.json <<- EOF
	{
		"Server": {
			"PublicIp": "0.0.0.0",
			"PublicPort": 0,
			"ListenIp": "0.0.0.0",
			"ListenPort": 0
		},
		"AntiCheat": {
			"Enabled": false,
			"BanIpFromGame": false
		}
	}
	EOF

	touch $CONFIG_DIR/$SERVICE_NAME-script.conf
	echo 'script_bckp_delold=14' >> $CONFIG_DIR/$SERVICE_NAME-script.conf
	echo 'script_log_delold=7' >> $CONFIG_DIR/$SERVICE_NAME-script.conf
	echo 'script_update_ignore_failed_startups=0' >> $CONFIG_DIR/$SERVICE_NAME-script.conf

	echo "Configuration complete"
	echo "For any settings you'll want to change, edit the files located in $CONFIG_DIR/"
	echo "To enable additional fuctions like steam, discord, email and tmpfs execute the script with the help argument."
}

#---------------------------

#Do not allow for another instance of this script to run to prevent data loss
if [[ "send_notification_start_initialized" != "$1" ]] && [[ "send_notification_start_complete" != "$1" ]] && [[ "send_notification_stop_initialized" != "$1" ]] && [[ "send_notification_stop_complete" != "$1" ]] && [[ "send_notification_crash" != "$1" ]] && [[ "move_wine_log" != "$1" ]] && [[ "server_tmux_install" != "$1" ]] && [[ "attach" != "$1" ]] && [[ "status" != "$1" ]]; then
	SCRIPT_PID_CHECK=$(basename -- "$0")
	if pidof -x "$SCRIPT_PID_CHECK" -o $$ > /dev/null; then
		echo "An another instance of this script is already running, please clear all the sessions of this script before starting a new session"
		exit 2
	fi
fi

#---------------------------

#Check what user is executing the script and allow root to execute certain functions.
if [[ "$EUID" != "$(id -u $SERVICE_NAME)" ]] && [[ "config_email" != "$1" ]] && [[ "config_tmpfs" != "$1" ]]; then
	echo "This script is only able to be executed by the $SERVICE_NAME user."
	echo "The following functions can also be executed as root: config_email, config_tmpfs"
	exit 3
fi

#---------------------------

#Script help page
case "$1" in
	help)
		echo -e "${CYAN}Time: $(date +"%Y-%m-%d %H:%M:%S") ${NC}"
		echo -e "${CYAN}$NAME server script by 7thCore${NC}"
		echo "Version: $VERSION"
		echo ""
		echo "Basic script commands:"
		echo -e "${GREEN}diag   ${RED}- ${GREEN}Prints out package versions and if script files are installed.${NC}"
		echo -e "${GREEN}status ${RED}- ${GREEN}Display status of server.${NC}"
		echo ""
		echo "Configuration and installation:"
		echo -e "${GREEN}config_script  ${RED}- ${GREEN}Configures the script, enables the systemd services and installs the wine prefix.${NC}"
		echo -e "${GREEN}config_discord ${RED}- ${GREEN}Configures discord integration.${NC}"
		echo -e "${GREEN}config_email   ${RED}- ${GREEN}Configures email integration. Due to postfix configuration files being in /etc this has to be executed as root.${NC}"
		echo ""
		echo "Server services managment:"
		echo -e "${GREEN}add_server                      ${RED}- ${GREEN}Adds a server instance.${NC}"
		echo -e "${GREEN}remove_server                   ${RED}- ${GREEN}Removes a server instance.${NC}"
		echo -e "${GREEN}enable_services <server number> ${RED}- ${GREEN}Enables all services dependant on the configuration file of the script.${NC}"
		echo -e "${GREEN}disable_services                ${RED}- ${GREEN}Disables all services. The server and the script will not start up on boot anymore.${NC}"
		echo -e "${GREEN}reload_services                 ${RED}- ${GREEN}Reloads all services, dependant on the configuration file.${NC}"
		echo ""
		echo "Server and console managment:"
		echo -e "${GREEN}start <server number>           ${RED}- ${GREEN}Start the server. If the server number is not specified the function will start all servers.${NC}"
		echo -e "${GREEN}start_no_err <server number>    ${RED}- ${GREEN}Start the server but don't require confimation if in failed state.${NC}"
		echo -e "${GREEN}stop <server number>            ${RED}- ${GREEN}Stop the server. If the server number is not specified the function will stop all servers.${NC}"
		echo -e "${GREEN}restart <server number>         ${RED}- ${GREEN}Restart the server. If the server number is not specified the function will restart all servers.${NC}"
		echo -e "${GREEN}attach <server number>          ${RED}- ${GREEN}Attaches to the tmux session of the specified server.${NC}"
		echo ""
		echo "Backup managment:"
		echo -e "${GREEN}backup        ${RED}- ${GREEN}Backup files, if server running or not.${NC}"
		echo -e "${GREEN}autobackup    ${RED}- ${GREEN}Automaticly backup files when server running.${NC}"
		echo -e "${GREEN}delete_backup ${RED}- ${GREEN}Delete old backups.${NC}"
		echo ""
		;;
#---------------------------
#Basic script functions
	diag)
		script_diagnostics
		;;
	status)
		script_status
		;;
#---------------------------
#Configuration and installation
	config_script)
		script_config_script
		;;
	config_discord)
		script_config_discord
		;;
	config_email)
		script_config_email
		;;
#---------------------------
#Server services managment
	add_server)
		script_add_server
		;;
	remove_server)
		script_remove_server
		;;
	enable_services)
		script_enable_services_manual
		;;
	disable_services)
		script_disable_services_manual
		;;
	reload_services)
		script_reload_services
		;;
#---------------------------
#Server and console managment
	start)
		script_start $2
		;;
	start_no_err)
		script_start_ignore_errors $2
		;;
	stop)
		script_stop $2
		;;
	restart)
		script_restart $2
		;;
	attach)
		script_attach $2
		;;
#---------------------------
#Backup managment
	backup)
		script_backup
		;;
	autobackup)
		script_autobackup
		;;
	delete_backup)
		script_deloldbackup
		;;
#---------------------------
#Hidden functions meant for systemd service use
	send_notification_start_initialized)
		script_send_notification_start_initialized $2
		;;
	send_notification_start_complete)
		script_send_notification_start_complete $2
		;;
	send_notification_stop_initialized)
		script_send_notification_stop_initialized $2
		;;
	send_notification_stop_complete)
		script_send_notification_stop_complete $2
		;;
	send_notification_crash)
		script_send_notification_crash $2
		;;
	server_tmux_install)
		script_server_tmux_install $2 $3
		;;
	timer_one)
		script_timer_one
		;;
	timer_two)
		script_timer_two
		;;
	*)
#---------------------------
#General output if the script does not recognise the argument provided
	echo -e "${CYAN}Time: $(date +"%Y-%m-%d %H:%M:%S") ${NC}"
	echo -e "${CYAN}$NAME server script by 7thCore${NC}"
	echo ""
	echo "For more detailed information, execute the script with the -help argument"
	echo ""
	echo -e "${GREEN}Basic script commands${RED}: ${GREEN}help, diag, status${NC}"
	echo -e "${GREEN}Configuration and installation${RED}: ${GREEN}config_script, config_discord, config_email, ${NC}"
	echo -e "${GREEN}Server services managment${RED}: ${GREEN}add_server, remove_server, enable_services, disable_services, reload_services${NC}"
	echo -e "${GREEN}Server and console managment${RED}: ${GREEN}start, start_no_err, stop,restart, attach${NC}"
	echo -e "${GREEN}Backup managment${RED}: ${GREEN}backup, autobackup, delete_backup${NC}"
	exit 1
	;;
esac

exit 0
