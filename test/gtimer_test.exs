defmodule GtimerTest do
  use ExUnit.Case

  test "set_and_cancel" do
    timer = Gtimer.new_timer(1000)
    Gtimer.cancel_timer(timer)
    Process.sleep(1100)
    assert 2 == 2
  end

  test "timeout" do
    child = spawn(fn () ->
      Gtimer.new_timer(1000)
      Process.sleep(2500)
    end)
    Process.sleep(1200)
    assert Process.alive?(child) == false
  end

  test "no_timeout" do
    child = spawn(fn () ->
      Gtimer.new_timer(1000)
      Process.sleep(2500)
    end)
    Process.sleep(500)
    assert Process.alive?(child) == true
  end

  test "n_timeouts" do
    children = Enum.map(1..2000, fn i ->
      spawn(fn () ->
        timer_ref = Gtimer.new_timer(1000,fn pid -> Process.exit(pid,:because) end)
        Process.sleep(500)
        if rem(i,2)==0 do
          Gtimer.cancel_timer(timer_ref)
        end
        Process.sleep(5000)
      end)
    end)
    Process.sleep(2000)
    alive = Enum.filter(children, fn pid -> Process.alive?(pid) end)
    assert length(alive) == 1000
  end
end
