defmodule Gtimer do
  use GenServer

  def init(_) do
    {:ok,pqueue} = :epqueue.new()
    {:ok, %{pqueue: pqueue, map: %{}, counter: 0}}
  end

  def handle_call({:new_timer, timeout, pid}, _from, state) do
    timer_ref = state[:counter]
    timeout_time = :os.system_time(:millisecond)+timeout
    queue_item = %{timer: timer_ref, timeout: timeout_time, pid: pid}
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
          IO.puts("no reference #{inspect timer_ref} in map")
          state
       map_item ->
          IO.puts("found map_item #{inspect map_item}")
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
    IO.puts("Pid #{inspect queue_item[:pid]} timed out; terminating...")
    Process.exit(queue_item[:pid],:timed_out)
    new_state = %{ state | map: Map.drop(state[:map],[queue_item[:timer_ref]])}
    case calculate_timeout(new_state) do
      {:ok, next_time} ->
        {:noreply, new_state, next_time}
      _ ->
        {:noreply, new_state}
    end
  end

  def handle_info(other, state) do
    IO.puts("*** WARNING: gtimer: unexpected message #{inspect other} received")
    {:noreply, state}
  end

  def calculate_timeout(state) do
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

  def new_timer(timeout) do
    case Process.whereis(:gtimer) do
      nil ->
        {:ok, _pid} = GenServer.start_link(Gtimer, [], [{:name, :gtimer}])
        new_timer(timeout)
      _pid ->
        GenServer.call(:gtimer,{:new_timer, timeout, self()})
    end
  end

  def cancel_timer(time_ref) do
    case Process.whereis(:gtimer) do
      nil ->
        {:ok, _pid} = GenServer.start_link(Gtimer, [], [{:name, :gtimer}])
        cancel_timer(time_ref)
      _pid ->
        GenServer.call(:gtimer,{:cancel_timer, time_ref})
    end
  end
end
