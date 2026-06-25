/**
 * @file task.h
 * Record the status of a long-running task and permits its termination.
 *
 * @author David Manura (c) 2003-2004 Scientific Instrument Services, Inc.
 * Licensed under the terms of the SIMION SL Toolkit.
 * $Revision$ $Date$ Created 2004-04.
 */

#ifndef SIMIONSL_TASK_H
#define SIMIONSL_TASK_H

namespace simion {

/**
 * This class is used to record the status (e.g. percent completion)
 * of a long-running task and to permit the task to be
 * terminated before completion.
 */
class Task
{
    enum FLAGS
    {
        F_INTERRUPTED = (1<<0),
        F_BUSY = (1<<1),
        F_STARTED = (1<<2),
        F_SUCCESS = (1<<3),
        F_FAILED = (1<<4)
    };
    int percent_complete_;
    int flags_;
    const char * message_;
public:
    Task() : percent_complete_(0), flags_(0), message_(0) { }

    void reset() { percent_complete_ = 0; flags_ = 0; }

    void begin() { flags_ |= F_STARTED | F_BUSY; percent_complete_ = 0;}
    bool is_busy() { return (flags_ & F_BUSY) != 0; }

    bool is_interrupted() { return (flags_ & F_INTERRUPTED) != 0; }
    void set_interrupted() { flags_ |= F_INTERRUPTED; }

    int percent_complete() { return percent_complete_; }
    void set_percent_complete(int percent) { percent_complete_ = percent; }

    void done_success() { flags_ |= F_SUCCESS; flags_ &= ~F_BUSY; }
    bool is_success() { return (flags_ & F_SUCCESS) != 0; }

    void done_failed() { flags_ |= F_FAILED; flags_ &= ~F_BUSY; }
    bool is_failed() { return (flags_ & F_FAILED) != 0; }

    /** warning: pointer is owned by caller. copy of data is
        not made. */
    void set_message(const char * message) { message_ = message; }
    const char * get_message() { return message_; }
};

} // end namespace

#endif // first include
