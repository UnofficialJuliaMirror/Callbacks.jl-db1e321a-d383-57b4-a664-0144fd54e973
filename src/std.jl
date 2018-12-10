# Standard Callbacks

runall(f) = f
runall(fs::AbstractVector) = (data, stage) -> foreach(f -> handlesignal(f(data, stage)), fs)

"Higher order function that makes a callback run just once every n"
function everyn(callback, n::Integer)
  everyncb(data, stage) = nothing
  function everyncb(data, stage::Type{Outside})
    if data.i % n == 0
      return callback(data, stage)
    else
      nothing
    end
  end
  return everyncb
end


## Callback Augmenters
## ===================
#
"""
Returns a function that when invoked, will only be triggered at most once
during `timeout` seconds. Normally, the throttled function will run
as much as it can, without ever going more than once per `wait` duration;
but if you'd like to disable the execution on the leading edge, pass
`leading=false`. To enable execution on the trailing edge, ditto.
"""
function throttle(f, timeout; leading = true, trailing = false) # From Flux (thanks!)
  cooldown = true
  later = nothing
  result = nothing

  function throttled(args...; kwargs...)
    yield()

    if cooldown
      if leading
        result = f(args...; kwargs...)
      else
        later = () -> f(args...; kwargs...)
      end

      cooldown = false
      @async try
        while (sleep(timeout); later != nothing)
          later()
          later = nothing
        end
      catch e
        rethrow(e)
      finally
        cooldown = true
      end
    elseif trailing
      later = () -> (result = f(args...; kwargs...))
    end

    return result
  end
end


"As the name suggests"
donothing(data, stage) = nothing

"Show progress meter"
function showprogress(n)
  p = Progress(n, 1)
  updateprogress(data, stage) = nothing # Do nothing in other stages
  function updateprogress(data, stage::Type{Outside})
    ProgressMeter.next!(p)
  end
end

"Stop if nans or Inf are present (-Inf) still permissible"
stopnanorinf(data, stage) = nothing
function stopnanorinf(data, stage::Type{Outside})
  if isnan(data.p)
    println("p is $(data.p)")
    throw(NaNError())
    return Stop
  elseif data.p == Inf
    println("p is $(data.p)")
    throw(InfError())
    return Stop
  end
end