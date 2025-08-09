/// Tag range, as UInt64
///
// Layout: [scratch | end | start | tag]
//   - scratch: 6 bits (bits 63...58)
//   - end:     21 bits (bits 57...37)
//   - start:   21 bits (bits 36...16)
//   - tag:     16 bits (bits 15...0)
//
// Half-open ranges: [start, end)
@frozen
public struct TagRange {
  public var raw: UInt64

  public static let tagBits: UInt64 = 16
  public static let startBits: UInt64 = 21
  public static let endBits: UInt64 = 21
  public static let scratchBits: UInt64 = 6

  public static let tagShift: UInt64 = 0
  public static let startShift: UInt64 = tagBits
  public static let endShift: UInt64 = tagBits + startBits
  public static let scratchShift: UInt64 = tagBits + startBits + endBits

  public static let tagMaskField: UInt64 = (1 &<< tagBits) - 1
  public static let startMaskField: UInt64 = (1 &<< startBits) - 1
  public static let endMaskField: UInt64 = (1 &<< endBits) - 1
  public static let scratchMaskField: UInt64 = (1 &<< scratchBits) - 1

  public static let tagMask: UInt64 = tagMaskField << tagShift
  public static let startMask: UInt64 = startMaskField << startShift
  public static let endMask: UInt64 = endMaskField << endShift
  public static let scratchMask: UInt64 = scratchMaskField << scratchShift
  public init(raw: UInt64) {
    self.raw = raw
  }

  @inlinable
  public static func makeSafely(
    tag: Int,
    start: Int,
    end: Int,
    scratch: Int = 0
  ) -> Self {
    precondition(tag <= tagMaskField, "tag out of range")
    precondition(start <= startMaskField, "start out of range")
    precondition(end <= endMaskField, "end out of range")
    precondition(scratch <= scratchMaskField, "scratch out of range")
    return make(tag: tag, start: start, end: end, scratch: scratch)
  }

  @inlinable
  public static func make(
    tag: Int,
    start: Int,
    end: Int,
    scratch: Int = 0
  ) -> Self {
    let value: UInt64 =
      ((UInt64(tag) & tagMaskField) << tagShift)
      | ((UInt64(start) & startMaskField) << startShift)
      | ((UInt64(end) & endMaskField) << endShift)
      | ((UInt64(scratch) & scratchMaskField) << scratchShift)
    return Self(raw: value)
  }

  // MARK: - SIMD helpers (SIMD4<UInt64>)

  @inlinable
  static func extractTagSIMD4(_ v: SIMD4<UInt64>) -> SIMD4<UInt64> {
    let mask = SIMD4<UInt64>(repeating: Self.tagMask)
    return v & mask  // tag field is at LSB in this layout
  }

  @inlinable
  static func extractStartSIMD4(_ v: SIMD4<UInt64>) -> SIMD4<UInt64> {
    let shift = SIMD4<UInt64>(repeating: Self.startShift)
    let shifted = v &>> shift
    let mask = SIMD4<UInt64>(repeating: Self.startMaskField)
    return shifted & mask
  }

  @inlinable
  static func extractEndSIMD4(_ v: SIMD4<UInt64>) -> SIMD4<UInt64> {
    let shift = SIMD4<UInt64>(repeating: Self.endShift)
    let shifted = v &>> shift
    let mask = SIMD4<UInt64>(repeating: Self.endMaskField)
    return shifted & mask
  }

  @inlinable
  static func maskToAllOnes(_ mask: SIMDMask<SIMD4<Int64>>) -> SIMD4<UInt64> {
    let zeros = SIMD4<UInt64>(repeating: 0)
    let ones = SIMD4<UInt64>(repeating: ~UInt64(0))
    return zeros.replacing(with: ones, where: mask)
  }
  /// Query for all tags in range
  /// Returns a per-element lane mask (0 or 1) for each element in `data`.
  /// Requirements:
  ///   - data.count is a multiple of 4 (no tail handling).
  ///   - [qStart, qEnd) is the parent range.
  ///   - Matches only when tag == targetTag AND start >= qStart AND end <= qEnd.
  @inlinable
  public static func maskForTagInRange(
    data: [UInt64],
    maskResult: inout [UInt64],
    targetTag: UInt64,
    qStart: UInt64,
    qEnd: UInt64
  ) {
    precondition(data.count >= 4, "data.count is not 4+")
    precondition(
      data.count <= maskResult.count,
      "data.count must less or same as output mask"
    )
    precondition(data.count % 4 == 0, "data.count must be a multiple of 4")
    precondition(targetTag <= Self.tagMaskField, "targetTag out of range")
    precondition(qStart <= qEnd, "invalid query range")

    let tagTargetVec = SIMD4<UInt64>(repeating: targetTag)
    let qStartVec = SIMD4<UInt64>(repeating: qStart)
    let qEndVec = SIMD4<UInt64>(repeating: qEnd)

    var i = 0
    while i < data.count {
      let v = SIMD4<UInt64>(data[i + 0], data[i + 1], data[i + 2], data[i + 3])

      // Extract fields
      let tags = Self.extractTagSIMD4(v)
      let start = Self.extractStartSIMD4(v)
      let end = Self.extractEndSIMD4(v)

      // Branchless lane masks
      // tag == targetTag
      let mTag = Self.maskToAllOnes(tags .== tagTargetVec)
      // start >= qStart
      let mStart = Self.maskToAllOnes(start .>= qStartVec)
      // end <= qEnd
      let mEnd = Self.maskToAllOnes(end .<= qEndVec)

      // Final mask: tag match AND contained in [qStart, qEnd)
      let m = mTag & mStart & mEnd

      maskResult[i + 0] = m[0]
      maskResult[i + 1] = m[1]
      maskResult[i + 2] = m[2]
      maskResult[i + 3] = m[3]

      i += 4
    }

  }

  // Optional utility: compress a 0/~0 mask array into a packed bitset (LSB = earlier element).
  @inlinable
  public static func compressMaskToBitset64(
    _ laneMasks: [UInt64]
  ) -> [UInt64] {
    var result: [UInt64] = []
    var acc: UInt64 = 0
    var bit: UInt64 = 1
    var countInWord = 0

    for m in laneMasks {
      if m != 0 { acc |= bit }
      bit &<<= 1
      countInWord += 1
      if countInWord == 64 {
        result.append(acc)
        acc = 0
        bit = 1
        countInWord = 0
      }
    }
    if countInWord != 0 { result.append(acc) }
    return result
  }
}
