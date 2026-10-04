import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Can I Wear")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Leather jacket")
                .font(.title2)

            Text("Checking the weather…")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
