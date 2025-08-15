// Scalar-only bitfield helper
@usableFromInline
@frozen
struct BitField64 {
  @usableFromInline let bits: UInt64
  @usableFromInline let shift: UInt64
  @usableFromInline let maskField: UInt64
  @usableFromInline let mask: UInt64

  @inlinable
  init(bits: UInt64, shift: UInt64) {
    self.bits = bits
    self.shift = shift
    self.maskField = (1 &<< bits) &- 1
    self.mask = maskField &<< shift
  }

  // Read unshifted value
  @inlinable @inline(__always)
  func read(_ v: UInt64) -> UInt64 {
    (v &>> shift) & maskField
  }

  // Encode unshifted value into position
  @inlinable @inline(__always)
  func encode(_ x: UInt64) -> UInt64 {
    (x & maskField) &<< shift
  }

  // Clear field bits
  @inlinable @inline(__always)
  func clear(in v: UInt64) -> UInt64 {
    v & ~mask
  }

  // Write unshifted value into field
  @inlinable @inline(__always)
  func write(in v: UInt64, value x: UInt64) -> UInt64 {
    clear(in: v) | encode(x)
  }

  // Update field by transforming the unshifted value
  @inlinable @inline(__always)
  func update(in v: UInt64, _ f: (UInt64) -> UInt64) -> UInt64 {
    write(in: v, value: f(read(v)))
  }
}

// SIMD wrapper around BitField64
@usableFromInline
@frozen
struct SIMDField64 {
  @usableFromInline let scalar: BitField64

  @inlinable
  init(_ scalar: BitField64) { self.scalar = scalar }

  @inlinable @inline(__always)
  func read(_ v: SIMD4<UInt64>) -> SIMD4<UInt64> {
    let shifts = SIMD4<UInt64>(repeating: scalar.shift)
    let masksF = SIMD4<UInt64>(repeating: scalar.maskField)
    return (v &>> shifts) & masksF
  }

  @inlinable @inline(__always)
  func encode(_ x: SIMD4<UInt64>) -> SIMD4<UInt64> {
    let shifts = SIMD4<UInt64>(repeating: scalar.shift)
    let masksF = SIMD4<UInt64>(repeating: scalar.maskField)
    return (x & masksF) &<< shifts
  }

  @inlinable @inline(__always)
  func clear(in v: SIMD4<UInt64>) -> SIMD4<UInt64> {
    let masks = SIMD4<UInt64>(repeating: scalar.mask)
    return v & ~masks
  }

  @inlinable @inline(__always)
  func write(in v: SIMD4<UInt64>, value x: SIMD4<UInt64>) -> SIMD4<UInt64> {
    clear(in: v) | encode(x)
  }

  // Elementwise update in SIMD (f transforms unshifted values lane-wise)
  @inlinable @inline(__always)
  func update(in v: SIMD4<UInt64>, _ f: (SIMD4<UInt64>) -> SIMD4<UInt64>)
    -> SIMD4<UInt64>
  {
    write(in: v, value: f(read(v)))
  }

  // Convenience: broadcast scalar write
  @inlinable @inline(__always)
  func write(in v: SIMD4<UInt64>, scalar x: UInt64) -> SIMD4<UInt64> {
    write(in: v, value: .init(repeating: x))
  }
}

@frozen
public struct TagRange {
  public var raw: UInt64

  // Single source of truth (scalar)
  @usableFromInline static let tagField = BitField64(bits: 16, shift: 0)
  @usableFromInline static let startField = BitField64(
    bits: 21,
    shift: tagField.bits
  )
  @usableFromInline static let endField = BitField64(
    bits: 21,
    shift: tagField.bits + startField.bits
  )
  @usableFromInline static let scratchField = BitField64(
    bits: 6,
    shift: tagField.bits + startField.bits + endField.bits
  )

  // SIMD wrappers
  @usableFromInline static let tagSIMD = SIMDField64(tagField)
  @usableFromInline static let startSIMD = SIMDField64(startField)
  @usableFromInline static let endSIMD = SIMDField64(endField)
  @usableFromInline static let scratchSIMD = SIMDField64(scratchField)

  /*
    // Optional forwards for legacy constants
    public static let tagBits: UInt64 = tagField.bits
    public static let startBits: UInt64 = startField.bits
    public static let endBits: UInt64 = endField.bits
    public static let scratchBits: UInt64 = scratchField.bits
  
    public static let tagShift: UInt64 = tagField.shift
    public static let startShift: UInt64 = startField.shift
    public static let endShift: UInt64 = endField.shift
    public static let scratchShift: UInt64 = scratchField.shift
  
    public static let tagMaskField: UInt64 = tagField.maskField
    public static let startMaskField: UInt64 = startField.maskField
    public static let endMaskField: UInt64 = endField.maskField
    public static let scratchMaskField: UInt64 = scratchField.maskField
  
    public static let tagMask: UInt64 = tagField.mask
    public static let startMask: UInt64 = startField.mask
    public static let endMask: UInt64 = endField.mask
    public static let scratchMask: UInt64 = scratchField.mask
  */

  public init(raw: UInt64) { self.raw = raw }

  @inlinable
  public static func makeSafely(
    tag: Int,
    start: Int,
    end: Int,
    scratch: Int = 0
  ) -> Self {
    precondition(UInt64(tag) <= tagField.maskField, "tag out of range")
    precondition(UInt64(start) <= startField.maskField, "start out of range")
    precondition(UInt64(end) <= endField.maskField, "end out of range")
    precondition(
      UInt64(scratch) <= scratchField.maskField,
      "scratch out of range"
    )
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
      tagField.encode(UInt64(tag)) | startField.encode(UInt64(start))
      | endField.encode(UInt64(end)) | scratchField.encode(UInt64(scratch))
    return Self(raw: value)
  }

  // Scalar accessors
  @inlinable public var tag: UInt64 { Self.tagField.read(raw) }
  @inlinable public var start: UInt64 { Self.startField.read(raw) }
  @inlinable public var end: UInt64 { Self.endField.read(raw) }
  @inlinable public var scratch: UInt64 { Self.scratchField.read(raw) }

  // SIMD helpers (unshifted results)
  @inlinable static func extractTagSIMD4(_ v: SIMD4<UInt64>) -> SIMD4<UInt64> {
    tagSIMD.read(v)
  }
  @inlinable static func extractStartSIMD4(_ v: SIMD4<UInt64>) -> SIMD4<UInt64>
  {
    startSIMD.read(v)
  }
  @inlinable static func extractEndSIMD4(_ v: SIMD4<UInt64>) -> SIMD4<UInt64> {
    endSIMD.read(v)
  }

  // Example SIMD write/update if desired
  @inlinable static func setTagSIMD4(in v: SIMD4<UInt64>, to x: SIMD4<UInt64>)
    -> SIMD4<UInt64>
  {
    tagSIMD.write(in: v, value: x)
  }
  @inlinable static func updateStartSIMD4(
    in v: SIMD4<UInt64>,
    _ f: (SIMD4<UInt64>) -> SIMD4<UInt64>
  ) -> SIMD4<UInt64> {
    startSIMD.update(in: v, f)
  }
}
