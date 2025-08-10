import Testing
import tagDemo

@Test func maskForTagInRange() {
  typealias Masker = TagOps.MaskForTag
  guard var me = Masker(lanes: 1024) else { return }  // TODO: fail
  me.run()
  let act = me.getMaskResultActual()
  let exp = me.getMaskResultExpected()
  if exp != act {  // TODO: pick another test API
    print(act.map { Masker.HM($0) })
    print(exp.map { Masker.HM($0) })
  }
}
