# A global timer facility

A small library which provides a global timer facility in Elixir (or Erlang). There are two callable functions:
  - `timer_ref = Gtimer.new_timer(timeout,timeout_action \\ nil)`.
    Starts a new timer running for `timeout` millseconds, returns a "timer reference".
  - `Gtimer.cancel_timer(timer_ref)`.
    Cancels a running timer.

If a running timer is not cancelled when the timer expires the `timeout_action` function will
be called with the process identifier `pid`of the process that created the timer
as a single argument. If the timeout_action is not a function of arity 1, then the default action of
terminating the process `pid`, and displaying an informative message, will be taken.

Timer management is done in a separate (GenServer) process which will be linked to the process executing the new_timer call.
Inside the process timers are stored in a priority queue, and using a map, which affords logarithmic worst-case time complexity for both function calls 
(in terms of the number of timers running). 

An example:
    timer_ref = Gtimer.new_timer(1000,fn pid -> Process.exit(pid,:because) end)
This will start a new timer which when it expires kills the process which invoked
the call to `new_timer`.


