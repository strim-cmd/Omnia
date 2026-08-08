#if canImport(SwiftUI)
public struct Foo: View {
  public var body: some View {
    HStack { Text("hi") THIS IS A SYNTAX ERROR
  }
}
#endif
