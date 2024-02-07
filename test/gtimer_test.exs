defmodule GtimerTest do
  use ExUnit.Case

  setup do
    on_exit(fn ->
      try do
        Gtimer.stop()
      catch _,_ -> :ok end
    end)
  end

  test "set_and_cancel" do
    timer = Gtimer.new_timer(100,"test set_and_cancel")
    Gtimer.cancel_timer(timer)
    Process.sleep(200)
    assert Gtimer.expired_timers() == []
  end

  test "timeout" do
    child = Task.async(fn () ->
      Gtimer.new_timer(100,"test timeout")
      Process.sleep(500)
    end)
    Task.await(child)
    num_timers = length(Gtimer.expired_timers())
    assert num_timers == 1
  end

  test "timeout_message" do
    child = Task.async(fn () ->
      Gtimer.new_timer(100,{:call,:gtimer_test,:timeout_message,[21]},log_level: :error)
      Process.sleep(500)
    end)
    Task.await(child)
    num_timers = length(Gtimer.expired_timers())
    assert num_timers == 1
  end

  test "no_timeout" do
    task = Task.async(fn () ->
      Gtimer.new_timer(1000,"test no_timeout")
      Process.sleep(500)
    end)
    Task.await(task)
    assert Gtimer.expired_timers() == []
  end

  test "timeout_action" do
    self = self()
    task = Task.async(fn () ->
      Gtimer.new_timer(100,"test timeout_action",timeout_action: fn _ ->
        send(self,:hola)
      end)
      Process.sleep(200)
    end)
    Task.await(task)
    assert_receive(:hola,300)
  end

  test "n_timeouts" do
    children = Enum.map(1..2000, fn i ->
      spawn(fn () ->
        timer_ref = Gtimer.new_timer(100,"test n_timeouts",timeout_action: fn item -> Process.exit(item.pid,:because) end)
        Process.sleep(50)
        if rem(i,2)==0 do
          Gtimer.cancel_timer(timer_ref)
        end
        Process.sleep(2000)
      end)
    end)
    Process.sleep(2000)
    alive = Enum.filter(children, fn pid -> Process.alive?(pid) end)
    assert length(alive) == 1000
  end
end
