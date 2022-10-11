defmodule Gtimer do
  @moduledoc """
  A small library which provides a global timer facility in Elixir (or Erlang). 

  ## Example: 
  iex> timer_ref = Gtimer.new_timer(timeout,timeout_action \\ nil)

  Starts a new timer running for `timeout` millseconds, returns a "timer reference".

  iex> Gtimer.cancel_timer(timer_ref)

  Cancels a running timer.

  If a running timer is not cancelled when the timer expires the `timeout_action` function 
  will be called with the process identifier of the process that created the timer
  as a single argument. If the timeout_action is not a function of arity 1, then the 
  default action of terminating the process that created the timer, 
  and displaying an informative message, will be taken.
  
  Timer management is done in a separate process which will be linked
  to the process executing the new_timer call.  Inside the process
  timers are stored in a priority queue, and using a map, which
  affords logarithmic worst-case time complexity for both function
  calls (in terms of the number of timers running).

  ## Example:

  iex> timer_ref = Gtimer.new_timer(1000,fn pid -> Process.exit(pid,:because) end)

  This will start a new timer which when it expires kills the process which invoked
  the call to `new_timer`.
  """
  use GenServer

  @doc false
  def init(_) do
    {:ok,pqueue} = :epqueue.new()
    {:ok, %{pqueue: pqueue, map: %{}, counter: 0}}
  end

  def handle_call({:new_timer, timeout, pid, timeout_action}, _from, state) do
    timer_ref = state[:counter]
    timeout_time = :os.system_time(:millisecond)+timeout
    queue_item = %{timer_ref: timer_ref, timeout: timeout_time, pid: pid, timeout_action: timeout_action}
    {:ok, item_ref} = :epqueue.insert(state[:pqueue], queue_item, timeout_time)
    map_item = Map.put(queue_item,:pqueue_ref,item_ref)
    new_state =
      %{ state |
         map: Map.put(state[:map],timer_ref,map_item),
         counter: state[:counter]+1 }
    case calculate_timeout(new_state) do
      {:ok, next_time} ->
        {:reply, timer_ref, new_state, next_time}
      _ ->
        {:reply, timer_ref, new_state}
    end
  end

  def handle_call({:cancel_timer, timer_ref}, _from, state) do
    new_state = 
      case Map.get(state[:map],timer_ref,:undefined) do
        :undefined ->
          state
        map_item ->
          pqueue_ref = map_item[:pqueue_ref]
          :epqueue.remove(state[:pqueue],pqueue_ref)
          %{ state | map: Map.drop(state[:map],[timer_ref]) }
      end
    case calculate_timeout(new_state) do
      {:ok, next_time} ->
        {:reply, :ok, new_state, next_time}
      _ ->
        {:reply, :ok, new_state}
    end
  end

  def handle_info(:timeout, state) do
    {:ok, queue_item, _} = :epqueue.pop(state[:pqueue])
    # We should do a user defined action here...
    pid = queue_item[:pid]
    timeout_action = queue_item[:timeout_action]
    if is_function(timeout_action,1) do
      try do
        timeout_action.(pid)
      rescue
        _ -> IO.puts("*** ERROR: Gtimer: timeout_function raised an exception")
      end
    else
      if Process.alive?(pid) do
        IO.puts("Pid #{inspect pid} timed out; terminating...")
        Process.exit(pid,:timed_out)
      end
    end
    new_state = %{ state | map: Map.drop(state[:map],[queue_item[:timer_ref]])}
    case calculate_timeout(new_state) do
      {:ok, next_time} ->
        {:noreply, new_state, next_time}
      _ ->
        {:noreply, new_state}
    end
  end

  def handle_info(other, state) do
    IO.puts("*** WARNING: Gtimer: unexpected message #{inspect other} received")
    {:noreply, state}
  end

  defp calculate_timeout(state) do
    case :epqueue.size(state[:pqueue]) do
      n when n>0 ->
        {:ok, _, timeout_time} = :epqueue.peek(state[:pqueue])
        current_time = :os.system_time(:millisecond)
        next_timeout = max(0,timeout_time-current_time)
        {:ok, next_timeout}
      _ ->
        nil
    end
  end

  
  @doc """
  Starts a new timer running for `timeout` millseconds, returns a "timer reference".
  If a running timer is not cancelled when the timer expires the timeout_action function 
  will be called with the process identifier of the process that created the timer as 
  a single argument. If the timeout_action is not a function of arity 1, then 
  the default action of terminating the process that created the timer, 
  and displaying an informative message, will be taken.
  """
  def new_timer(timeout,timeout_action \\ nil) do
    case Process.whereis(:gtimer) do
      nil ->
        # Do not link to the calling process; we are likely to kill it!
        GenServer.start(Gtimer, [], [{:name, :gtimer}])
        new_timer(timeout)
      _pid ->
        GenServer.call(:gtimer,{:new_timer, timeout, self(), timeout_action})
    end
  end

  @doc """
  Cancels a running timer.
  """
  def cancel_timer(time_ref) do
    case Process.whereis(:gtimer) do
      nil ->
        # Do not link to the calling process; we are likely to kill it!
        GenServer.start(Gtimer, [], [{:name, :gtimer}])
        cancel_timer(time_ref)
      _pid ->
        GenServer.call(:gtimer,{:cancel_timer, time_ref})
    end
  end
end
