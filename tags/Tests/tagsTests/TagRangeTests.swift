import XrayInXCTest

@testable import tags

final class TagRangeTests: AssrtTestCase {
  func testTagRange() {
    let tag = 0xBEEF  // 16 bits
    let start = 12_345  // 21 bits
    let end = 12_355  // 21 bits
    let scratch = 17  // 6 bits

    // makeSafely vs manual pack
    let r = TagRange.makeSafely(
      tag: tag,
      start: start,
      end: end,
      scratch: scratch
    )
    let manual: UInt64 =
      ((UInt64(tag) & TagRange.tagField.maskField) &<< TagRange.tagField.shift)
      | ((UInt64(start) & TagRange.startField.maskField)
        &<< TagRange.startField.shift)
      | ((UInt64(end) & TagRange.endField.maskField) &<< TagRange.endField.shift)
      | ((UInt64(scratch) & TagRange.scratchField.maskField)
        &<< TagRange.scratchField.shift)
    a.expAct(manual, r.raw, "TagRange.makeSafely packs fields correctly", .sl())

    // scalar read accessors
    a.expAct(UInt64(tag), r.tag, "TagRange.tag scalar read", .sl())
    a.expAct(UInt64(start), r.start, "TagRange.start scalar read", .sl())
    a.expAct(UInt64(end), r.end, "TagRange.end scalar read", .sl())
    a.expAct(UInt64(scratch), r.scratch, "TagRange.scratch scalar read", .sl())

    // SIMD extractors
    let vec = SIMD4<UInt64>(repeating: r.raw)
    a.expAct(
      SIMD4<UInt64>(repeating: UInt64(tag)),
      TagRange.extractTagSIMD4(vec),
      "TagRange.extractTagSIMD4",
      .sl()
    )
    a.expAct(
      SIMD4<UInt64>(repeating: UInt64(start)),
      TagRange.extractStartSIMD4(vec),
      "TagRange.extractStartSIMD4",
      .sl()
    )
    a.expAct(
      SIMD4<UInt64>(repeating: UInt64(end)),
      TagRange.extractEndSIMD4(vec),
      "TagRange.extractEndSIMD4",
      .sl()
    )

    // SIMD write for tag + verify other fields preserved
    let newTags = SIMD4<UInt64>(1, 2, 3, 4)
    let vec2 = TagRange.setTagSIMD4(in: vec, to: newTags)
    a.expAct(
      newTags,
      TagRange.extractTagSIMD4(vec2),
      "TagRange.setTagSIMD4 then read",
      .sl()
    )
    a.expAct(
      SIMD4<UInt64>(repeating: UInt64(start)),
      TagRange.extractStartSIMD4(vec2),
      "setTagSIMD4 preserves start",
      .sl()
    )
    a.expAct(
      SIMD4<UInt64>(repeating: UInt64(end)),
      TagRange.extractEndSIMD4(vec2),
      "setTagSIMD4 preserves end",
      .sl()
    )

    // SIMD update for start (+5)
    let vec3 = TagRange.updateStartSIMD4(in: vec2) {
      $0 &+ SIMD4<UInt64>(repeating: 5)
    }
    a.expAct(
      SIMD4<UInt64>(repeating: UInt64(start + 5)),
      TagRange.extractStartSIMD4(vec3),
      "TagRange.updateStartSIMD4 +5",
      .sl()
    )

    // Round-trip make (unsafe) parity with makeSafely for valid inputs
    let r2 = TagRange.make(tag: tag, start: start, end: end, scratch: scratch)
    a.expAct(
      r.raw,
      r2.raw,
      "TagRange.make equals makeSafely for valid inputs",
      .sl()
    )

    // Sanity: ranges are half-open [start, end)
    a.ok(r.start <= r.end, "TagRange half-open invariant start <= end", .sl())
  }
}
