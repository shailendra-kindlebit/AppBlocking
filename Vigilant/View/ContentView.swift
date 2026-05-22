//
//  ContentView.swift
//  Vigilant
//
//  Created by KBS on 5/14/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selected:Bool = false
    
    var body: some View {
       
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
