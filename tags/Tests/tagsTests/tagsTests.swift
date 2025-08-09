import Testing

import tags

@Test func maskForTagInRange() {
  // Tags
  let parentTag = 1
  let childTag = 2

  // Parent range [10, 30)
  let qStart: UInt64 = 10
  let qEnd: UInt64 = 30
  @inline(__always)
  func make(_ tag: Int, _ start: Int, _ end: Int) -> TagRange {
    .make(tag: tag, start: start, end: end)
  }

  let (hit, miss) = (UInt64.max, UInt64.min)
  let exp = [miss, hit, miss, hit]
  let r0 = make(parentTag, 10, 30).raw  // MISS: tag mis-match
  let r1 = make(childTag, 12, 20).raw  // HIT: tag and contained
  let r2 = make(childTag, 25, 35).raw  // MISS: overlaps
  let r3 = make(childTag, 10, 30).raw  // HIT: tag and contained (i.e., exact)

  let data: [UInt64] = [r0, r1, r2, r3]
  var maskResult = [UInt64](repeating: UInt64(0), count: data.count)

  TagRange.maskForTagInRange(
    data: data,
    maskResult: &maskResult,
    targetTag: UInt64(childTag),
    qStart: UInt64(qStart),
    qEnd: UInt64(qEnd)
  )

  if exp != maskResult {
    print(maskResult.map { $0 == hit ? "H" : "M" })
    print(exp.map { $0 == hit ? "H" : "M" })
  }
}
