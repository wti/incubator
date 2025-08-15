import XrayInXCTest

@testable import tags

final class SIMDField64Tests: AssrtTestCase {
  func testSIMDField64() {
    let f = BitField64(bits: 8, shift: 16)
    let sf = SIMDField64(f)

    // Base vectors with field values 1,2,3,4
    let v = SIMD4<UInt64>(
      f.write(in: 0, value: 1),
      f.write(in: 0, value: 2),
      f.write(in: 0, value: 3),
      f.write(in: 0, value: 4)
    )

    // read
    a.expAct(
      SIMD4<UInt64>(1, 2, 3, 4),
      sf.read(v),
      "SIMDField64.read lane-wise",
      .sl()
    )

    // write (set to 9,8,7,6)
    let to = SIMD4<UInt64>(9, 8, 7, 6)
    let v2 = sf.write(in: v, value: to)
    a.expAct(to, sf.read(v2), "SIMDField64.write then read", .sl())

    // clear
    a.expAct(
      SIMD4<UInt64>(repeating: 0),
      sf.clear(in: v2),
      "SIMDField64.clear removes field bits",
      .sl()
    )

    // update (+10)
    let v3 = sf.update(in: v) { $0 &+ SIMD4<UInt64>(repeating: 10) }
    a.expAct(
      SIMD4<UInt64>(11, 12, 13, 14),
      sf.read(v3),
      "SIMDField64.update lane-wise +10",
      .sl()
    )

    // scalar broadcast write
    let v4 = sf.write(in: v3, scalar: 0x7F)
    a.expAct(
      SIMD4<UInt64>(repeating: 0x7F),
      sf.read(v4),
      "SIMDField64.write scalar broadcast",
      .sl()
    )
  }
}
