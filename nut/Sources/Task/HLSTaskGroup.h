//
//  HLSTaskGroup.h
//  Funds_iPad
//
//  Created by Samuel Défago on 12/17/10.
//  Copyright 2010 Hortis. All rights reserved.
//

#import "HLSTask.h"

// Forward declarations
@protocol HLSTaskGroupDelegate;

/**
 * This class is a container for task objects to be submitted simultaneously. Do not inherit from this class,
 * subclass HLSTask to implement your custom task logic, and use HLSTaskGroup for submitting many custom tasks
 * at once. This allows you to track not only the individual status of each task, but also the overall progress
 * of the task group. Moreover, dependencies between tasks can be set, which is impossible to achieve when
 * submitting single tasks.
 *
 * A task group must not be submitted several times simultaneously (this leads to undefined behavior). A task 
 * group which was fully processed can be submitted again (and with another delegate if needed), but must not be 
 * already running.
 *
 * Designated initializer: init:
 */
@interface HLSTaskGroup : NSObject {
@private
    NSString *_tag;
    NSDictionary *_userInfo;
    NSMutableSet *_taskSet;                     // contains HLSTask objects
    NSMutableDictionary *_dependencyMap;        // maps a HLSTask object to the NSMutableSet of all other HLSTask objects it depends on
    BOOL _running;
    BOOL _finished;
    BOOL _cancelled;
    float _progress;
    NSUInteger _nbrFailures;
}

/**
 * Optional tag to identify a task group
 */
@property (nonatomic, retain) NSString *tag;

/**
 * Dictionary which can be used freely to convey additional information
 */
@property (nonatomic, retain) NSDictionary *userInfo;

/**
 * Add a task to the task group
 */
- (void)addTask:(HLSTask *)task;

/**
 * Return the current set of HLSTask objects
 */
- (NSSet *)tasks;

/**
 * Return YES if the task group is being processed
 */
@property (nonatomic, readonly, assign, getter=isRunning) BOOL running;

/**
 * Return YES if the task group processing is done (i.e. all contained tasks are finished as well)
 */
@property (nonatomic, readonly, assign, getter=isFinished) BOOL finished;

/**
 * Return YES if the task group processing has been cancelled
 */
@property (nonatomic, readonly, assign, getter=isCancelled) BOOL cancelled;

/**
 * Overall progress value (between 0.f and 1.f). If some tasks fail this value may not reach 1.f
 */
@property (nonatomic, readonly, assign) float progress;

/**
 * Return the current number of failed tasks
 */
- (NSUInteger)nbrFailures;

/**
 * Create dependencies between tasks of a task group. If task1 depends on task2, then task1 will
 * only begin processing once task2 has been fully processed.
 */
- (void)addDependencyForTask:(HLSTask *)task1 onTask:(HLSTask *)task2;

/**
 * Return the array of all tasks which a task depends on
 */
- (NSSet *)dependenciesForTask:(HLSTask *)task;

@end

@protocol HLSTaskGroupDelegate <NSObject>
@optional

/**
 * The task group has started
 */
- (void)taskGroupHasStartedProcessing:(HLSTaskGroup *)taskGroup;

/**
 * The task group is being processed and has an updated status (you can e.g. call progress to get its completion
 * status)
 */
- (void)taskGroupProgressUpdated:(HLSTaskGroup *)taskGroup;

/**
 * The task group has been fully processed. You can check the number of failures or loop over all tasks to get their
 * status or errors individually
 */
- (void)taskGroupHasBeenProcessed:(HLSTaskGroup *)taskGroup;

/**
 * The task group has been cancelled
 */
- (void)taskGroupHasBeenCancelled:(HLSTaskGroup *)taskGroup;

@end

