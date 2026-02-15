# Pollux

Pollux is an asynchronous i/o loop for [Lua](https://lua.org) inspired by [Trio](https://trio.readthedocs.io) and powered by [Zig](https://ziglang.org).
Pollux is very much a work in progress.

To build Pollux, run `zig build` in the repository root.
You can pass `-Dlang=lua54` to build with Lua 5.4, for instance.
A shared library object (called `pollux.so` on POSIX systems) will be placed in `zig-out/lib`.
Running `lua` from a directory containing this library will allow the Lua interpreter to load it.

Here is some example code.

```lua
pollux = require "pollux"
pollux.run(function(px) -- px is a handle to the event loop; 
  -- note that it is only available from inside pollux.run()
  local f = px:async(function() px:sleep(4) return 5 end) -- sleeps for 4 seconds
  print("hi!") -- runs right away
  local n = f:await() -- f is a "Future" and must be awaited to get the inner value
  print("got " .. n) -- runs after 4 seconds
  -- after the second print, pollux.run() will return control to the user
  end
end)
```
