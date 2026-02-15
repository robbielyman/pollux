//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;
const mb = @import("mb");
const zlua = mb.zlua;
const Lua = mb.Lua;

pub const Pollux = opaque {
    fn io(p: *Pollux) std.Io {
        const ev: *std.Io.Evented = @ptrCast(@alignCast(p));
        return ev.io();
    }

    // FIXME: Surely this is incorrect
    pub fn __err(_: *Lua, _: error{Canceled}) void {}

    pub fn sleep(p: *Pollux, seconds: i64) error{Canceled}!void {
        return p.io().sleep(.fromSeconds(seconds), .real);
    }

    pub fn async(p: *Pollux, c: Coroutine) Future {
        const i = p.io();
        return .{ .f = i.async(Coroutine.run, .{c}), .idx = c.idx, .io = i };
    }

    pub fn pull(l: *Lua, arg: i32) *Pollux {
        return @ptrCast(l.checkUserdata(std.Io.Evented, arg, "pollux.Pollux"));
    }

    const Future = struct {
        f: std.Io.Future(i32),
        io: std.Io,
        idx: i32,

        pub fn push(future: Future, l: *Lua) i32 {
            const ptr = l.newUserdata(Future, 0);
            ptr.* = future;
            _ = l.getMetatableRegistry("pollux.Future");
            l.setMetatable(-2);
            return 1;
        }

        pub fn pull(l: *Lua, arg: i32) *Future {
            return l.checkUserdata(Future, arg, "pollux.Future");
        }

        fn await(l: *Lua) i32 {
            const future: *Future = l.checkUserdata(Future, 1, "pollux.Future");
            const nres = future.f.await(future.io);
            const t = l.rawGetIndex(zlua.registry_index, future.idx);
            std.debug.assert(t == .thread);
            const thread = l.toThread(-1) catch unreachable;
            l.pop(1);
            thread.xMove(l, nres);
            l.unref(zlua.registry_index, future.idx);
            thread.closeThread(l) catch unreachable; // FIXME: handle error
            return nres;
        }
    };

    const Coroutine = struct {
        l: *Lua,
        idx: i32,

        pub fn run(c: Coroutine) i32 {
            const t = c.l.rawGetIndex(zlua.registry_index, c.idx);
            std.debug.assert(t == .thread);
            const thread = c.l.toThread(-1) catch unreachable;
            c.l.pop(1);
            var n_res: i32 = undefined;
            const stat = thread.resumeThread(c.l, thread.getTop() - 1, &n_res) catch unreachable;
            switch (stat) {
                .ok => return n_res,
                .yield => unreachable,
            }
        }

        pub fn pull(l: *Lua, arg: i32) Coroutine {
            // std.debug.assert(arg > 1);
            l.checkType(arg, .function);
            const top = l.getTop();
            const thread = l.newThread();
            const ref = l.ref(zlua.registry_index) catch unreachable; // FIXME: handle OOM
            l.xMove(thread, top + 1 - arg);
            return .{ .l = l, .idx = ref };
        }
    };
};

// TODO: allow this function to reuse Io instances
fn run(l: *Lua) i32 {
    l.checkType(1, .function);
    l.pushValue(1);
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const ev: *std.Io.Evented = l.newUserdata(std.Io.Evented, 0);
    _ = l.getMetatableRegistry("pollux.Pollux");
    l.setMetatable(-2);
    ev.init(gpa.allocator(), .{}) catch unreachable;
    defer ev.deinit();
    l.pushClosure(zlua.wrap(errCleanup), 0);
    l.rotate(-3, 1);
    l.protectedCall(.{ .args = 1, .results = 0, .msg_handler = -3 }) catch {
        ev.deinit();
        _ = gpa.deinit();
        l.raiseError();
    };
    return 0;
}

fn errCleanup(_: *Lua) i32 {
    return 1;
}

fn registerFuture(l: *Lua) void {
    l.newMetatable("pollux.Future") catch {
        l.pop(1);
        return;
    };
    l.setFuncs(&.{.{ .func = zlua.wrap(Pollux.Future.await), .name = "await" }}, 0);
    _ = l.pushString("__index");
    l.pushValue(-2);
    l.setTable(-3);
    l.pop(1);
}

fn registerPollux(l: *Lua) void {
    l.newMetatable("pollux.Pollux") catch {
        l.pop(1);
        return;
    };
    const funcs = mb.Functions(Pollux);
    l.setFuncs(funcs, 0);
    _ = l.pushString("__index");
    l.pushValue(-2);
    l.setTable(-3);
    l.pop(1);
}

fn lua_open(lua: ?*zlua.LuaState) callconv(.c) c_int {
    const l: *Lua = @ptrCast(lua.?);
    registerPollux(l);
    registerFuture(l);
    l.newTable();
    _ = l.pushString("run");
    l.pushFunction(zlua.wrap(run));
    l.setTable(-3);
    return 1;
}

comptime {
    @export(&lua_open, .{ .linkage = .strong, .name = "luaopen_pollux" });
}
