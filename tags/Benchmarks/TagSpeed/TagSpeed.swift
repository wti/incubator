import Benchmark
import tagDemo

let benchmarks: @Sendable () -> Void = {
  typealias Masker = TagOps.MaskForTag
  guard var me = Masker(lanes: 1024) else { return }  // TODO: fail

  Benchmark("TagScan-noRun") { benchmark in
    for _ in benchmark.scaledIterations {
      me.clearMaskResult()
    }
  }
  Benchmark("TagScan") { benchmark in
    for _ in benchmark.scaledIterations {
      blackHole(me.run())
      me.clearMaskResult()  // urk: part of benchmark?
    }
  }
}
