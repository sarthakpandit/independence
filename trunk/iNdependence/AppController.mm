/*
 *  AppController.mm
 *  iNdependence
 *
 *  Created by The Operator on 23/08/07.
 *  Copyright 2007 The Operator. All rights reserved.
 *
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License version 2, as published by the Free Software Foundation.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * See the GNU General Public License version 2 for more details
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#import "AppController.h"
#import "MainWindow.h"
#import "SSHHandler.h"
#include "PhoneInteraction/UtilityFunctions.h"
#include "PhoneInteraction/PhoneInteraction.h"
#include "PhoneInteraction/SSHHelper.h"


enum
{
	MENU_ITEM_ACTIVATE = 12,
	MENU_ITEM_DEACTIVATE = 13,
	MENU_ITEM_RETURN_TO_JAIL = 14,
	MENU_ITEM_JAILBREAK = 15,
	MENU_ITEM_INSTALL_SIM_UNLOCK = 16,
	MENU_ITEM_INSTALL_SSH = 17,
	MENU_ITEM_CHANGE_PASSWORD = 18,
	MENU_ITEM_REMOVE_SIM_UNLOCK = 19,
	MENU_ITEM_ENTER_DFU_MODE = 20,
	MENU_ITEM_REMOVE_SSH = 21,
	MENU_ITEM_PRE_111 = 22,
	MENU_ITEM_POST_111 = 23
};

extern MainWindow *g_mainWindow;
static AppController *g_appController;

static void updateStatus(const char *msg, bool waiting)
{
	
	if (g_mainWindow) {
		[g_mainWindow setStatus:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding] spinning:waiting];
	}
	
}

static void phoneInteractionNotification(int type, const char *msg)
{
	
	if (g_mainWindow) {
		
		switch (type) {
			case NOTIFY_CONNECTED:
				[g_appController setConnected:true];
				break;
			case NOTIFY_DISCONNECTED:
				[g_appController setConnected:false];
				break;
			case NOTIFY_AFC_CONNECTED:
				[g_appController setAFCConnected:true];
				break;
			case NOTIFY_AFC_DISCONNECTED:
				[g_appController setAFCConnected:false];
				break;
			case NOTIFY_INITIALIZATION_FAILED:
				[g_mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				[NSApp terminate:g_appController];
				break;
			case NOTIFY_CONNECTION_FAILED:
				[g_mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_AFC_CONNECTION_FAILED:
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_ACTIVATION_SUCCESS:
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Success" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_DEACTIVATION_SUCCESS:
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Success" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_JAILBREAK_SUCCESS:
				[g_mainWindow endDisplayWaitingSheet];
				[g_appController setPerformingJailbreak:false];
				[g_mainWindow updateStatus];

				if ([g_appController isWaitingForActivation]) {
					[g_appController activateStageTwo];
				}
				else if ([g_appController isWaitingForDeactivation]) {
					[g_appController deactivateStageTwo];
				}
				else {
					[g_mainWindow displayAlert:@"Success" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				}

				break;
			case NOTIFY_JAILRETURN_SUCCESS:
				[g_mainWindow endDisplayWaitingSheet];
				[g_appController setReturningToJail:false];
				[g_mainWindow updateStatus];

				if ([g_appController isWaitingForActivation]) {
					[g_appController activateStageThree];
				}
				else if ([g_appController isWaitingForDeactivation]) {
					[g_appController deactivateStageThree];
				}
				else {
					[g_mainWindow displayAlert:@"Success" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				}

				break;
			case NOTIFY_DFU_SUCCESS:
				[g_mainWindow endDisplayWaitingSheet];
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Success" message:@"Your phone is now in DFU mode and is ready for you to downgrade."];
				break;
			case NOTIFY_JAILBREAK_FAILED:
				[g_mainWindow endDisplayWaitingSheet];
				[g_appController setPerformingJailbreak:false];
				[g_mainWindow updateStatus];

				if ([g_appController isWaitingForActivation]) {
					[g_appController activationFailed:msg];
				}
				else if ([g_appController isWaitingForDeactivation]) {
					[g_appController deactivationFailed:msg];
				}
				else {
					[g_mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				}

				break;
			case NOTIFY_JAILRETURN_FAILED:
				[g_mainWindow endDisplayWaitingSheet];
				[g_appController setReturningToJail:false];
				[g_mainWindow updateStatus];

				if ([g_appController isWaitingForActivation]) {
					[g_appController activationFailed:msg];
				}
				else if ([g_appController isWaitingForDeactivation]) {
					[g_appController deactivationFailed:msg];
				}
				else {
					[g_mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				}

				break;
			case NOTIFY_DFU_FAILED:
				[g_mainWindow endDisplayWaitingSheet];
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_ACTIVATION_FAILED:
			case NOTIFY_PUTSERVICES_FAILED:
			case NOTIFY_PUTFSTAB_FAILED:
			case NOTIFY_DEACTIVATION_FAILED:
			case NOTIFY_PUTPEM_FAILED:
			case NOTIFY_GET_ACTIVATION_FAILED:
			case NOTIFY_PUTFILE_FAILED:
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_GET_ACTIVATION_SUCCESS:
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Success" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_NEW_JAILBREAK_STAGE_ONE_WAIT:
				[g_mainWindow endDisplayWaitingSheet];
				[g_mainWindow startDisplayWaitingSheet:nil
											   message:@"Please press and hold the Home + Sleep buttons for 3 seconds, then power off your phone, then press Sleep again to restart it."
												 image:[NSImage imageNamed:@"home_sleep_buttons"] cancelButton:false runModal:false];
				break;
			case NOTIFY_NEW_JAILBREAK_STAGE_TWO_WAIT:
				[g_mainWindow endDisplayWaitingSheet];
				[g_mainWindow startDisplayWaitingSheet:nil
											   message:@"Please reboot your phone again using the same steps..."
												 image:[NSImage imageNamed:@"home_sleep_buttons"] cancelButton:false runModal:false];
				break;
			case NOTIFY_JAILBREAK_RECOVERY_WAIT:
				[g_mainWindow startDisplayWaitingSheet:nil message:@"Waiting for jail break..." image:[NSImage imageNamed:@"jailbreak"] cancelButton:false runModal:false];
				break;
			case NOTIFY_JAILRETURN_RECOVERY_WAIT:
				[g_mainWindow startDisplayWaitingSheet:nil message:@"Waiting for return to jail..." image:[NSImage imageNamed:@"jailbreak"] cancelButton:false runModal:false];
				break;
			case NOTIFY_DFU_RECOVERY_WAIT:
				[g_mainWindow startDisplayWaitingSheet:nil message:@"Waiting to enter DFU mode..." image:nil cancelButton:false runModal:false];
				break;
			case NOTIFY_RECOVERY_CONNECTED:
				[g_appController setRecoveryMode:true];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_RECOVERY_DISCONNECTED:
				[g_appController setRecoveryMode:false];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_RESTORE_CONNECTED:
				[g_appController setRestoreMode:true];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_RESTORE_DISCONNECTED:
				[g_appController setRestoreMode:false];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_DFU_CONNECTED:
				[g_appController setDFUMode:true];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_DFU_DISCONNECTED:
				[g_appController setDFUMode:false];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_JAILBREAK_CANCEL:
				[g_mainWindow endDisplayWaitingSheet];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_CONNECTION_SUCCESS:
			case NOTIFY_AFC_CONNECTION_SUCCESS:
			case NOTIFY_INITIALIZATION_SUCCESS:
			case NOTIFY_PUTFSTAB_SUCCESS:
			case NOTIFY_PUTSERVICES_SUCCESS:
			case NOTIFY_PUTPEM_SUCCESS:
			default:
				break;
		}
		
	}
	
}

@implementation AppController

- (void)dealloc
{
	
	if (m_phoneInteraction != NULL) {
		delete m_phoneInteraction;
	}

	if (m_sshPath != NULL) {
		free(m_sshPath);
	}

	[super dealloc];
}

- (void)awakeFromNib
{
	g_appController = self;

	if (!g_mainWindow) {
		g_mainWindow = mainWindow;
	}

	m_connected = false;
	m_afcConnected = false;
	m_recoveryMode = false;
	m_restoreMode = false;
	m_dfuMode = false;
	m_jailbroken = false;
	m_activated = false;
	m_performingJailbreak = false;
	m_returningToJail = false;
	m_installingSSH = false;
	m_waitingForActivation = false;
	m_waitingForDeactivation = false;
	m_bootCount = 0;
	m_sshPath = NULL;
	[customizeBrowser setEnabled:NO];
	m_phoneInteraction = PhoneInteraction::getInstance(updateStatus, phoneInteractionNotification);
}

- (void)setConnected:(bool)connected
{
	m_connected = connected;
	
	if (m_connected) {
		[self setAFCConnected:m_phoneInteraction->isConnectedToAFC()];
		[self setActivated:m_phoneInteraction->isPhoneActivated()];
		[self setJailbroken:m_phoneInteraction->isPhoneJailbroken()];

		if ([self isAFCConnected]) {

			if ([self isActivated]) {
				[activateButton setEnabled:NO];
				[deactivateButton setEnabled:YES];
			}
			else {
				[activateButton setEnabled:YES];
				[deactivateButton setEnabled:NO];
			}

		}
		else {
			[activateButton setEnabled:NO];
			[deactivateButton setEnabled:NO];
		}

		[enterDFUModeButton setEnabled:YES];

		if (m_installingSSH) {
			m_bootCount++;
			[mainWindow endDisplayWaitingSheet];

			if (m_bootCount < 2) {
				[mainWindow startDisplayWaitingSheet:nil
											 message:@"Please reboot your phone again using the same steps..."
											   image:[NSImage imageNamed:@"home_sleep_buttons"] cancelButton:true runModal:false];
			}
			else {
				[self finishInstallingSSH:false];
			}

		}
		
	}
	else {
		[self setAFCConnected:false];
		[self setActivated:false];
		[self setJailbroken:false];

		[activateButton setEnabled:NO];
		[deactivateButton setEnabled:NO];
		[enterDFUModeButton setEnabled:NO];
	}
	
	[mainWindow updateStatus];
}

- (bool)isConnected
{
	return m_connected;
}

- (void)setAFCConnected:(bool)connected
{
	m_afcConnected = connected;

	if (m_afcConnected) {

		if ([self isActivated]) {
			[activateButton setEnabled:NO];
			[deactivateButton setEnabled:YES];
		}
		else {
			[activateButton setEnabled:YES];
			[deactivateButton setEnabled:NO];
		}

		if ([self isJailbroken]) {
			[jailbreakButton setEnabled:NO];

			if ([self isUsing10xFirmware]) {
				[returnToJailButton setEnabled:YES];
			}
			else {
				[returnToJailButton setEnabled:NO];
			}

		}
		else {
			[jailbreakButton setEnabled:YES];
			[returnToJailButton setEnabled:NO];
		}
		
	}
	else {
		[activateButton setEnabled:NO];
		[deactivateButton setEnabled:NO];
		[jailbreakButton setEnabled:NO];
		[returnToJailButton setEnabled:NO];
	}

	[mainWindow updateStatus];
}

- (bool)isAFCConnected
{
	return m_afcConnected;
}

- (void)setRecoveryMode:(bool)inRecovery
{
	m_recoveryMode = inRecovery;
	[mainWindow updateStatus];
}

- (bool)isInRecoveryMode
{
	return m_recoveryMode;
}

- (void)setRestoreMode:(bool)inRestore
{
	m_restoreMode = inRestore;
	[mainWindow updateStatus];
}

- (bool)isInRestoreMode
{
	return m_restoreMode;
}

- (void)setDFUMode:(bool)inDFU
{
	m_dfuMode = inDFU;
	[mainWindow updateStatus];
}

- (bool)isInDFUMode
{
	return m_dfuMode;
}

- (void)setJailbroken:(bool)jailbroken
{
	m_jailbroken = jailbroken;
	
	if (m_jailbroken) {

		if ([self isUsing10xFirmware]) {
			[returnToJailButton setEnabled:YES];
		}
		else {
			[returnToJailButton setEnabled:NO];
		}

		[changePasswordButton setEnabled:YES];
		[customizeBrowser setEnabled:YES];
		[jailbreakButton setEnabled:NO];
		
		if ([self isSSHInstalled]) {
			[installSSHButton setEnabled:NO];
			[removeSSHButton setEnabled:YES];

			if ([self isUsing10xFirmware]) {

				if (!m_phoneInteraction->fileExists("/var/root/Media.backup")) {
					[pre111UpgradeButton setEnabled:YES];
				}
				else {
					[pre111UpgradeButton setEnabled:NO];
				}

				[post111UpgradeButton setEnabled:NO];
			}
			else {
				[pre111UpgradeButton setEnabled:NO];

				if (m_phoneInteraction->fileExists("/var/root/Media.backup")) {
					[post111UpgradeButton setEnabled:YES];
				}
				else {
					[post111UpgradeButton setEnabled:NO];
				}

			}

			if ([self isanySIMInstalled]) {
				[installSimUnlockButton setEnabled:NO];
				[removeSimUnlockButton setEnabled:YES];
			}
			else {
				[installSimUnlockButton setEnabled:YES];
				[removeSimUnlockButton setEnabled:NO];
			}

		}
		else {
			[installSSHButton setEnabled:YES];
			[removeSSHButton setEnabled:NO];
			[installSimUnlockButton setEnabled:NO];
			[removeSimUnlockButton setEnabled:NO];
		}

	}
	else {
		[returnToJailButton setEnabled:NO];
		[installSSHButton setEnabled:NO];
		[removeSSHButton setEnabled:NO];
		[installSimUnlockButton setEnabled:NO];
		[removeSimUnlockButton setEnabled:NO];
		[changePasswordButton setEnabled:NO];
		[customizeBrowser setEnabled:NO];
		[pre111UpgradeButton setEnabled:NO];
		[post111UpgradeButton setEnabled:NO];

		if ([self isConnected] && [self isAFCConnected]) {
			[jailbreakButton setEnabled:YES];
		}
		else {
			[jailbreakButton setEnabled:NO];
		}
		
	}
	
	[mainWindow updateStatus];
}

- (bool)isJailbroken
{
	return m_jailbroken;
}

- (void)setActivated:(bool)activated
{
	m_activated = activated;

	if (m_activated) {

		if ([self isJailbroken]) {
			[activateButton setEnabled:NO];
			[deactivateButton setEnabled:YES];
		}

	}
	else {

		if ([self isJailbroken]) {
			[activateButton setEnabled:YES];
			[deactivateButton setEnabled:NO];
		}

	}

	[mainWindow updateStatus];
}

- (bool)isActivated
{
	return m_activated;
}

- (bool)isSSHInstalled
{
	return m_phoneInteraction->fileExists("/usr/bin/dropbear");
}

- (bool)isanySIMInstalled
{
	return m_phoneInteraction->applicationExists("anySIM.app");
}

- (NSString*)phoneFirmwareVersion
{
	return [NSString stringWithCString:m_phoneInteraction->getPhoneProductVersion() encoding:NSUTF8StringEncoding];
}

- (bool)isUsing10xFirmware
{
	char *value = m_phoneInteraction->getPhoneProductVersion();

	if (!strncmp(value, "1.0", 3)) {
		return true;
	}

	return false;
}

- (void)setPerformingJailbreak:(bool)bJailbreaking
{
	m_performingJailbreak = bJailbreaking;
}

- (void)setReturningToJail:(bool)bReturning
{
	m_returningToJail = bReturning;
}

- (bool)isWaitingForActivation
{
	return m_waitingForActivation;
}

- (bool)isWaitingForDeactivation
{
	return m_waitingForDeactivation;
}

- (IBAction)performJailbreak:(id)sender
{

	if ([self isUsing10xFirmware]) {
		NSString *firmwarePath = nil;

		// first things first -- get the path to the unzipped firmware files
		NSOpenPanel *firmwareOpener = [NSOpenPanel openPanel];
		[firmwareOpener setTitle:@"Select where you unzipped the firmware files"];
		[firmwareOpener setCanChooseDirectories:YES];
		[firmwareOpener setCanChooseFiles:NO];
		[firmwareOpener setAllowsMultipleSelection:NO];

		while (1) {

			if ([firmwareOpener runModalForTypes:nil] != NSOKButton) {
				return;
			}

			firmwarePath = [firmwareOpener filename];

			if ([[NSFileManager defaultManager] fileExistsAtPath:[firmwarePath stringByAppendingString:@"/Restore.plist"]]) {
				break;
			}

			[mainWindow displayAlert:@"Error" message:@"Specified path does not contain firmware files.  Try again."];
			return;
		}

		NSString *servicesFile = [[NSBundle mainBundle] pathForResource:@"Services_mod" ofType:@"plist"];
	
		if (servicesFile == nil) {
			[mainWindow displayAlert:@"Error" message:@"Error finding modified Services.plist file."];
			return;
		}

		NSString *fstabFile = [[NSBundle mainBundle] pathForResource:@"fstab_mod" ofType:@""];
		
		if (fstabFile == nil) {
			[mainWindow displayAlert:@"Error" message:@"Error finding modified fstab file."];
			return;
		}

		m_performingJailbreak = true;
		m_phoneInteraction->performJailbreak([firmwarePath UTF8String], [fstabFile UTF8String],
											 [servicesFile UTF8String]);
	}
	else {
		NSString *servicesFile = [[NSBundle mainBundle] pathForResource:@"Services111_mod" ofType:@"plist"];
		
		if (servicesFile == nil) {
			[mainWindow displayAlert:@"Error" message:@"Error finding modified Services.plist file."];
			return;
		}
		
		m_performingJailbreak = true;
		m_phoneInteraction->performNewJailbreak([servicesFile UTF8String]);
	}

}

- (IBAction)returnToJail:(id)sender
{
	[mainWindow setStatus:@"Returning to jail..." spinning:true];

	NSString *servicesFile = nil;

	if ([self isUsing10xFirmware]) {
		servicesFile = [[NSBundle mainBundle] pathForResource:@"Services" ofType:@"plist"];
	}
	else {
		servicesFile = [[NSBundle mainBundle] pathForResource:@"Services111" ofType:@"plist"];
	}

	if (servicesFile == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error finding Services.plist file."];
		[mainWindow updateStatus];
		return;
	}

	NSString *fstabFile = [[NSBundle mainBundle] pathForResource:@"fstab" ofType:@""];

	if (fstabFile == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error finding fstab file."];
		[mainWindow updateStatus];
		return;
	}

	m_returningToJail = true;
	m_phoneInteraction->returnToJail([servicesFile UTF8String], [fstabFile UTF8String]);
}

- (IBAction)enterDFUMode:(id)sender
{
	NSString *firmwarePath;
	
	// first things first -- get the path to the unzipped firmware files
	NSOpenPanel *firmwareOpener = [NSOpenPanel openPanel];
	[firmwareOpener setTitle:@"Select where you unzipped the firmware files"];
	[firmwareOpener setCanChooseDirectories:YES];
	[firmwareOpener setCanChooseFiles:NO];
	[firmwareOpener setAllowsMultipleSelection:NO];
	
	while (1) {
		
		if ([firmwareOpener runModalForTypes:nil] != NSOKButton) {
			return;
		}
		
		firmwarePath = [firmwareOpener filename];
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:[firmwarePath stringByAppendingString:@"/Restore.plist"]]) {
			break;
		}
		
		[mainWindow displayAlert:@"Error" message:@"Specified path does not contain firmware files.  Try again."];
		return;
	}
	
	m_phoneInteraction->enterDFUMode([firmwarePath UTF8String]);
}

- (IBAction)pre111Upgrade:(id)sender
{

	if (m_phoneInteraction->fileExists("/var/root/Media.backup")) {
		[mainWindow displayAlert:@"Already done" message:@"It appears that you have already performed the pre-1.1.1 operation.  If this is not the case, then remove the /var/root/Media.backup directory from your phone using SSH/SFTP and try again."];
		return;
	}

	bool bCancelled = false;
	NSString *ipAddress, *password;
	
	if ([sshHandler getSSHInfo:&ipAddress password:&password wasCancelled:&bCancelled] == false) {
		return;
	}
	
	if (bCancelled) {
		return;
	}

	[mainWindow displayAlert:@"Open iTunes" message:@"Please open iTunes now and ensure that it is connected to your phone.\n\nIf you see the \"Set Up Your iPhone\" screen, then set it up accordingly before you proceed.\n\nOnce you are done and the iPhone is connected to iTunes again, press the OK button to proceed."];

	bool done = false;
	int retval;
	
	while (!done) {
		[mainWindow startDisplayWaitingSheet:@"Performing Pre-1.1.1 Upgrade" message:@"Performing pre-1.1.1 operations..." image:nil
								cancelButton:false runModal:false];
		retval = SSHHelper::symlinkMediaToRoot([ipAddress UTF8String], [password UTF8String]);
		[mainWindow endDisplayWaitingSheet];

		if (retval != SSH_HELPER_SUCCESS) {

			switch (retval)
			{
				case SSH_HELPER_ERROR_NO_RESPONSE:
					[mainWindow displayAlert:@"Failed" message:@"Couldn't connect to SSH server.  Ensure IP address is correct, phone is connected to a network, and SSH is installed correctly."];
					done = true;
					break;
				case SSH_HELPER_ERROR_BAD_PASSWORD:
					[mainWindow displayAlert:@"Failed" message:@"root password is incorrect."];
					done = true;
					break;
				case SSH_HELPER_VERIFICATION_FAILED:
					int retval = NSRunAlertPanel(@"Failed", @"Host verification failed.  Would you like iNdependence to try and fix this for you by editing ~/.ssh/known_hosts?", @"No", @"Yes", nil);

					if (retval == NSAlertAlternateReturn) {
						
						if (![sshHandler removeKnownHostsEntry:ipAddress]) {
							[mainWindow displayAlert:@"Failed" message:@"Couldn't remove entry from ~/.ssh/known_hosts.  Please edit that file by hand and remove the line containing your phone's IP address."];
							done = true;
						}
						
					}
					else {
						done = true;
					}

					break;
				default:
					[mainWindow displayAlert:@"Failed" message:@"Error performing pre-1.1.1 operations."];
					done = true;
					break;
			}

		}
		else {
			done = true;
		}

	}

	[pre111UpgradeButton setEnabled:false];
	[mainWindow displayAlert:@"Success" message:@"Your phone is now ready to be upgraded to 1.1.1.\n\nPlease quit iNdependence, then use iTunes to do this now.\n\nEnsure that you choose 'Update' and not 'Restore' in iTunes."];
}

- (IBAction)post111Upgrade:(id)sender
{
	
	if (!m_phoneInteraction->fileExists("/var/root/Media.backup")) {
		[mainWindow displayAlert:@"Error" message:@"/var/root/Media.backup does not exist on your phone so you cannot perform this operation."];
		return;
	}
	
	bool bCancelled = false;
	NSString *ipAddress, *password;
	
	if ([sshHandler getSSHInfo:&ipAddress password:&password wasCancelled:&bCancelled] == false) {
		return;
	}
	
	if (bCancelled) {
		return;
	}

	bool done = false;
	int retval;
	
	while (!done) {
		[mainWindow startDisplayWaitingSheet:@"Performing Post-1.1.1 Upgrade" message:@"Performing post-1.1.1 operations..." image:nil
								cancelButton:false runModal:false];
		retval = SSHHelper::removeMediaSymlink([ipAddress UTF8String], [password UTF8String]);
		[mainWindow endDisplayWaitingSheet];
		
		if (retval != SSH_HELPER_SUCCESS) {
			
			switch (retval)
			{
				case SSH_HELPER_ERROR_NO_RESPONSE:
					[mainWindow displayAlert:@"Failed" message:@"Couldn't connect to SSH server.  Ensure IP address is correct, phone is connected to a network, and SSH is installed correctly."];
					done = true;
					break;
				case SSH_HELPER_ERROR_BAD_PASSWORD:
					[mainWindow displayAlert:@"Failed" message:@"root password is incorrect."];
					done = true;
					break;
				case SSH_HELPER_VERIFICATION_FAILED:
					int retval = NSRunAlertPanel(@"Failed", @"Host verification failed.  Would you like iNdependence to try and fix this for you by editing ~/.ssh/known_hosts?", @"No", @"Yes", nil);
					
					if (retval == NSAlertAlternateReturn) {
						
						if (![sshHandler removeKnownHostsEntry:ipAddress]) {
							[mainWindow displayAlert:@"Failed" message:@"Couldn't remove entry from ~/.ssh/known_hosts.  Please edit that file by hand and remove the line containing your phone's IP address."];
							done = true;
						}
						
					}
						else {
							done = true;
						}
						
						break;
				default:
					[mainWindow displayAlert:@"Failed" message:@"Error performing post-1.1.1 operations."];
					done = true;
					break;
			}
			
		}
		else {
			done = true;
		}
		
	}

	[post111UpgradeButton setEnabled:false];
	[mainWindow displayAlert:@"Success" message:@"You've successfully performed the post-1.1.1 operations."];
}

- (IBAction)installSimUnlock:(id)sender
{
	bool bCancelled = false;
	NSString *ipAddress, *password;

	if ([sshHandler getSSHInfo:&ipAddress password:&password wasCancelled:&bCancelled] == false) {
		return;
	}

	if (bCancelled) {
		return;
	}

	NSString *simUnlockApp = [[NSBundle mainBundle] pathForResource:@"anySIM" ofType:@"app"];

	if (simUnlockApp == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error finding SIM unlock application in bundle."];
		return;
	}

	if (!m_phoneInteraction->putApplicationOnPhone([simUnlockApp UTF8String])) {
		[mainWindow displayAlert:@"Error" message:@"Couldn't put application on phone"];
		return;
	}

	NSString *appName = [NSString stringWithFormat:@"%@/%@", @"/Applications", [simUnlockApp lastPathComponent]];

	bool done = false;
	int retval;
	
	while (!done) {
		[mainWindow startDisplayWaitingSheet:@"Setting Permissions" message:@"Setting application permissions..." image:nil
								cancelButton:false runModal:false];
		retval = SSHHelper::copyPermissions([simUnlockApp UTF8String], [appName UTF8String], [ipAddress UTF8String],
											[password UTF8String]);
		[mainWindow endDisplayWaitingSheet];
		
		if (retval != SSH_HELPER_SUCCESS) {
			
			switch (retval)
			{
				case SSH_HELPER_ERROR_NO_RESPONSE:
					PhoneInteraction::getInstance()->removeApplication([[simUnlockApp lastPathComponent] UTF8String]);
					[mainWindow displayAlert:@"Failed" message:@"Couldn't connect to SSH server.  Ensure IP address is correct, phone is connected to a network, and SSH is installed correctly."];
					done = true;
					break;
				case SSH_HELPER_ERROR_BAD_PASSWORD:
					PhoneInteraction::getInstance()->removeApplication([[simUnlockApp lastPathComponent] UTF8String]);
					[mainWindow displayAlert:@"Failed" message:@"root password is incorrect."];
					done = true;
					break;
				case SSH_HELPER_VERIFICATION_FAILED:
					int retval = NSRunAlertPanel(@"Failed", @"Host verification failed.  Would you like iNdependence to try and fix this for you by editing ~/.ssh/known_hosts?", @"No", @"Yes", nil);
					
					if (retval == NSAlertAlternateReturn) {
						
						if (![sshHandler removeKnownHostsEntry:ipAddress]) {
							PhoneInteraction::getInstance()->removeApplication([[simUnlockApp lastPathComponent] UTF8String]);
							[mainWindow displayAlert:@"Failed" message:@"Couldn't remove entry from ~/.ssh/known_hosts.  Please edit that file by hand and remove the line containing your phone's IP address."];
							done = true;
						}
						
					}
					else {
						done = true;
					}

					break;
				default:
					PhoneInteraction::getInstance()->removeApplication([[simUnlockApp lastPathComponent] UTF8String]);
					[mainWindow displayAlert:@"Failed" message:@"Error setting permissions for application."];
					done = true;
					break;
			}
			
		}
		else {
			done = true;
		}
		
	}

	if ([self isanySIMInstalled]) {
		[installSimUnlockButton setEnabled:NO];
		[removeSimUnlockButton setEnabled:YES];
	}
	else {
		[installSimUnlockButton setEnabled:YES];
		[removeSimUnlockButton setEnabled:NO];
	}

	[mainWindow displayAlert:@"Success" message:@"The anySIM application should now be installed on your phone.  Simply run it and it will finish the SIM unlock process.\n\nAfter you are done, you can remove it from your phone."];
}

- (void)removeSimUnlock:(id)sender
{
	bool bCancelled = false;
	NSString *ipAddress, *password;
	
	if ([sshHandler getSSHInfo:&ipAddress password:&password wasCancelled:&bCancelled] == false) {
		return;
	}
	
	if (bCancelled) {
		return;
	}

	if (!m_phoneInteraction->removeApplication("anySIM.app")) {
		return;
	}

	if ([self isanySIMInstalled]) {
		[installSimUnlockButton setEnabled:NO];
		[removeSimUnlockButton setEnabled:YES];
	}
	else {
		[installSimUnlockButton setEnabled:YES];
		[removeSimUnlockButton setEnabled:NO];
	}
	
	bool done = false;
	int retval;
	
	while (!done) {
		[mainWindow startDisplayWaitingSheet:@"Restarting SpringBoard" message:@"Restarting SpringBoard..." image:nil
								cancelButton:false runModal:false];
		retval = SSHHelper::restartSpringboard([ipAddress UTF8String], [password UTF8String]);
		[mainWindow endDisplayWaitingSheet];

		if (retval != SSH_HELPER_SUCCESS) {
			
			switch (retval)
			{
				case SSH_HELPER_ERROR_NO_RESPONSE:
					[mainWindow displayAlert:@"Failed" message:@"Couldn't connect to SSH server.  Ensure IP address is correct, phone is connected to a network, and SSH is installed correctly."];
					done = true;
					break;
				case SSH_HELPER_ERROR_BAD_PASSWORD:
					[mainWindow displayAlert:@"Failed" message:@"root password is incorrect."];
					done = true;
					break;
				case SSH_HELPER_VERIFICATION_FAILED:
					int retval = NSRunAlertPanel(@"Failed", @"Host verification failed.  Would you like iNdependence to try and fix this for you by editing ~/.ssh/known_hosts?", @"No", @"Yes", nil);
					
					if (retval == NSAlertAlternateReturn) {
						
						if (![sshHandler removeKnownHostsEntry:ipAddress]) {
							[mainWindow displayAlert:@"Failed" message:@"Couldn't remove entry from ~/.ssh/known_hosts.  Please edit that file by hand and remove the line containing your phone's IP address."];
							done = true;
						}
						
					}
					else {
						done = true;
					}

					break;
				default:
					[mainWindow displayAlert:@"Failed" message:@"Error restarting SpringBoard."];
					done = true;
					break;
			}
			
		}
		else {
			done = true;
		}
		
	}
	
	[mainWindow displayAlert:@"Success" message:@"The anySIM application was successfully removed from your phone."];
}

- (bool)doPutPEM:(const char*)pemfile
{
	[mainWindow setStatus:@"Putting PEM file on phone..." spinning:true];
	return m_phoneInteraction->putPEMOnPhone(pemfile);
}

- (void)activateStageTwo
{
	NSString *pemfile = [[NSBundle mainBundle] pathForResource:@"iPhoneActivation" ofType:@"pem"];
	NSString *device_private_key_file = [[NSBundle mainBundle] pathForResource:@"device_private_key" ofType:@"pem"];

	if ( (pemfile == nil) || (device_private_key_file == nil) ) {
		m_waitingForActivation = false;
		[mainWindow displayAlert:@"Error" message:@"Error finding necessary files in application bundle."];
		[mainWindow updateStatus];
		return;
	}

	if (![self doPutPEM:[pemfile UTF8String]]) {
		m_waitingForActivation = false;
		return;
	}

	if (!m_phoneInteraction->putFile([device_private_key_file UTF8String], "/private/var/root/Library/Lockdown/device_private_key.pem",
									 0, 0)) {
		m_waitingForActivation = false;
		[mainWindow displayAlert:@"Error" message:@"Error writing device_private_key.pem to phone."];
		[mainWindow updateStatus];
		return;
	}

	if ([self isUsing10xFirmware]) {
		[self returnToJail:self];
	}
	else {
		[self activateStageThree];
	}

}

- (void)activateStageThree
{
	m_waitingForActivation = false;

	NSString *pemfile_priv = [[NSBundle mainBundle] pathForResource:@"iPhoneActivation_private" ofType:@"pem"];
	
	if (pemfile_priv == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error finding PEM file in application bundle."];
		[mainWindow updateStatus];
		return;
	}
	
	[mainWindow setStatus:@"Activating..." spinning:true];
	
	m_phoneInteraction->activate(NULL, [pemfile_priv UTF8String]);
}

- (void)activationFailed:(const char*)msg
{
	m_waitingForActivation = false;
	[mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
}

- (void)deactivateStageTwo
{
	[mainWindow setStatus:@"Restoring original PEM file on phone..." spinning:true];
	
	NSString *pemfile = [[NSBundle mainBundle] pathForResource:@"iPhoneActivation_original" ofType:@"pem"];
	
	if (pemfile == nil) {
		m_waitingForDeactivation = false;
		[mainWindow displayAlert:@"Error" message:@"Error finding PEM file in application bundle."];
		[mainWindow updateStatus];
		return;
	}
	
	if (![self doPutPEM:[pemfile UTF8String]]) {
		m_waitingForDeactivation = false;
		return;
	}
	
	[self returnToJail:self];
}

- (void)deactivateStageThree
{
	m_waitingForDeactivation = false;
	[mainWindow setStatus:@"Deactivating..." spinning:true];
	m_phoneInteraction->deactivate();
}

- (void)deactivationFailed:(const char*)msg
{
	m_waitingForDeactivation = false;
	[mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
}

- (IBAction)activate:(id)sender
{
	m_waitingForActivation = true;

	if (!m_phoneInteraction->isPhoneJailbroken()) {
		[self performJailbreak:sender];
		return;
	}

	[self activateStageTwo];
}

- (IBAction)deactivate:(id)sender
{
	m_waitingForDeactivation = true;

	if (!m_phoneInteraction->isPhoneJailbroken()) {
		[self performJailbreak:sender];
		return;
	}
	
	[self deactivateStageTwo];
}

- (IBAction)waitDialogCancel:(id)sender
{

	if (m_installingSSH) {
		[mainWindow endDisplayWaitingSheet];
		[self finishInstallingSSH:true];
	}
	
}

- (IBAction)changePassword:(id)sender
{
	[NSApp beginSheet:newPasswordDialog modalForWindow:mainWindow modalDelegate:nil didEndSelector:nil
		  contextInfo:nil];

	const char *accountName = NULL;
	const char *newPassword = NULL;

	while ( !accountName || !newPassword ) {

		if ([NSApp runModalForWindow:newPasswordDialog] == -1) {
			[NSApp endSheet:newPasswordDialog];
			[newPasswordDialog orderOut:self];
			return;
		}

		[NSApp endSheet:newPasswordDialog];
		[newPasswordDialog orderOut:self];

		if ([[accountNameField stringValue] length] == 0) {
			[mainWindow displayAlert:@"Error" message:@"Invalid account name.  Try again."];
			continue;
		}

		if ([[passwordField stringValue] length] == 0) {
			[mainWindow displayAlert:@"Error" message:@"Invalid password.  Try again."];
			continue;
		}

		if (![[passwordField stringValue] isEqualToString:[passwordAgainField stringValue]]) {
			[mainWindow displayAlert:@"Error" message:@"Passwords don't match.  Try again."];
			continue;
		}

		accountName = [[accountNameField stringValue] UTF8String];
		newPassword = [[passwordField stringValue] UTF8String];
	}

	int size = 0;
	char *buf, *offset;

	if (!m_phoneInteraction->getFileData((void**)&buf, &size, "/etc/master.passwd")) {
		[mainWindow displayAlert:@"Error" message:@"Error reading /etc/master.passwd from phone."];
		return;
	}

	int accountLen = strlen(accountName);
	char pattern[accountLen+2];

	strcpy(pattern, accountName);
	pattern[accountLen] = ':';
	pattern[accountLen+1] = 0;

	if ( (offset = strstr(buf, pattern)) == NULL ) {
		free(buf);
		[mainWindow displayAlert:@"Error" message:@"No such account name in master.passwd."];
		return;
	}

	char *encryptedPassword = crypt(newPassword, "XU");
	
	if (encryptedPassword == NULL) {
		free(buf);
		[mainWindow displayAlert:@"Error" message:@"Error encrypting given password."];
		return;
	}

	strncpy(offset + accountLen + 1, encryptedPassword, 13);

	if (!m_phoneInteraction->putData(buf, size, "/etc/master.passwd")) {
		free(buf);
		[mainWindow displayAlert:@"Error" message:@"Error writing to /etc/master.passwd on phone."];
		return;
	}

	free(buf);
	[mainWindow displayAlert:@"Success" message:@"Successfully changed account password."];
}

- (IBAction)passwordDialogCancel:(id)sender
{
	[NSApp stopModalWithCode:-1];
}

- (IBAction)passwordDialogOk:(id)sender
{
	[NSApp stopModalWithCode:0];
}

- (IBAction)keyGenerationOutputDismiss:(id)sender
{
	[keyGenerationOutput orderOut:self];
}

- (IBAction)installSSH:(id)sender
{

	// first generate the dropbear RSA and DSS keys
	NSString *dropbearkeyPath = [[NSBundle mainBundle] pathForResource:@"dropbearkey" ofType:@""];

	if (dropbearkeyPath == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error finding dropbearkey in bundle."];
		return;
	}

	[logOutput setString:@""];
	[keyGenerationOutput orderFront:self];

	NSString *tmpDir = NSTemporaryDirectory();
	NSMutableString *dropbearRSAFile = [NSMutableString stringWithString:tmpDir];
	[dropbearRSAFile appendString:@"/dropbear_rsa_host_key"];

	// remove old file if it exists
	remove([dropbearRSAFile UTF8String]);

	NSArray *args = [NSArray arrayWithObjects:@"-t", @"rsa", @"-f", dropbearRSAFile, nil];
	NSTask *task = [[NSTask alloc] init];
	NSPipe *pipe = [NSPipe pipe];
	NSFileHandle *readHandle = [pipe fileHandleForReading];
	NSData *inData = nil;

	[task setStandardOutput:pipe];
	[task setStandardError:pipe];
	[task setLaunchPath:dropbearkeyPath];
	[task setArguments:args];
	[task launch];

	NSTextStorage *textStore = [logOutput textStorage];
	
	// output to log window
	while ((inData = [readHandle availableData]) && [inData length]) {
		int len = [inData length];
		char buf[len+1];
		memcpy(buf, [inData bytes], len);

		if (buf[len-1] != 0) {
			buf[len] = 0;
		}

		NSAttributedString *tmpString = [[NSAttributedString alloc] initWithString:[NSString stringWithUTF8String:buf]];
		[textStore appendAttributedString:tmpString];
		[logOutput scrollRangeToVisible:NSMakeRange([textStore length]-2, 1)];
		[tmpString release];
	}

	[task waitUntilExit];

	if ([task terminationStatus] != 0) {
		[task release];
		[mainWindow displayAlert:@"Error" message:@"Error occurred while executing dropbearkey."];
		return;
	}

	[task release];

	NSMutableString *dropbearDSSFile = [NSMutableString stringWithString:tmpDir];
	[dropbearDSSFile appendString:@"/dropbear_dss_host_key"];

	// remove old file if it exists
	remove([dropbearDSSFile UTF8String]);

	args = [NSArray arrayWithObjects:@"-t", @"dss", @"-f", dropbearDSSFile, nil];
	task = [[NSTask alloc] init];
	pipe = [NSPipe pipe];
	readHandle = [pipe fileHandleForReading];

	[task setStandardOutput:pipe];
	[task setStandardError:pipe];
	[task setLaunchPath:dropbearkeyPath];
	[task setArguments:args];
	[task launch];

	// output to log window
	while ((inData = [readHandle availableData]) && [inData length]) {
		int len = [inData length];
		char buf[len+1];
		memcpy(buf, [inData bytes], len);
		
		if (buf[len-1] != 0) {
			buf[len] = 0;
		}
		
		NSAttributedString *tmpString = [[NSAttributedString alloc] initWithString:[NSString stringWithUTF8String:buf]];
		[textStore appendAttributedString:tmpString];
		[logOutput scrollRangeToVisible:NSMakeRange([textStore length]-2, 1)];
		[tmpString release];
	}

	[task waitUntilExit];

	if ([task terminationStatus] != 0) {
		[task release];
		[mainWindow displayAlert:@"Error" message:@"Error occurred while executing dropbearkey."];
		return;
	}

	[task release];

	if (!m_phoneInteraction->createDirectory("/etc/dropbear")) {
		[mainWindow displayAlert:@"Error" message:@"Error creating /etc/dropbear directory on phone."];
		return;
	}

	if (!m_phoneInteraction->putFile([dropbearRSAFile UTF8String], "/etc/dropbear/dropbear_rsa_host_key")) {
		[mainWindow displayAlert:@"Error" message:@"Error writing /etc/dropbear/dropbear_rsa_host_key to phone."];
		return;
	}

	if (!m_phoneInteraction->putFile([dropbearDSSFile UTF8String], "/etc/dropbear/dropbear_dss_host_key")) {
		[mainWindow displayAlert:@"Error" message:@"Error writing /etc/dropbear/dropbear_dss_host_key to phone."];
		return;
	}

	NSString *chmodFile = [[NSBundle mainBundle] pathForResource:@"chmod" ofType:@""];

	if (chmodFile == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error finding chmod in bundle."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([chmodFile UTF8String], "/bin/chmod")) {
		[mainWindow displayAlert:@"Error" message:@"Error writing /bin/chmod to phone."];
		return;
	}

	NSString *shFile = [[NSBundle mainBundle] pathForResource:@"sh" ofType:@""];

	if (shFile == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error finding sh in bundle."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([shFile UTF8String], "/bin/sh")) {
		[mainWindow displayAlert:@"Error" message:@"Error writing /bin/sh to phone."];
		return;
	}

	NSString *sftpFile = [[NSBundle mainBundle] pathForResource:@"sftp-server" ofType:@""];

	if (sftpFile == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error finding sftp-server in bundle."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([sftpFile UTF8String], "/usr/libexec/sftp-server")) {
		[mainWindow displayAlert:@"Error" message:@"Error writing /usr/libexec/sftp-server to phone."];
		return;
	}

	NSString *scpFile = [[NSBundle mainBundle] pathForResource:@"scp" ofType:@""];
	
	if (scpFile == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error finding scp in bundle."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([scpFile UTF8String], "/usr/bin/scp")) {
		[mainWindow displayAlert:@"Error" message:@"Error writing /usr/bin/scp to phone."];
		return;
	}
	
	NSString *libarmfpFile = [[NSBundle mainBundle] pathForResource:@"libarmfp" ofType:@"dylib"];
	
	if (libarmfpFile == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error finding libarmfp.dylib in bundle."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([libarmfpFile UTF8String], "/usr/lib/libarmfp.dylib")) {
		[mainWindow displayAlert:@"Error" message:@"Error writing /usr/lib/libarmfp.dylib to phone."];
		return;
	}
	
	NSString *dropbearFile = [[NSBundle mainBundle] pathForResource:@"dropbear" ofType:@""];
	
	if (dropbearFile == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error finding dropbear in bundle."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([dropbearFile UTF8String], "/usr/bin/dropbear")) {
		[mainWindow displayAlert:@"Error" message:@"Error writing /usr/bin/dropbear to phone."];
		return;
	}
	
	NSMutableString *tmpFilePath = [NSMutableString stringWithString:tmpDir];
	[tmpFilePath appendString:@"/update.backup.iNdependence"];

	if (!m_phoneInteraction->getFile("/usr/sbin/update", [tmpFilePath UTF8String])) {
		[mainWindow displayAlert:@"Error" message:@"Error reading /usr/sbin/update from phone."];
		return;
	}

	if (!m_phoneInteraction->putFile([chmodFile UTF8String], "/usr/sbin/update")) {
		remove([tmpFilePath UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error writing /usr/sbin/update to phone."];
		return;
	}

	NSMutableString *tmpFilePath2 = [NSMutableString stringWithString:tmpDir];
	[tmpFilePath2 appendString:@"/com.apple.update.plist.backup.iNdependence"];

	if (!m_phoneInteraction->getFile("/System/Library/LaunchDaemons/com.apple.update.plist", [tmpFilePath2 UTF8String])) {
		remove([tmpFilePath UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error reading /System/Library/LaunchDaemons/com.apple.update.plist from phone."];
		return;
	}

	int fd = open([tmpFilePath2 UTF8String], O_RDONLY, 0);

	if (fd == -1) {
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error opening com.apple.update.plist.backup.iNdependence for reading."];
		return;
	}

	struct stat st;

	if (fstat(fd, &st) == -1) {
		close(fd);
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error obtaining com.apple.update.plist.original file size."];
		return;
	}

	NSMutableString *tmpFilePath3 = [NSMutableString stringWithString:tmpDir];
	[tmpFilePath3 appendString:@"/com.apple.update.plist.iNdependence"];
	int fd2 = open([tmpFilePath3 UTF8String], O_CREAT | O_TRUNC | O_WRONLY,
				   S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);

	if (fd2 == -1) {
		close(fd);
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error opening com.apple.update.plist.iNdependence for writing."];
		return;
	}

	unsigned char buf[1024];
	int readCount = 0;

	while (readCount < st.st_size) {
		int retval = read(fd, buf, 1024);

		if (retval < 1) {
			break;
		}

		write(fd2, buf, retval);
		readCount += retval;
	}

	close(fd);
	close(fd2);

	if (readCount < st.st_size) {
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		remove([tmpFilePath3 UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error copying com.apple.update.plist."];
		return;
	}

	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:tmpFilePath3];
	NSMutableDictionary *mutDict = [NSMutableDictionary dictionaryWithCapacity:[dict count]];
	[mutDict addEntriesFromDictionary:dict];
	NSMutableArray *mutArgs = [NSMutableArray arrayWithCapacity:5];
	[mutArgs addObject:@"/usr/sbin/update"];
	[mutArgs addObject:@"555"];
	[mutArgs addObject:@"/bin/chmod"];
	[mutArgs addObject:@"/bin/sh"];
	[mutArgs addObject:@"/usr/bin/dropbear"];
	[mutArgs addObject:@"/usr/libexec/sftp-server"];
	[mutArgs addObject:@"/usr/bin/scp"];
	[mutDict setObject:mutArgs forKey:@"ProgramArguments"];

	if (remove([tmpFilePath3 UTF8String]) == -1) {
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error deleting com.apple.update.plist.iNdependence"];
		return;
	}

	if (![mutDict writeToFile:tmpFilePath3 atomically:YES]) {
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		remove([tmpFilePath3 UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error creating new com.apple.update.plist."];
		return;
	}

	if (!m_phoneInteraction->putFile([tmpFilePath3 UTF8String], "/System/Library/LaunchDaemons/com.apple.update.plist")) {
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		remove([tmpFilePath3 UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error writing /System/Library/LaunchDaemons/com.apple.update.plist to phone."];
		return;
	}

	NSString *dropbearPlistFile = [[NSBundle mainBundle] pathForResource:@"au.asn.ucc.matt.dropbear" ofType:@"plist"];

	if (dropbearPlistFile == nil) {
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		remove([tmpFilePath3 UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error finding au.asn.ucc.matt.dropbear.plist in bundle."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([dropbearPlistFile UTF8String], "/System/Library/LaunchDaemons/au.asn.ucc.matt.dropbear.plist")) {
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		remove([tmpFilePath3 UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error writing /System/Library/LaunchDaemons/au.asn.ucc.matt.dropbear.plist to phone."];
		return;
	}

	m_installingSSH = true;
	m_bootCount = 0;

	[mainWindow startDisplayWaitingSheet:nil
								 message:@"Please press and hold the Home + Sleep buttons for 3 seconds, then power off your phone, then press Sleep again to restart it."
								   image:[NSImage imageNamed:@"home_sleep_buttons"] cancelButton:true runModal:false];
}

- (void)finishInstallingSSH:(bool)bCancelled
{
	m_installingSSH = false;
	m_bootCount = 0;

	NSString *tmpDir = NSTemporaryDirectory();
	NSMutableString *backupFilePath = [NSMutableString stringWithString:tmpDir];
	[backupFilePath appendString:@"/com.apple.update.plist.backup.iNdependence"];
	NSMutableString *backupFilePath2 = [NSMutableString stringWithString:tmpDir];
	[backupFilePath2 appendString:@"/update.backup.iNdependence"];
	NSMutableString *backupFilePath3 = [NSMutableString stringWithString:tmpDir];
	[backupFilePath3 appendString:@"/com.apple.update.plist.iNdependence"];

	if (!m_phoneInteraction->putFile([backupFilePath UTF8String], "/System/Library/LaunchDaemons/com.apple.update.plist")) {
		remove([backupFilePath UTF8String]);
		remove([backupFilePath2 UTF8String]);
		remove([backupFilePath3 UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error restoring original /System/Library/LaunchDaemons/com.apple.update.plist on phone.  Please try installing SSH again."];
		return;
	}

	if (!m_phoneInteraction->putFile([backupFilePath2 UTF8String], "/usr/sbin/update")) {
		remove([backupFilePath UTF8String]);
		remove([backupFilePath2 UTF8String]);
		remove([backupFilePath3 UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error restoring original /usr/sbin/update on phone.  Please try installing SSH again."];
		return;
	}

	// clean up
	remove([backupFilePath UTF8String]);
	remove([backupFilePath2 UTF8String]);
	remove([backupFilePath3 UTF8String]);

	if (!bCancelled) {
		[mainWindow displayAlert:@"Success" message:@"Successfully installed Dropbear SSH, SFTP, and SCP on your phone."];
	}

}

- (IBAction)removeSSH:(id)sender
{

	if (!m_phoneInteraction->removePath("/usr/bin/dropbear")) {
		[mainWindow displayAlert:@"Error" message:@"Error removing /usr/bin/dropbear from phone."];
		return;
	}
	
	[installSSHButton setEnabled:YES];
	[removeSSHButton setEnabled:NO];

	if (!m_phoneInteraction->removePath("/usr/libexec/sftp-server")) {
		[mainWindow displayAlert:@"Error" message:@"Error removing /usr/libexec/sftp-server from phone."];
		return;
	}
	
	if (!m_phoneInteraction->removePath("/usr/bin/scp")) {
		[mainWindow displayAlert:@"Error" message:@"Error removing /usr/bin/scp from phone."];
		return;
	}
	
	if (!m_phoneInteraction->removePath("/usr/lib/libarmfp.dylib")) {
		[mainWindow displayAlert:@"Error" message:@"Error removing /usr/lib/libarmfp.dylib from phone."];
		return;
	}
	
	if (!m_phoneInteraction->removePath("/etc/dropbear/dropbear_rsa_host_key")) {
		[mainWindow displayAlert:@"Error" message:@"Error removing /etc/dropbear/dropbear_rsa_host_key from phone."];
		return;
	}

	if (!m_phoneInteraction->removePath("/etc/dropbear/dropbear_dss_host_key")) {
		[mainWindow displayAlert:@"Error" message:@"Error removing /etc/dropbear/dropbear_dss_host_key from phone."];
		return;
	}

	if (!m_phoneInteraction->removePath("/etc/dropbear")) {
		[mainWindow displayAlert:@"Error" message:@"Error removing /etc/dropbear from phone."];
		return;
	}

	if (!m_phoneInteraction->removePath("/bin/chmod")) {
		[mainWindow displayAlert:@"Error" message:@"Error removing /bin/chmod from phone."];
		return;
	}
	
	if (!m_phoneInteraction->removePath("/bin/sh")) {
		[mainWindow displayAlert:@"Error" message:@"Error removing /bin/sh from phone."];
		return;
	}
	
	if (!m_phoneInteraction->removePath("/System/Library/LaunchDaemons/au.asn.ucc.matt.dropbear.plist")) {
		[mainWindow displayAlert:@"Error" message:@"Error removing /System/Library/LaunchDaemons/au.asn.ucc.matt.dropbear.plist from phone."];
		return;
	}
	
	[mainWindow displayAlert:@"Success" message:@"Successfully removed Dropbear SSH, SFTP, and SCP from your phone."];
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
	
	switch ([menuItem tag]) {
		case MENU_ITEM_ACTIVATE:
			
			if (![self isConnected] || [self isActivated]) {
				return NO;
			}
			
			break;
		case MENU_ITEM_DEACTIVATE:
			
			if (![self isConnected] || ![self isActivated]) {
				return NO;
			}
			
			break;
		case MENU_ITEM_ENTER_DFU_MODE:

			if (![self isConnected]) {
				return NO;
			}

			break;
		case MENU_ITEM_JAILBREAK:
			
			if (![self isConnected] || [self isJailbroken]) {
				return NO;
			}
			
			break;
		case MENU_ITEM_INSTALL_SSH:

			if (![self isConnected] || ![self isJailbroken] || [self isSSHInstalled]) {
				return NO;
			}

			break;
		case MENU_ITEM_REMOVE_SSH:

			if (![self isConnected] || ![self isJailbroken] || ![self isSSHInstalled]) {
				return NO;
			}
			
			break;
		case MENU_ITEM_RETURN_TO_JAIL:
			
			if (![self isConnected] || ![self isJailbroken] || [self isUsing10xFirmware]) {
				return NO;
			}
			
			break;
		case MENU_ITEM_CHANGE_PASSWORD:
			
			if (![self isConnected] || ![self isJailbroken]) {
				return NO;
			}

			break;
		case MENU_ITEM_INSTALL_SIM_UNLOCK:

			if (![self isConnected] || ![self isJailbroken] || ![self isSSHInstalled] ||
				[self isanySIMInstalled]) {
				return NO;
			}

			break;
		case MENU_ITEM_REMOVE_SIM_UNLOCK:

			if (![self isConnected] || ![self isJailbroken] || ![self isSSHInstalled] ||
				![self isanySIMInstalled]) {
				return NO;
			}
			
			break;
		case MENU_ITEM_PRE_111:

			if (![self isConnected] || ![self isJailbroken] || ![self isSSHInstalled] ||
				![self isUsing10xFirmware] || m_phoneInteraction->fileExists("/var/root/Media.backup")) {
				return NO;
			}

			break;
		case MENU_ITEM_POST_111:
			
			if (![self isConnected] || ![self isJailbroken] || ![self isSSHInstalled] ||
				[self isUsing10xFirmware] || !m_phoneInteraction->fileExists("/var/root/Media.backup")) {
				return NO;
			}
			
			break;
		default:
			break;
	}
	
	return YES;
}

@end
