import tags

public enum TagOps {
  public typealias RangeTag = TagRange0
  /// initialize then run ``RangeTag/maskForTagInRange``
  ///
  /// Limitations:
  /// - currently only repeating 2 kinds of hit or miss for same parent range
  ///
  /// TODO
  /// - multiple parent tag ranges with multiple child tag-ranges
  /// - Run other queries in parallel, in same loop
  /// - see if possible to use scratch area
  public struct MaskForTag {
    public static let (hit, miss) = (UInt64.max, UInt64.min)
    public static let parent = TagDatum(tag: 1, range: 10...30)
    public static let parentStart = 10
    public static let childTag = 2
    private static let zero = UInt64(0)

    public struct TagDatum: Sendable {
      public let tag: Int
      public let range: ClosedRange<Int>
      public var start: Int { range.lowerBound }
      public var end: Int { range.upperBound }
    }

    /// Render UInt64 as "H" (hit) "M" (miss) or "?" (neither)
    /// - Parameter x: UInt64 from ``RangeTag`` element
    public static func HM(_ x: UInt64) -> String {
      x == hit ? "H" : x == miss ? "M" : "?"
    }
    public static let expectMask = [miss, hit, miss, hit]

    public let data: [UInt64]
    private var maskResult: [UInt64]

    /// Initialize data before run
    /// - Parameter lanes: Int 1..(Int.max / 16)
    public init?(lanes: Int = 1) {
      if lanes < 1 || lanes > (Int.max / 16) { return nil }

      @inline(__always)
      func make(_ tag: Int, _ start: Int, _ end: Int) -> RangeTag {
        .make(tag: tag, start: start, end: end)
      }
      let parent = Self.parent
      let childTag = Self.childTag
      let r0 = make(parent.tag, parent.start, parent.end).raw  // MISS: tag
      let r1 = make(childTag, 12, 20).raw  // HIT: tag and contained
      let r2 = make(childTag, 25, 35).raw  // MISS: overlaps
      let r3 = make(childTag, 10, 30).raw  // HIT: tag and exact range

      let filledCount = 4 * lanes
      var data = [UInt64](repeating: Self.zero, count: filledCount)
      var i = 0
      while i < data.count {
        data[i + 0] = r0
        data[i + 1] = r1
        data[i + 2] = r2
        data[i + 3] = r3
        i += 4
      }
      self.data = data
      self.maskResult = [UInt64](repeating: UInt64(0), count: data.count)
    }

    public mutating func run() {
      RangeTag.maskForTagInRange(
        data: data,
        maskResult: &maskResult,
        targetTag: UInt64(Self.childTag),
        qStart: UInt64(Self.parent.start),
        qEnd: UInt64(Self.parent.end)
      )
    }
    mutating public func clearMaskResult() {
      for i in 0..<maskResult.count {
        maskResult[i] = Self.zero
      }
    }

    public func getMaskResultActual() -> [UInt64] {
      maskResult
    }

    public func getMaskResultExpected() -> [UInt64] {
      if data.count != maskResult.count { return [UInt64]() }  // TODO
      let filledCount = data.count
      var result = [UInt64](repeating: UInt64(0), count: filledCount)
      result.reserveCapacity(maskResult.count)
      var i = 0
      while i < filledCount {
        result[i + 0] = Self.expectMask[0]
        result[i + 1] = Self.expectMask[1]
        result[i + 2] = Self.expectMask[2]
        result[i + 3] = Self.expectMask[3]
        i += 4
      }
      return result
    }
  }
}
