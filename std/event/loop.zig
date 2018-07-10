const std = @import("../index.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const posix = std.os.posix;
const windows = std.os.windows;
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;

pub const Loop = struct {
    allocator: *mem.Allocator,
    next_tick_queue: std.atomic.QueueMpsc(promise),
    os_data: OsData,
    final_resume_node: ResumeNode,
    dispatch_lock: u8, // TODO make this a bool
    pending_event_count: usize,
    extra_threads: []*std.os.Thread,

    // pre-allocated eventfds. all permanently active.
    // this is how we send promises to be resumed on other threads.
    available_eventfd_resume_nodes: std.atomic.Stack(ResumeNode.EventFd),
    eventfd_resume_nodes: []std.atomic.Stack(ResumeNode.EventFd).Node,

    pub const NextTickNode = std.atomic.QueueMpsc(promise).Node;

    pub const ResumeNode = struct {
        id: Id,
        handle: promise,

        pub const Id = enum {
            Basic,
            Stop,
            EventFd,
        };

        pub const EventFd = switch (builtin.os) {
            builtin.Os.macosx => MacOsEventFd,
            builtin.Os.linux => struct {
                base: ResumeNode,
                epoll_op: u32,
                eventfd: i32,
            },
            builtin.Os.windows => struct {
                base: ResumeNode,
                completion_key: usize,
            },
            else => @compileError("unsupported OS"),
        };

        const MacOsEventFd = struct {
            base: ResumeNode,
            kevent: posix.Kevent,
        };
    };

    /// After initialization, call run().
    /// TODO copy elision / named return values so that the threads referencing *Loop
    /// have the correct pointer value.
    fn initSingleThreaded(self: *Loop, allocator: *mem.Allocator) !void {
        return self.initInternal(allocator, 1);
    }

    /// The allocator must be thread-safe because we use it for multiplexing
    /// coroutines onto kernel threads.
    /// After initialization, call run().
    /// TODO copy elision / named return values so that the threads referencing *Loop
    /// have the correct pointer value.
    fn initMultiThreaded(self: *Loop, allocator: *mem.Allocator) !void {
        const core_count = try std.os.cpuCount(allocator);
        return self.initInternal(allocator, core_count);
    }

    /// Thread count is the total thread count. The thread pool size will be
    /// max(thread_count - 1, 0)
    fn initInternal(self: *Loop, allocator: *mem.Allocator, thread_count: usize) !void {
        self.* = Loop{
            .pending_event_count = 0,
            .allocator = allocator,
            .os_data = undefined,
            .next_tick_queue = std.atomic.QueueMpsc(promise).init(),
            .dispatch_lock = 1, // start locked so threads go directly into epoll wait
            .extra_threads = undefined,
            .available_eventfd_resume_nodes = std.atomic.Stack(ResumeNode.EventFd).init(),
            .eventfd_resume_nodes = undefined,
            .final_resume_node = ResumeNode{
                .id = ResumeNode.Id.Stop,
                .handle = undefined,
            },
        };
        const extra_thread_count = thread_count - 1;
        self.eventfd_resume_nodes = try self.allocator.alloc(
            std.atomic.Stack(ResumeNode.EventFd).Node,
            extra_thread_count,
        );
        errdefer self.allocator.free(self.eventfd_resume_nodes);

        self.extra_threads = try self.allocator.alloc(*std.os.Thread, extra_thread_count);
        errdefer self.allocator.free(self.extra_threads);

        try self.initOsData(extra_thread_count);
        errdefer self.deinitOsData();
    }

    /// must call stop before deinit
    pub fn deinit(self: *Loop) void {
        self.deinitOsData();
        self.allocator.free(self.extra_threads);
    }

    const InitOsDataError = std.os.LinuxEpollCreateError || mem.Allocator.Error || std.os.LinuxEventFdError ||
        std.os.SpawnThreadError || std.os.LinuxEpollCtlError || std.os.BsdKEventError ||
        std.os.WindowsCreateIoCompletionPortError;

    const wakeup_bytes = []u8{0x1} ** 8;

    fn initOsData(self: *Loop, extra_thread_count: usize) InitOsDataError!void {
        switch (builtin.os) {
            builtin.Os.linux => {
                errdefer {
                    while (self.available_eventfd_resume_nodes.pop()) |node| std.os.close(node.data.eventfd);
                }
                for (self.eventfd_resume_nodes) |*eventfd_node| {
                    eventfd_node.* = std.atomic.Stack(ResumeNode.EventFd).Node{
                        .data = ResumeNode.EventFd{
                            .base = ResumeNode{
                                .id = ResumeNode.Id.EventFd,
                                .handle = undefined,
                            },
                            .eventfd = try std.os.linuxEventFd(1, posix.EFD_CLOEXEC | posix.EFD_NONBLOCK),
                            .epoll_op = posix.EPOLL_CTL_ADD,
                        },
                        .next = undefined,
                    };
                    self.available_eventfd_resume_nodes.push(eventfd_node);
                }

                self.os_data.epollfd = try std.os.linuxEpollCreate(posix.EPOLL_CLOEXEC);
                errdefer std.os.close(self.os_data.epollfd);

                self.os_data.final_eventfd = try std.os.linuxEventFd(0, posix.EFD_CLOEXEC | posix.EFD_NONBLOCK);
                errdefer std.os.close(self.os_data.final_eventfd);

                self.os_data.final_eventfd_event = posix.epoll_event{
                    .events = posix.EPOLLIN,
                    .data = posix.epoll_data{ .ptr = @ptrToInt(&self.final_resume_node) },
                };
                try std.os.linuxEpollCtl(
                    self.os_data.epollfd,
                    posix.EPOLL_CTL_ADD,
                    self.os_data.final_eventfd,
                    &self.os_data.final_eventfd_event,
                );

                var extra_thread_index: usize = 0;
                errdefer {
                    // writing 8 bytes to an eventfd cannot fail
                    std.os.posixWrite(self.os_data.final_eventfd, wakeup_bytes) catch unreachable;
                    while (extra_thread_index != 0) {
                        extra_thread_index -= 1;
                        self.extra_threads[extra_thread_index].wait();
                    }
                }
                while (extra_thread_index < extra_thread_count) : (extra_thread_index += 1) {
                    self.extra_threads[extra_thread_index] = try std.os.spawnThread(self, workerRun);
                }
            },
            builtin.Os.macosx => {
                self.os_data.kqfd = try std.os.bsdKQueue();
                errdefer std.os.close(self.os_data.kqfd);

                self.os_data.kevents = try self.allocator.alloc(posix.Kevent, extra_thread_count);
                errdefer self.allocator.free(self.os_data.kevents);

                const eventlist = ([*]posix.Kevent)(undefined)[0..0];

                for (self.eventfd_resume_nodes) |*eventfd_node, i| {
                    eventfd_node.* = std.atomic.Stack(ResumeNode.EventFd).Node{
                        .data = ResumeNode.EventFd{
                            .base = ResumeNode{
                                .id = ResumeNode.Id.EventFd,
                                .handle = undefined,
                            },
                            // this one is for sending events
                            .kevent = posix.Kevent{
                                .ident = i,
                                .filter = posix.EVFILT_USER,
                                .flags = posix.EV_CLEAR | posix.EV_ADD | posix.EV_DISABLE,
                                .fflags = 0,
                                .data = 0,
                                .udata = @ptrToInt(&eventfd_node.data.base),
                            },
                        },
                        .next = undefined,
                    };
                    self.available_eventfd_resume_nodes.push(eventfd_node);
                    const kevent_array = (*[1]posix.Kevent)(&eventfd_node.data.kevent);
                    _ = try std.os.bsdKEvent(self.os_data.kqfd, kevent_array, eventlist, null);
                    eventfd_node.data.kevent.flags = posix.EV_CLEAR | posix.EV_ENABLE;
                    eventfd_node.data.kevent.fflags = posix.NOTE_TRIGGER;
                    // this one is for waiting for events
                    self.os_data.kevents[i] = posix.Kevent{
                        .ident = i,
                        .filter = posix.EVFILT_USER,
                        .flags = 0,
                        .fflags = 0,
                        .data = 0,
                        .udata = @ptrToInt(&eventfd_node.data.base),
                    };
                }

                // Pre-add so that we cannot get error.SystemResources
                // later when we try to activate it.
                self.os_data.final_kevent = posix.Kevent{
                    .ident = extra_thread_count,
                    .filter = posix.EVFILT_USER,
                    .flags = posix.EV_ADD | posix.EV_DISABLE,
                    .fflags = 0,
                    .data = 0,
                    .udata = @ptrToInt(&self.final_resume_node),
                };
                const kevent_array = (*[1]posix.Kevent)(&self.os_data.final_kevent);
                _ = try std.os.bsdKEvent(self.os_data.kqfd, kevent_array, eventlist, null);
                self.os_data.final_kevent.flags = posix.EV_ENABLE;
                self.os_data.final_kevent.fflags = posix.NOTE_TRIGGER;

                var extra_thread_index: usize = 0;
                errdefer {
                    _ = std.os.bsdKEvent(self.os_data.kqfd, kevent_array, eventlist, null) catch unreachable;
                    while (extra_thread_index != 0) {
                        extra_thread_index -= 1;
                        self.extra_threads[extra_thread_index].wait();
                    }
                }
                while (extra_thread_index < extra_thread_count) : (extra_thread_index += 1) {
                    self.extra_threads[extra_thread_index] = try std.os.spawnThread(self, workerRun);
                }
            },
            builtin.Os.windows => {
                self.os_data.extra_thread_count = extra_thread_count;

                self.os_data.io_port = try std.os.windowsCreateIoCompletionPort(
                    windows.INVALID_HANDLE_VALUE,
                    null,
                    undefined,
                    undefined,
                );
                errdefer std.os.close(self.os_data.io_port);

                for (self.eventfd_resume_nodes) |*eventfd_node, i| {
                    eventfd_node.* = std.atomic.Stack(ResumeNode.EventFd).Node{
                        .data = ResumeNode.EventFd{
                            .base = ResumeNode{
                                .id = ResumeNode.Id.EventFd,
                                .handle = undefined,
                            },
                            // this one is for sending events
                            .completion_key = @ptrToInt(&eventfd_node.data.base),
                        },
                        .next = undefined,
                    };
                    self.available_eventfd_resume_nodes.push(eventfd_node);
                }

                var extra_thread_index: usize = 0;
                errdefer {
                    var i: usize = 0;
                    while (i < extra_thread_index) : (i += 1) {
                        while (true) {
                            const overlapped = @intToPtr(?*windows.OVERLAPPED, 0x1);
                            std.os.windowsPostQueuedCompletionStatus(self.os_data.io_port, undefined, @ptrToInt(&self.final_resume_node), overlapped) catch continue;
                            break;
                        }
                    }
                    while (extra_thread_index != 0) {
                        extra_thread_index -= 1;
                        self.extra_threads[extra_thread_index].wait();
                    }
                }
                while (extra_thread_index < extra_thread_count) : (extra_thread_index += 1) {
                    self.extra_threads[extra_thread_index] = try std.os.spawnThread(self, workerRun);
                }
            },
            else => {},
        }
    }

    fn deinitOsData(self: *Loop) void {
        switch (builtin.os) {
            builtin.Os.linux => {
                std.os.close(self.os_data.final_eventfd);
                while (self.available_eventfd_resume_nodes.pop()) |node| std.os.close(node.data.eventfd);
                std.os.close(self.os_data.epollfd);
                self.allocator.free(self.eventfd_resume_nodes);
            },
            builtin.Os.macosx => {
                self.allocator.free(self.os_data.kevents);
                std.os.close(self.os_data.kqfd);
            },
            builtin.Os.windows => {
                std.os.close(self.os_data.io_port);
            },
            else => {},
        }
    }

    /// resume_node must live longer than the promise that it holds a reference to.
    pub fn addFd(self: *Loop, fd: i32, resume_node: *ResumeNode) !void {
        _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);
        errdefer {
            _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
        }
        try self.modFd(
            fd,
            posix.EPOLL_CTL_ADD,
            std.os.linux.EPOLLIN | std.os.linux.EPOLLOUT | std.os.linux.EPOLLET,
            resume_node,
        );
    }

    pub fn modFd(self: *Loop, fd: i32, op: u32, events: u32, resume_node: *ResumeNode) !void {
        var ev = std.os.linux.epoll_event{
            .events = events,
            .data = std.os.linux.epoll_data{ .ptr = @ptrToInt(resume_node) },
        };
        try std.os.linuxEpollCtl(self.os_data.epollfd, op, fd, &ev);
    }

    pub fn removeFd(self: *Loop, fd: i32) void {
        self.removeFdNoCounter(fd);
        _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
    }

    fn removeFdNoCounter(self: *Loop, fd: i32) void {
        std.os.linuxEpollCtl(self.os_data.epollfd, std.os.linux.EPOLL_CTL_DEL, fd, undefined) catch {};
    }

    pub async fn waitFd(self: *Loop, fd: i32) !void {
        defer self.removeFd(fd);
        suspend |p| {
            // TODO explicitly put this memory in the coroutine frame #1194
            var resume_node = ResumeNode{
                .id = ResumeNode.Id.Basic,
                .handle = p,
            };
            try self.addFd(fd, &resume_node);
        }
    }

    /// Bring your own linked list node. This means it can't fail.
    pub fn onNextTick(self: *Loop, node: *NextTickNode) void {
        _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);
        self.next_tick_queue.put(node);
    }

    pub fn run(self: *Loop) void {
        _ = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
        self.workerRun();
        for (self.extra_threads) |extra_thread| {
            extra_thread.wait();
        }
    }

    fn workerRun(self: *Loop) void {
        start_over: while (true) {
            if (@atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst) == 0) {
                while (self.next_tick_queue.get()) |next_tick_node| {
                    const handle = next_tick_node.data;
                    if (self.next_tick_queue.isEmpty()) {
                        // last node, just resume it
                        _ = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
                        resume handle;
                        _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                        continue :start_over;
                    }

                    // non-last node, stick it in the epoll/kqueue set so that
                    // other threads can get to it
                    if (self.available_eventfd_resume_nodes.pop()) |resume_stack_node| {
                        const eventfd_node = &resume_stack_node.data;
                        eventfd_node.base.handle = handle;
                        switch (builtin.os) {
                            builtin.Os.macosx => {
                                const kevent_array = (*[1]posix.Kevent)(&eventfd_node.kevent);
                                const eventlist = ([*]posix.Kevent)(undefined)[0..0];
                                _ = std.os.bsdKEvent(self.os_data.kqfd, kevent_array, eventlist, null) catch {
                                    // fine, we didn't need it anyway
                                    _ = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
                                    self.available_eventfd_resume_nodes.push(resume_stack_node);
                                    resume handle;
                                    _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                                    continue :start_over;
                                };
                            },
                            builtin.Os.linux => {
                                // the pending count is already accounted for
                                const epoll_events = posix.EPOLLONESHOT | std.os.linux.EPOLLIN | std.os.linux.EPOLLOUT | std.os.linux.EPOLLET;
                                self.modFd(eventfd_node.eventfd, eventfd_node.epoll_op, epoll_events, &eventfd_node.base) catch {
                                    // fine, we didn't need it anyway
                                    _ = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
                                    self.available_eventfd_resume_nodes.push(resume_stack_node);
                                    resume handle;
                                    _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                                    continue :start_over;
                                };
                            },
                            builtin.Os.windows => {
                                // this value is never dereferenced but we need it to be non-null so that
                                // the consumer code can decide whether to read the completion key.
                                // it has to do this for normal I/O, so we match that behavior here.
                                const overlapped = @intToPtr(?*windows.OVERLAPPED, 0x1);
                                std.os.windowsPostQueuedCompletionStatus(self.os_data.io_port, undefined, eventfd_node.completion_key, overlapped) catch {
                                    // fine, we didn't need it anyway
                                    _ = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
                                    self.available_eventfd_resume_nodes.push(resume_stack_node);
                                    resume handle;
                                    _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                                    continue :start_over;
                                };
                            },
                            else => @compileError("unsupported OS"),
                        }
                    } else {
                        // threads are too busy, can't add another eventfd to wake one up
                        _ = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
                        resume handle;
                        _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                        continue :start_over;
                    }
                }

                const pending_event_count = @atomicLoad(usize, &self.pending_event_count, AtomicOrder.SeqCst);
                if (pending_event_count == 0) {
                    // cause all the threads to stop
                    switch (builtin.os) {
                        builtin.Os.linux => {
                            // writing 8 bytes to an eventfd cannot fail
                            std.os.posixWrite(self.os_data.final_eventfd, wakeup_bytes) catch unreachable;
                            return;
                        },
                        builtin.Os.macosx => {
                            const final_kevent = (*[1]posix.Kevent)(&self.os_data.final_kevent);
                            const eventlist = ([*]posix.Kevent)(undefined)[0..0];
                            // cannot fail because we already added it and this just enables it
                            _ = std.os.bsdKEvent(self.os_data.kqfd, final_kevent, eventlist, null) catch unreachable;
                            return;
                        },
                        builtin.Os.windows => {
                            var i: usize = 0;
                            while (i < self.os_data.extra_thread_count) : (i += 1) {
                                while (true) {
                                    const overlapped = @intToPtr(?*windows.OVERLAPPED, 0x1);
                                    std.os.windowsPostQueuedCompletionStatus(self.os_data.io_port, undefined, @ptrToInt(&self.final_resume_node), overlapped) catch continue;
                                    break;
                                }
                            }
                            return;
                        },
                        else => @compileError("unsupported OS"),
                    }
                }

                _ = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
            }

            switch (builtin.os) {
                builtin.Os.linux => {
                    // only process 1 event so we don't steal from other threads
                    var events: [1]std.os.linux.epoll_event = undefined;
                    const count = std.os.linuxEpollWait(self.os_data.epollfd, events[0..], -1);
                    for (events[0..count]) |ev| {
                        const resume_node = @intToPtr(*ResumeNode, ev.data.ptr);
                        const handle = resume_node.handle;
                        const resume_node_id = resume_node.id;
                        switch (resume_node_id) {
                            ResumeNode.Id.Basic => {},
                            ResumeNode.Id.Stop => return,
                            ResumeNode.Id.EventFd => {
                                const event_fd_node = @fieldParentPtr(ResumeNode.EventFd, "base", resume_node);
                                event_fd_node.epoll_op = posix.EPOLL_CTL_MOD;
                                const stack_node = @fieldParentPtr(std.atomic.Stack(ResumeNode.EventFd).Node, "data", event_fd_node);
                                self.available_eventfd_resume_nodes.push(stack_node);
                            },
                        }
                        resume handle;
                        if (resume_node_id == ResumeNode.Id.EventFd) {
                            _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                        }
                    }
                },
                builtin.Os.macosx => {
                    var eventlist: [1]posix.Kevent = undefined;
                    const count = std.os.bsdKEvent(self.os_data.kqfd, self.os_data.kevents, eventlist[0..], null) catch unreachable;
                    for (eventlist[0..count]) |ev| {
                        const resume_node = @intToPtr(*ResumeNode, ev.udata);
                        const handle = resume_node.handle;
                        const resume_node_id = resume_node.id;
                        switch (resume_node_id) {
                            ResumeNode.Id.Basic => {},
                            ResumeNode.Id.Stop => return,
                            ResumeNode.Id.EventFd => {
                                const event_fd_node = @fieldParentPtr(ResumeNode.EventFd, "base", resume_node);
                                const stack_node = @fieldParentPtr(std.atomic.Stack(ResumeNode.EventFd).Node, "data", event_fd_node);
                                self.available_eventfd_resume_nodes.push(stack_node);
                            },
                        }
                        resume handle;
                        if (resume_node_id == ResumeNode.Id.EventFd) {
                            _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                        }
                    }
                },
                builtin.Os.windows => {
                    var completion_key: usize = undefined;
                    while (true) {
                        var nbytes: windows.DWORD = undefined;
                        var overlapped: ?*windows.OVERLAPPED = undefined;
                        switch (std.os.windowsGetQueuedCompletionStatus(self.os_data.io_port, &nbytes, &completion_key, &overlapped, windows.INFINITE)) {
                            std.os.WindowsWaitResult.Aborted => return,
                            std.os.WindowsWaitResult.Normal => {},
                        }
                        if (overlapped != null) break;
                    }
                    const resume_node = @intToPtr(*ResumeNode, completion_key);
                    const handle = resume_node.handle;
                    const resume_node_id = resume_node.id;
                    switch (resume_node_id) {
                        ResumeNode.Id.Basic => {},
                        ResumeNode.Id.Stop => return,
                        ResumeNode.Id.EventFd => {
                            const event_fd_node = @fieldParentPtr(ResumeNode.EventFd, "base", resume_node);
                            const stack_node = @fieldParentPtr(std.atomic.Stack(ResumeNode.EventFd).Node, "data", event_fd_node);
                            self.available_eventfd_resume_nodes.push(stack_node);
                        },
                    }
                    resume handle;
                    if (resume_node_id == ResumeNode.Id.EventFd) {
                        _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                    }
                },
                else => @compileError("unsupported OS"),
            }
        }
    }

    const OsData = switch (builtin.os) {
        builtin.Os.linux => struct {
            epollfd: i32,
            final_eventfd: i32,
            final_eventfd_event: std.os.linux.epoll_event,
        },
        builtin.Os.macosx => MacOsData,
        builtin.Os.windows => struct {
            io_port: windows.HANDLE,
            extra_thread_count: usize,
        },
        else => struct {},
    };

    const MacOsData = struct {
        kqfd: i32,
        final_kevent: posix.Kevent,
        kevents: []posix.Kevent,
    };
};

test "std.event.Loop - basic" {
    //var da = std.heap.DirectAllocator.init();
    //defer da.deinit();

    //const allocator = &da.allocator;

    //var loop: Loop = undefined;
    //try loop.initMultiThreaded(allocator);
    //defer loop.deinit();

    //loop.run();
}
