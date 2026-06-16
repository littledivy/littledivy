#import "./shim/html.typ": *

#set document(
  title: "Driving libuv with tokio",
  date: datetime(day: 12, month: 2, year: 2026),
  description: "Integrating libuv's event loop with tokio on a single thread",
)

#show: html-shim

#show math.equation.where(block: false): it => {
  if target() == "html" {
    html.elem("span", attrs: (class: "math"), html.frame(it))
  } else {
    it
  }
}

#show math.equation.where(block: true): it => {
  if target() == "html" {
    html.elem("figure", attrs: (class: "math"), html.frame(it))
  } else {
    it
  }
}


#nav-bar()

#title()
#byline()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

libuv is a cross-platform async I/O library. tokio is the async runtime for Rust. Both want to own the event loop.#sidenote[An event loop parks the thread on the kernel until I/O is ready. Two of them on one thread deadlocks unless one yields.] Both want to park on the kernel waiting for I/O. What happens when you need them on the same thread?

I wrote Rust bindings for libuv (libuvrust^1) and got both loops running cooperatively inside a single tokio runtime. Here's how it works.

#note[The trick only works because tokio's reactor exposes a non-blocking poll. If both runtimes insisted on owning the park, you'd deadlock on the first `epoll_wait`.]

= How tokio's reactor works

tokio uses mio under the hood, which is a thin wrapper over the OS polling primitives. On Linux that's epoll, on macOS it's kqueue.

The single-threaded runtime (`current_thread` flavor) runs a tight loop: poll up to 61 tasks, then drive the I/O reactor. When it parks, it needs to decide how long to sleep. tokio uses a hierarchical timing wheel with 6 levels, each with 64 slots. Since #m(`64 = 2^{6}`), each level handles a different 6-bit window of the duration:

#M(`\text{Level } l: 64 \times 64^{l} \text{ ms per slot}`)

Level 0 covers 64ms at 1ms granularity, level 1 covers ~4 seconds at 64ms granularity, all the way up to level 5 which covers ~2 years. This is a radix-64 decomposition of time. The slot for a given duration at level #m(`l`) is:

#M(`s(d, l) = \lfloor d / 64^{l} \rfloor \bmod 64 = (d \gg 6l) \mathbin{\&} \text{0x3F}`)

This extracts bits #m(`[6l, 6l + 6)`) from the duration. Level determination uses the position of the most significant bit:

#M(`l(d) = \lfloor (63 - \text{clz}(d)) / 6 \rfloor`)

where #m(`\text{clz}`) is the count of leading zeros. This maps directly to which 6-bit group contains the MSB of the time difference.

Finding the next timer within a level is #m(`O(1)`). Each level tracks occupied slots in a single `u64` bitfield. To find the next occupied slot from position #m(`p`):

#M(`s_{\text{next}} = (\text{trailing\_zeros}(\text{rotate\_right}(\text{occupied}, p)) + p) \bmod 64`)

The bit rotation moves the current position to bit 0, `trailing_zeros` counts how many empty slots ahead, and we wrap around with mod 64. This is the entire search -- no iteration, no heap traversal. The park duration becomes #m(`\min(t_{\text{wheel}} - t_{\text{now}}, \text{limit})`) and gets passed to `epoll_wait` as the timeout.

= How libuv's reactor works

libuv runs a phased event loop. Each iteration of `uv_run` goes through: timers, pending callbacks, idle, prepare, poll, check, close. The poll phase is where it parks on the kernel -- same epoll/kqueue as tokio.

```
while there are active handles {
  run timers
  run pending callbacks
  run idle handlers
  run prepare handlers
  epoll_wait(backend_fd, events, timeout)
  run check handlers
  run close callbacks
}
```

libuv stores timers in a binary min-heap ordered by absolute deadline. The comparator is:

#M(`a < b \iff \begin{cases} a_{\text{timeout}} < b_{\text{timeout}} \\ a_{\text{start\_id}} < b_{\text{start\_id}} & \text{if } a_{\text{timeout}} = b_{\text{timeout}} \end{cases}`)

When you call `uv_timer_start(handle, cb, timeout, repeat)`, the deadline is computed as:

#M(`d = t_{\text{loop}} + \text{timeout}`)

and the handle is inserted into the heap in #m(`O(\log n)`).

The heap insertion is where it gets interesting. In a complete binary tree with #m(`n`) elements, the next insertion point is at position #m(`n + 1`) (1-indexed). The path from root to this position is encoded in the binary representation of #m(`n + 1`). Skip the MSB (which is always 1, representing the root), then read the remaining bits left-to-right: 0 means go left, 1 means go right.

For example, inserting the 6th element (#m(`n = 5`), #m(`n + 1 = 6 = \text{110}_2`)): skip the leading 1, read [1, 0] -- go right, then left. This is how libuv's `heap_insert` navigates without parent pointers:

```c
path = 0;
for (k = 0, n = 1 + heap->nelts; n >= 2; k += 1, n /= 2)
  path = (path << 1) | (n & 1);
```

The loop reverses the bit order by extracting LSBs and shifting them in. #m(`k`) counts the depth. Then it walks the tree following the bits:

```c
while (k > 0) {
  parent = child;
  if (path & 1) child = &(*child)->right;
  else          child = &(*child)->left;
  path >>= 1;
  k -= 1;
}
```

After insertion, the node bubbles up to restore the heap property. Total cost: #m(`O(\log n)`) comparisons and swaps, with the path computation in #m(`O(\log n)`) bit operations.

`uv__run_timers` pops from the heap until #m(`d_{\text{min}} > t_{\text{loop}}`). The min is always at the root -- #m(`O(1)`) to peek, #m(`O(\log n)`) to remove.

Notice anything familiar? Both runtimes end up calling epoll_wait on a file descriptor with a timeout derived from their timer data structure. libuv calls this its "backend fd" and exposes it through `uv_backend_fd()`.

= Nesting reactors

Only one loop can block on the kernel at a time. If libuv blocks, tokio starves. If we busy-poll libuv, CPU usage goes to 100%.

Here's the trick. `uv_backend_fd()` returns libuv's epoll/kqueue fd. It's just a file descriptor. tokio lets you watch arbitrary fds via `AsyncFd`. So we register libuv's backend fd _inside_ tokio's reactor:

```rust
let async_fd = AsyncFd::with_interest(
    UvBackendFd(uv_backend_fd(uv_loop)),
    Interest::READABLE,
).unwrap();
```

tokio's epoll watches libuv's epoll. When any of libuv's fds become ready, the kernel marks `backend_fd` as readable, and tokio wakes our task.

Inside tokio, when this fd fires, the I/O driver decodes a `ScheduledIo` from the mio token (which is just a provenance-erased pointer) and updates its readiness state. The readiness is packed into a single `AtomicUsize`:

#M(`\text{readiness} (16 \text{ bits}) \mid \text{tick} (15 \text{ bits}) \mid \text{shutdown} (1 \text{ bit})`)

The tick field prevents a subtle race: if the fd becomes ready again between when we read the readiness and when we clear it, the tick mismatch prevents us from accidentally clearing the new event. This matters for our nested fd because libuv events can arrive at any time.

= The timeout problem

Now we have two timer systems. libuv's min-heap and tokio's timing wheel. Both compute a "how long to sleep" value. We need to reconcile them.

libuv exposes `uv_backend_timeout()`. Internally, `uv__backend_timeout` checks a chain of conditions:

```c
if (loop->stop_flag != 0)           return 0;
if (!uv__has_active_handles(loop))  return 0;
if (!queue_empty(pending_queue))    return 0;
if (!queue_empty(idle_handles))     return 0;
if (loop->closing_handles != NULL)  return 0;
return uv__next_timeout(loop);
```

If any of those are true, it returns 0 -- don't sleep, there's work to do. Otherwise it peeks at the heap minimum:

#M(`\tau = \begin{cases} -1 & \text{if heap is empty (block forever)} \\ 0 & \text{if } d_{\text{min}} \le t_{\text{loop}} \text{ (timer expired)} \\ \min(d_{\text{min}} - t_{\text{loop}}, 2^{31} - 1) & \text{otherwise} \end{cases}`)

The #m(`2^{31} - 1`) clamp is because `uv__next_timeout` returns an `int` and the heap stores `uint64_t` deadlines.

tokio does the same thing from its timing wheel: find the earliest occupied slot, compute #m(`t_{\text{wheel}} - t_{\text{now}}`), pass it to `epoll_wait`.

Our scheduling decision uses both:

```rust
uv_run(uv_loop, UV_RUN_NOWAIT); // drain pending

let timeout = uv_backend_timeout(uv_loop);

if timeout == 0 {
    cx.waker().wake_by_ref();
} else if only_uv_work {
    uv_run(uv_loop, UV_RUN_ONCE);
} else {
    waiter.poll_io_ready(cx);
    if timeout > 0 {
        waiter.poll_timer(cx, timeout);
    }
}
```

When #m(`\tau = 0`), libuv has pending work. Wake immediately. When tokio has no pending futures, hand the thread to libuv via `UV_RUN_ONCE` and let it block in its own epoll_wait. When both have work, watch the backend fd and register a tokio timer for #m(`\tau`) ms. The effective sleep duration is:

#M(`t_{\text{sleep}} = \min(\tau, t_{\text{wheel}} - t_{\text{now}})`)

Both timer systems contribute to the deadline. The kernel wakes us on whichever comes first.

= Windows

Windows breaks the fd trick. IOCP (IO Completion Ports) doesn't expose a pollable fd. You can't nest one IOCP inside another. tokio uses its own IOCP, libuv uses its own.

libuv's Windows poll function calls `GetQueuedCompletionStatusEx` with a timeout. It handles early returns with an exponential backoff -- if GQCS returns before the deadline, libuv retries with `timeout += 1 << (repeat - 1)`. This prevents tight spinning on spurious wakeups.

We can't hook into that. The workaround: a dedicated watcher thread that peeks at libuv's IOCP and wakes tokio when packets arrive.

```
Watcher thread                  Main thread (tokio)
──────────────                  ──────────────────
GQCS(iocp, INFINITE)            ...sleeping in tokio poll...
  ← packet arrives
PostQueuedCompletionStatus(×N)
waker.wake()
WaitForSingleObject(resume)     ← wakes up
  ← paused                     uv_run(NoWait)
                                clear_ready() → SetEvent(resume)
  ← resumed
back to GQCS                    ...sleeping in tokio poll...
```

The key trick is the re-post. The watcher dequeues #m(`k`) completion packets from the IOCP via `GetQueuedCompletionStatusEx`, then immediately posts them all back with `PostQueuedCompletionStatus`. The queue depth is invariant:

#M(`|Q| \xrightarrow{\text{GQCS}} |Q| - k \xrightarrow{\text{Post} \times k} |Q|`)

It detected that work arrived without consuming it. libuv's actual callbacks dequeue them during `uv_run(NoWait)`.

The auto-reset event is what makes this safe. After re-posting and waking tokio, the watcher calls `WaitForSingleObject(resume_event)` and blocks. It won't call GQCS again until the main thread signals the event via `SetEvent` after `uv_run` has drained the queue. Without this gate, the watcher would immediately re-dequeue its own re-posted packets.

```rust
fn watcher_thread_main(
  iocp: HANDLE,
  state: Arc<SharedState>,
) {
  let mut entries: [OVERLAPPED_ENTRY; 64] =
    unsafe { std::mem::zeroed() };

  loop {
    WaitForSingleObject(
      state.resume_event, INFINITE,
    );

    let mut num_entries: DWORD = 0;
    GetQueuedCompletionStatusEx(
      iocp, entries.as_mut_ptr(),
      64, &mut num_entries,
      GQCS_TIMEOUT_MS, FALSE,
    );

    if num_entries > 0 {
      // Re-post so libuv can still dequeue them
      for e in &entries[..num_entries as usize] {
        PostQueuedCompletionStatus(
          iocp,
          e.dw_number_of_bytes_transferred,
          e.lp_completion_key,
          e.lp_overlapped,
        );
      }

      state.ready.store(true, Ordering::Release);
      state.waker.wake();
      // Blocks until main thread calls clear_ready()
    }
  }
}
```

#figure(
  image("/static/img/luv-iocp-bridge.svg", width: 90%),
)

One extra thread, some synchronization, but IOCP doesn't give you much else to work with.

= Putting it together

Both loops run cooperatively on a single thread. libuv gets its full phase ordering -- timers, pending callbacks, idle, prepare, poll, check, close. tokio gets async/await. Neither starves.

```rust
#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<()> {
    let local = tokio::task::LocalSet::new();
    local.run_until(async {
        let mut tl = TokioUvLoop::new()?;

        let mut timer = Timer::new(tl.uv_loop())?;
        timer.start(500, 500, |t| {
            println!("[libuv] tick");
        })?;

        tokio::task::spawn_local(async {
            loop {
                tokio::time::sleep(Duration::from_millis(700)).await;
                println!("[tokio] tick");
            }
        });

        tl.drive().await;
        Ok(())
    }).await
}
```

libuv timers and tokio futures, interleaved, same thread. No busy waiting. No extra threads on Unix.

#link("https://github.com/littledivy/libuvrust")[https://github.com/littledivy/libuvrust]
