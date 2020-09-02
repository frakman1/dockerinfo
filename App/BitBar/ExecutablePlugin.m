//
//  ExecutablePlugin.m
//  BitBar
//
//  Created by Mathias Leppich on 22/01/14.
//  Copyright (c) 2014 Bit Bar. All rights reserved.
//

#import "ExecutablePlugin.h"
#import "PluginManager.h"
#import "NSTask+useSystemProxies.h"
#import "NSUserDefaults+Settings.h"

@implementation ExecutablePlugin

- (BOOL) refreshContentByExecutingCommand {
  return [self refreshContentByExecutingCommand:nil];
}

- (BOOL)refreshContentByExecutingCommand:(NSArray<NSString *> *)args {

  if (![[NSFileManager defaultManager] fileExistsAtPath:self.path]) {
    return NO;
  }

  NSTask *task = NSTask.new;

  [task setEnvironment:self.manager.environment];
  [task setLaunchPath:self.path];
  [task useSystemProxies];
  
  if (args) {
    task.arguments = args;
  }

  NSPipe *stdoutPipe = [NSPipe pipe];
  [task setStandardOutput:stdoutPipe];
  [stdoutPipe.fileHandleForReading waitForDataInBackgroundAndNotify];

  NSPipe *stderrPipe = [NSPipe pipe];
  [task setStandardError:stderrPipe];

  self.content = @"";
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileHandleDataAvailable:) name:NSFileHandleDataAvailableNotification object:stdoutPipe.fileHandleForReading];
  
  @try {
    [task launch];
  } @catch (NSException *e) {
    NSLog(@"Error when running %@ : %@: %@",self.path, self.name, e);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleDataAvailableNotification object:stdoutPipe.fileHandleForReading];
    self.lastCommandWasError = YES;
    self.content = @"";
    self.errorContent = e.reason;
    return NO;
  }

  [task waitUntilExit];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleDataAvailableNotification object:stdoutPipe.fileHandleForReading];
  
  NSFileHandle *stdoutPipeFh = [stdoutPipe fileHandleForReading];
  NSFileHandle *stderrPipeFh = [stderrPipe fileHandleForReading];
  NSData *stdoutData = [stdoutPipeFh readDataToEndOfFile];
  NSData *stderrData = [stderrPipeFh readDataToEndOfFile];
  
  [stdoutPipeFh closeFile];
  [stderrPipeFh closeFile];
  
  NSString *content = [[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding];
  
  if (content) {
    self.content = [self.content stringByAppendingString:content];
  }
  
  self.errorContent = [NSString.alloc initWithData:stderrData encoding:NSUTF8StringEncoding];

  // failure
  if ([task terminationStatus] != 0) {
    self.lastCommandWasError = YES;
    return NO;
  }

  // success
  self.lastCommandWasError = NO;

  return YES;
}

- (void)fileHandleDataAvailable:(NSNotification *)notification {
  NSFileHandle *fileHandle = notification.object;
  NSString *string = [[NSString alloc] initWithData:fileHandle.availableData encoding:NSUTF8StringEncoding];
  NSString *content = string ? [self.content stringByAppendingString:string] : self.content;
  NSArray *components = [content componentsSeparatedByString:@"~~~"];
  
  if (components.count > 1 && [components[components.count - 2] length] > 0) {
    self.content = [NSString stringWithFormat:@"%@~~~%@", components[components.count - 2], components[components.count - 1]];
    
    [self.lineCycleTimer invalidate];
    self.lineCycleTimer = nil;
    
    self.lastUpdated = NSDate.new;
    
    [self rebuildMenuForStatusItem:self.statusItem];
    
    // reset the current line
    self.currentLine = -1;
    
    // update the status item
    [self cycleLines];
    
    // sort out multi-line cycler
    if (self.isMultiline) {
      
      // start the timer to keep cycling lines
      self.lineCycleTimer = [NSTimer scheduledTimerWithTimeInterval:self.cycleLinesIntervalSeconds target:self selector:@selector(cycleLines) userInfo:nil repeats:YES];
      
    }
    
    // tell the manager this plugin has updated
    [self.manager pluginDidUdpdateItself:self];
  } else {
    self.content = content;
  }
  
  [fileHandle waitForDataInBackgroundAndNotify];
}

- (void)performRefreshNow {
  if (self.pluginIsVisible) {
    self.statusItem.enabled = NO;
  }
  
  [self refresh];
}

-(BOOL)refresh {
  __weak ExecutablePlugin *weakSelf = self;
  [self.lineCycleTimer invalidate];
  self.lineCycleTimer = nil;
  [self.refreshTimer invalidate];
  self.refreshTimer = nil;

  // execute command
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),  ^{
    [weakSelf refreshContentByExecutingCommand];
    dispatch_sync(dispatch_get_main_queue(), ^{
      if (weakSelf) {
        __strong ExecutablePlugin* strongSelf = weakSelf;
        
        [strongSelf.lineCycleTimer invalidate];
        strongSelf.lineCycleTimer = nil;
        
        strongSelf.lastUpdated = NSDate.new;
        //NSLog(@"3 ");
        NSString *versionString = [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"];
        [self.statusItem setToolTip:([NSString stringWithFormat:@"Docker Info %@\nMenubar Docker Dashboard", versionString] )];
        //NSLog(@"Dockerinfo vvv.Menubar Docker Dashboard");
        
        [strongSelf rebuildMenuForStatusItem:strongSelf.statusItem];
        
        // reset the current line
        strongSelf.currentLine = -1;
        
        // update the status item
        [strongSelf cycleLines];
        
        // sort out multi-line cycler
        if (strongSelf.isMultiline) {
          
          // start the timer to keep cycling lines
          strongSelf.lineCycleTimer = [NSTimer scheduledTimerWithTimeInterval:strongSelf.cycleLinesIntervalSeconds target:strongSelf selector:@selector(cycleLines) userInfo:nil repeats:YES];
          
        }
        
        // tell the manager this plugin has updated
        [strongSelf.manager pluginDidUdpdateItself:strongSelf];
        
        // strongSelf next refresh
        strongSelf.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:[strongSelf.refreshIntervalSeconds doubleValue] target:strongSelf selector:@selector(refresh) userInfo:nil repeats:NO];
      }

    });
  });

  return YES;
}

- (void) close {
  [self.lineCycleTimer invalidate];
  self.lineCycleTimer = nil;
  [self.refreshTimer invalidate];
  self.refreshTimer = nil;
}


- (void) copyOutput {

  NSString *valueToCopy = [self.allContentLines objectAtIndex:self.currentLine];
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  [pasteboard writeObjects:[NSArray arrayWithObject:valueToCopy]];

}

- (void) copyAllOutput {

  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  [pasteboard writeObjects:[NSArray arrayWithObject:self.allContent]];

}

- (void) runPluginExternally {

  NSString* script = @"tell application \"Terminal\" \n\
  do script \"%@\" \n\
  activate \n\
  end tell";

  NSString *s = [NSString stringWithFormat:
                 script, [self.path stringByReplacingOccurrencesOfString:@" " withString:@"\\\\ "]];
  NSAppleScript *as = [NSAppleScript.alloc initWithSource:s];
  [as executeAndReturnError:nil];

}

- (void) addAdditionalMenuItems:(NSMenu *)menu {

  if (!DEFS.userConfigDisabled) {
    NSMenuItem *runItem = [NSMenuItem.alloc initWithTitle:@"Run in Terminal…" action:@selector(runPluginExternally) keyEquivalent:@"o"];
    [runItem setTarget:self];
    [menu addItem:runItem];
  }

}

@end
