defmodule Gtimer do
  @moduledoc """
  A small library which provides a global timer facility in Elixir (or Erlang). 

  ## Example: 
  iex> timer_ref = Gtimer.new_timer(timeout,options \\ [])

  Starts a new timer running for `timeout` millseconds, returns a "timer reference".

  iex> Gtimer.cancel_timer(timer_ref)

  Cancels a running timer.

  If a running timer is not cancelled when the timer expires a
  `timeout_action` function (defined as an option)
  will be called with the process identifier of the process that created the timer
  as a single argument. If the timeout_action is not a function of arity 1, then the 
  default action of logging an informative warning message, will be taken.
  
  Timer management is done in a separate process. Inside the process
  timers are stored in a priority queue, and using a map, which
  affords logarithmic worst-case time complexity for both function
  calls (in terms of the number of timers running).

  ## Example:

  iex> timer_ref = Gtimer.new_timer(1000,fn pid -> Process.exit(pid,:because) end)

  This will start a new timer which when it expires kills the process which invoked
  the call to `new_timer`.
  """
  use GenServer
  require Logger

  @doc false
  def init(_) do
    {:ok,pqueue} = :epqueue.new()
    {:ok, %{pqueue: pqueue, map: %{}, counter: 0, expired: []}}
  end

  def handle_call({:new_timer, timeout, pid, info, options}, _from, state) do
    timer_ref = state.counter
    timeout_time = :os.system_time(:millisecond)+timeout
    queue_item = %{timer_ref: timer_ref, timeout: timeout, timeout_time: timeout_time, pid: pid, info: info, options: options}
    {:ok, item_ref} = :epqueue.insert(state.pqueue, queue_item, timeout_time)
    map_item = Map.put(queue_item,:pqueue_ref,item_ref)
    state =
      %{ state |
         map: Map.put(state.map,timer_ref,map_item),
         counter: state.counter+1 }
    case calculate_timeout(state) do
      {:ok, next_time} ->
        {:reply, timer_ref, state, next_time}
      _ ->
        {:reply, timer_ref, state}
    end
  end

  def handle_call({:cancel_timer, timer_ref}, _from, state) do
    state = 
      case Map.get(state.map,timer_ref,:undefined) do
        :undefined ->
          state
        map_item ->
          pqueue_ref = map_item.pqueue_ref
          :epqueue.remove(state.pqueue,pqueue_ref)
          %{ state | map: Map.drop(state.map,[timer_ref]) }
      end
    case calculate_timeout(state) do
      {:ok, next_time} ->
        {:reply, :ok, state, next_time}
      _ ->
        {:reply, :ok, state}
    end
  end

  def handle_call(:expired_timers,_,state) do
    case calculate_timeout(state) do
      {:ok, next_time} ->
        {:reply, state.expired, state, next_time}
      _ ->
        {:reply, state.expired, state}
    end
  end

  def handle_info(:timeout, state) do
    {:ok, item, _} = :epqueue.pop(state.pqueue)
    case Keyword.get(item.options,:timeout_action) do
      fun when is_function(fun,1) ->
        try do
          fun.(item)
        rescue
          _ -> IO.puts("*** ERROR: Gtimer: timeout_function for "<>print_info(item.info)<>" raised an exception")
        end
      _ -> 
        level = Keyword.get(item.options,:log_level,:warning)
        Logger.log(level,"Corsa timer timed out after #{IO.inspect(item.timeout)} milliseconds #{print_info(item.info)}")
    end
    state = %{ state |
               map: Map.drop(state.map,[item.timer_ref]),
               expired: [ item | state.expired ] }
    case calculate_timeout(state) do
      {:ok, next_time} ->
        {:noreply, state, next_time}
      _ ->
        {:noreply, state}
    end
  end

  def handle_info(other, state) do
    IO.puts("*** WARNING: Gtimer: unexpected message #{inspect other} received")
    {:noreply, state}
  end

  defp calculate_timeout(state) do
    case :epqueue.size(state.pqueue) do
      n when n>0 ->
        {:ok, _, timeout_time} = :epqueue.peek(state.pqueue)
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
  a single argument. Options may define a {`timeout_action`,fun}
  which is the action taken when a timer expires, or {`log_level`,level}
  which determines the Log level for timer expire messages.
  """
  def new_timer(timeout,info,options \\ []) do
    case Process.whereis(:gtimer) do
      nil ->
        # Do not link to the calling process; we are likely to kill it!
        GenServer.start(Gtimer, [], [{:name, :gtimer}])
        new_timer(timeout,info,options)
      _pid ->
        GenServer.call(:gtimer,{:new_timer, timeout, self(), info, options})
    end
  end

  @doc """
  Cancels a running timer.
  """
  def cancel_timer(time_ref) do
    case Process.whereis(:gtimer) do
      nil ->
        GenServer.start(Gtimer, [], [{:name, :gtimer}])
        cancel_timer(time_ref)
      _pid ->
        GenServer.call(:gtimer,{:cancel_timer, time_ref})
    end
  end

  @doc """
  Returns expired timers.
  """
  def expired_timers() do
    case Process.whereis(:gtimer) do
      nil ->
        GenServer.start(Gtimer, [], [{:name, :gtimer}])
        expired_timers()
      _pid ->
        GenServer.call(:gtimer,:expired_timers)
    end
  end

  def stop() do
    case Process.whereis(:gtimer) do
      nil -> :ok
      _pid -> GenServer.stop(:gtimer)
    end
  end

  defp print_info(info) do
    case info do
      {:call,_,_,_} -> "for call "<>pretty_print_mfa(info)
      _ when is_binary(info) -> ": "<>info
      _ -> IO.inspect(info)
    end
  end

  defp pretty_print_mfa({:call, module, function, args}) do
    module_string = inspect(module)
    function_string = Atom.to_string(function)
    args_string = Enum.map(args, &inspect/1) |> Enum.join(", ")
    "#{module_string}.#{function_string}(#{args_string})"
  end
  
end
