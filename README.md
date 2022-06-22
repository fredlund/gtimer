# gtimer
A global timer facility in Elixir

A small library which provides a global timer facility in Elixir (or Erlang). There are two callable functions:
  - timer_ref = Gtimer.new_timer(timeout) 
    which starts a new timer running for timeout millseconds and which returns a timer_ref.
  - Gtimer.cancel_timer(timer_ref) 
    cancels a running timer.

If a running timer is not cancelled when the timer expires the process which called new_timer(timeout) will be terminated. 
Timer management is done in a separate (GenServer) process which will be linked to the process executing the new_timer call.
Inside the process timers are stored in a priority queue, and using a map, which affords logarithmic worst-case time complexity for both function calls 
(in terms of the number of timers running). 
