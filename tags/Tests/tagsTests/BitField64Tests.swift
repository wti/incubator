import XrayInXCTest

@testable import tags

final class BitField64Tests: AssrtTestCase {
  func testBitField64() {
    let f = BitField64(bits: 8, shift: 16)  // maskField=0xFF, mask=0xFF<<16

    // write
    let w1 = f.write(in: 0, value: 0xAB)
    a.expAct(0x00AB_0000, w1, "BitField64.write encodes into position", .sl())

    // read
    a.expAct(0xAB, f.read(w1), "BitField64.read returns unshifted value", .sl())

    // update (+1, masked by encode)
    let w2 = f.update(in: w1) { $0 &+ 1 }
    a.expAct(
      0x00AC_0000,
      w2,
      "BitField64.update modifies only the field",
      .sl()
    )
    a.expAct(0xAC, f.read(w2), "BitField64.update result readback", .sl())

    // clear
    let w3 = f.clear(in: w2)
    a.expAct(0 as UInt64, w3, "BitField64.clear removes field bits", .sl())

    // encode convenience
    a.expAct(
      0x0012_0000,
      f.encode(0x12),
      "BitField64.encode places bits correctly",
      .sl()
    )
  }
}
