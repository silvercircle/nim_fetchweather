
import std/math

proc myThreadWorker():void {.thread.} = 
  {.cast(gcsafe).}
  var 
    cnt: int = 1000000
    sequence: int = 0
    foo, bar: float64

  bar = 2.434
  for i in 0..10000000000:
    foo = (math.sqrt(bar) * math.sqrt(bar)) / math.sqrt(2 * bar)
    cnt -= 1
    if cnt <= 0:
      cnt = 10000000
      echo sequence
      sequence = sequence + 1
  echo "Thread finished"

proc threadTest*(): void = 
  var threads: array[2, Thread[void]]
  createThread[string](threads[0], myThreadWorker, CTX)
  createThread[string](threads[1], myThreadWorker, CTX)
