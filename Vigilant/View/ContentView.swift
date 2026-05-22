//
//  ContentView.swift
//  Vigilant
//
//  Created by KBS on 5/14/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    var body: some View {
        NavigationSplitView {
           
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
